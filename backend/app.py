# -*- coding: utf-8 -*-
import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

from flask import Flask, request, jsonify, Response, copy_current_request_context
from flask_cors import CORS
from functools import wraps
import signal
import librosa
import librosa.sequence
import numpy as np
from sklearn.preprocessing import StandardScaler
from sklearn.metrics.pairwise import cosine_similarity, cosine_distances
import joblib
import requests
import tempfile
import time
import json
import warnings
import re
from difflib import SequenceMatcher
import threading
import soundfile as sf
from openai import OpenAI
import os

try:
    import noisereduce as nr
except Exception:
    nr = None

warnings.filterwarnings("ignore")

# ── OpenAI client ─────────────────────────────────────────────────────────────
api_key = os.getenv("OPENAI_API_KEY")
if not api_key:
    raise RuntimeError("OPENAI_API_KEY is not set in the environment")
client = OpenAI(api_key=api_key)

# ── Flask app ─────────────────────────────────────────────────────────────────
app = Flask(__name__)
CORS(app)

# ── Qari cache setup ──────────────────────────────────────────────────────────
qari_cache = {}
QARI_CACHE_DIR = os.path.join(tempfile.gettempdir(), "reciteright_cache")
QARI_CACHE_CLEANUP_INTERVAL_SECONDS = 30 * 60
QARI_CACHE_MAX_AGE_SECONDS = 2 * 60 * 60
_qari_cleanup_thread_started = False


def _cleanup_qari_cache_once():
    os.makedirs(QARI_CACHE_DIR, exist_ok=True)
    now = time.time()
    stale_paths = set()

    for filename in os.listdir(QARI_CACHE_DIR):
        if not filename.startswith("qari_") or not filename.endswith(".mp3"):
            continue

        filepath = os.path.join(QARI_CACHE_DIR, filename)
        if not os.path.isfile(filepath):
            continue

        if now - os.path.getmtime(filepath) <= QARI_CACHE_MAX_AGE_SECONDS:
            continue

        try:
            os.remove(filepath)
            stale_paths.add(filepath)
        except OSError:
            pass

    if stale_paths:
        keys_to_delete = [
            key for key, path in list(qari_cache.items()) if path in stale_paths
        ]
        for key in keys_to_delete:
            qari_cache.pop(key, None)


def _start_qari_cache_cleanup_thread():
    global _qari_cleanup_thread_started
    if _qari_cleanup_thread_started:
        return

    def _cleanup_loop():
        _cleanup_qari_cache_once()
        while True:
            time.sleep(QARI_CACHE_CLEANUP_INTERVAL_SECONDS)
            _cleanup_qari_cache_once()

    cleanup_thread = threading.Thread(target=_cleanup_loop, daemon=True)
    cleanup_thread.start()
    _qari_cleanup_thread_started = True


_start_qari_cache_cleanup_thread()

# ── Timeout helper ────────────────────────────────────────────────────────────
class TimeoutError(Exception):
    pass


def with_timeout(seconds=55):
    """Decorator to add timeout to route handlers."""
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            result = [TimeoutError("Request processing timeout")]

            @copy_current_request_context
            def target():
                try:
                    result[0] = func(*args, **kwargs)
                except Exception as e:
                    result[0] = e

            thread = threading.Thread(target=target)
            thread.daemon = True
            thread.start()
            thread.join(timeout=seconds)

            if thread.is_alive():
                print(f"⚠️ Request timeout after {seconds}s")
                return jsonify({
                    "success": False,
                    "error": f"Processing took too long (>{seconds}s). Please try with shorter audio.",
                    "reason": "timeout"
                }), 408

            if isinstance(result[0], Exception):
                raise result[0]

            return result[0]
        return wrapper
    return decorator


# ── Model load ────────────────────────────────────────────────────────────────
print("🔄 Model load ho raha hai...")
scaler = joblib.load("model/scaler.pkl")
X_ref = np.load("model/reference_features.npy")
with open("model/file_names.json") as f:
    file_names = json.load(f)
print(f"✅ Model ready! {len(file_names)} reference ayaat loaded.")

try:
    COMPARE_TIMEOUT_SECONDS = int(os.getenv("COMPARE_TIMEOUT_SECONDS", "300"))
except ValueError:
    COMPARE_TIMEOUT_SECONDS = 300
print(f"⏱️ Compare timeout set to {COMPARE_TIMEOUT_SECONDS}s")

# ── STEP 1: Audio preprocessing ───────────────────────────────────────────────
def preprocess_audio(input_path):
    """Preprocess audio: denoise, normalize, trim silence."""
    try:
        y, sr = librosa.load(input_path, sr=16000, mono=True)

        raw_rms = float(np.sqrt(np.mean(np.square(y)))) if y is not None and y.size > 0 else 0.0
        raw_peak = float(np.max(np.abs(y))) if y is not None and y.size > 0 else 0.0

        if nr is not None:
            y_denoised = nr.reduce_noise(y=y, sr=sr, stationary=True)
        else:
            y_denoised = y

        max_val = np.max(np.abs(y_denoised)) if y_denoised is not None and y_denoised.size > 0 else 0.0

        should_normalize = (raw_rms >= 0.0045 and raw_peak >= 0.025 and max_val > 0)
        if should_normalize:
            y_normalized = y_denoised / max_val * 0.95
        else:
            y_normalized = y_denoised

        y_trimmed, _ = librosa.effects.trim(y_normalized, top_db=20)

        output_path = input_path.replace(".wav", "_processed.wav")
        sf.write(output_path, y_trimmed, 16000)

        return output_path
    except Exception as e:
        print(f"⚠️ Audio preprocessing error: {e}. Using original.")
        return input_path


def _analyze_speech_activity(audio_path):
    """Estimate whether the audio contains meaningful speech-like content."""
    try:
        y, sr = librosa.load(audio_path, sr=16000, mono=True)
        if y is None or y.size == 0:
            return {
                "duration_sec": 0.0,
                "rms": 0.0,
                "peak": 0.0,
                "voiced_ratio": 0.0,
                "voiced_duration_sec": 0.0,
                "speech_detected": False,
                "reason": "empty_audio"
            }

        duration_sec = float(len(y) / sr)
        rms = float(np.sqrt(np.mean(np.square(y))))
        peak = float(np.max(np.abs(y)))

        intervals = librosa.effects.split(y, top_db=35)
        voiced_samples = int(sum((end - start) for start, end in intervals))
        voiced_duration_sec = float(voiced_samples / sr)
        voiced_ratio = float(voiced_duration_sec / max(duration_sec, 1e-6))

        speech_detected = (
            duration_sec >= 0.60 and
            voiced_duration_sec >= 0.20 and
            voiced_ratio >= 0.06 and
            rms >= 0.0025 and
            peak >= 0.015
        )

        return {
            "duration_sec": round(duration_sec, 3),
            "rms": round(rms, 6),
            "peak": round(peak, 6),
            "voiced_ratio": round(voiced_ratio, 4),
            "voiced_duration_sec": round(voiced_duration_sec, 3),
            "speech_detected": bool(speech_detected),
            "reason": "ok" if speech_detected else "no_speech"
        }
    except Exception as e:
        print(f"⚠️ Speech activity analysis error: {e}")
        return {
            "duration_sec": 0.0,
            "rms": 0.0,
            "peak": 0.0,
            "voiced_ratio": 0.0,
            "voiced_duration_sec": 0.0,
            "speech_detected": False,
            "reason": "analysis_error"
        }

# ── STEP 2: Transcribe via OpenAI Whisper API ────────────────────────────────
def transcribe_audio(audio_path, expected_text=""):
    """Transcribe audio using OpenAI's hosted Whisper API."""
    try:
        prompt = "بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ " + (expected_text or "")

        with open(audio_path, "rb") as f:
            result = client.audio.transcriptions.create(
                model="whisper-1",
                file=f,
                language="ar",
                prompt=prompt,
                response_format="verbose_json",
            )

        text = (result.get("text") or "").strip()
        segments = result.get("segments") or []

        no_speech_vals = [
            float((seg or {}).get("no_speech_prob", 0.0) or 0.0) for seg in segments
        ]
        logprob_vals = [
            float((seg or {}).get("avg_logprob", -2.0) or -2.0) for seg in segments
        ]

        detected_lang = (result.get("language", "ar") or "").lower()
        language_probability = 1.0 if detected_lang == "ar" else 0.0

        meta = {
            "text": text,
            "segment_count": len(segments),
            "mean_no_speech_prob": float(np.mean(no_speech_vals)) if no_speech_vals else 0.5,
            "avg_logprob": float(np.mean(logprob_vals)) if logprob_vals else -1.5,
            "language_probability": float(language_probability),
        }

        print(f"🎤 Transcribed (API): '{text}'")
        print(
            f"🧪 ASR meta: segments={meta['segment_count']}, "
            f"no_speech={meta['mean_no_speech_prob']:.3f}, avg_logprob={meta['avg_logprob']:.3f}"
        )
        return meta
    except Exception as e:
        print(f"❌ Transcription API error: {e}")
        return {
            "text": "",
            "segment_count": 0,
            "mean_no_speech_prob": 1.0,
            "avg_logprob": -5.0,
            "language_probability": 0.0,
        }

# ── Helper functions (gates, scoring, tajweed, etc.) ─────────────────────────
def _passes_transcription_gate(transcription_meta, correct_text=""):
    text = (transcription_meta or {}).get("text", "") or ""
    arabic_chars = len(re.findall(r"[\u0621-\u064A]", text))
    transcribed_words = len(text.split())
    segment_count = int((transcription_meta or {}).get("segment_count", 0) or 0)
    no_speech_prob = float((transcription_meta or {}).get("mean_no_speech_prob", 1.0) or 1.0)
    avg_logprob = float((transcription_meta or {}).get("avg_logprob", -5.0) or -5.0)
    lang_prob = float((transcription_meta or {}).get("language_probability", 0.0) or 0.0)

    correct_words = correct_text.split() if correct_text else []
    expected_words = len(correct_words)
    expected_arabic_chars = len(re.findall(r"[\u0621-\u064A]", correct_text)) if correct_text else 0

    if arabic_chars < 2:
        return False
    if transcribed_words == 0:
        return False
    if segment_count == 0:
        return False
    if no_speech_prob > 0.92 and avg_logprob < -1.4:
        return False
    if avg_logprob < -2.3:
        return False
    if lang_prob < 0.15 and no_speech_prob > 0.85:
        return False

    if expected_words >= 3:
        word_coverage = transcribed_words / float(expected_words)
        if word_coverage < 0.30:
            return False
    if expected_arabic_chars >= 12:
        char_coverage = arabic_chars / float(expected_arabic_chars)
        if char_coverage < 0.22:
            return False

    return True


def _clamp(value, min_value=0.0, max_value=100.0):
    return float(max(min_value, min(max_value, value)))


def _compute_confidence_multiplier(
    speech_stats,
    transcription_meta,
    correct_words_count=0,
    transcribed_words_count=0,
):
    voiced_ratio = float((speech_stats or {}).get("voiced_ratio", 0.0) or 0.0)
    rms = float((speech_stats or {}).get("rms", 0.0) or 0.0)
    no_speech_prob = float((transcription_meta or {}).get("mean_no_speech_prob", 1.0) or 1.0)
    avg_logprob = float((transcription_meta or {}).get("avg_logprob", -5.0) or -5.0)

    if correct_words_count > 0:
        coverage = min(1.0, transcribed_words_count / float(correct_words_count))
    else:
        coverage = 0.0

    voiced_factor = _clamp((voiced_ratio - 0.03) / 0.30, 0.0, 1.0)
    rms_factor = _clamp((rms - 0.0015) / 0.02, 0.0, 1.0)
    logprob_factor = _clamp((avg_logprob + 2.2) / 2.0, 0.0, 1.0)
    no_speech_factor = _clamp(1.0 - ((no_speech_prob - 0.20) / 0.75), 0.0, 1.0)
    coverage_factor = _clamp(coverage / 0.80, 0.0, 1.0)

    confidence = (
        (voiced_factor * 0.35)
        + (rms_factor * 0.20)
        + (logprob_factor * 0.20)
        + (no_speech_factor * 0.15)
        + (coverage_factor * 0.10)
    )

    if not _passes_transcription_gate(transcription_meta):
        confidence = min(confidence, 0.12)
    elif voiced_ratio < 0.04:
        confidence = min(confidence, 0.08)
    else:
        confidence = max(0.9, confidence * 1.3)

    return _clamp(confidence, 0.0, 1.0)

# ... keep all your existing helpers: clean_quran_text, normalize_arabic,
# align_words_smart, extract_phonemes, analyze_tajweed, extract_features,
# normalize_arabic_simple, detect_tajweed_rules, download_qari,
# get_grade, get_feedback, _normalize_mfcc, _levenshtein_distance,
# compute_dtw_score, compute_phoneme_accuracy, verify_tajweed_timing,
# compute_hybrid_score, and teacher feedback helpers.


# ── Health + utility routes ───────────────────────────────────────────────────
@app.route("/", methods=["GET"])
@app.route("/api/health", methods=["GET"])
def health():
    return jsonify({
        "status": "ReciteRight backend chal raha hai ✅",
        "model_loaded": True,
        "reference_ayaat": len(file_names),
        "api_version": "2.0",
    })


@app.route("/qaris", methods=["GET"])
def get_qaris():
    return jsonify({
        "qaris": [
            {"id": "7", "name": "Mishary Rashid Alafasy"},
            {"id": "1", "name": "AbdulBaset AbdulSamad"},
            {"id": "5", "name": "Mahmoud Khalil Al-Hussary"},
            {"id": "12", "name": "Saad Al-Ghamdi"},
            {"id": "9", "name": "Abdul Rahman Al-Sudais"},
        ]
    })


@app.route("/api/qari-url", methods=["GET"])
def qari_url():
    surah = request.args.get("surah", "1")
    ayah = request.args.get("ayah", "1")
    s = str(surah).zfill(3)
    a = str(ayah).zfill(3)
    url = f"https://verses.quran.com/Alafasy/mp3/{s}{a}.mp3"
    return jsonify({"url": url})


@app.route("/api/prefetch-qari", methods=["GET"])
def prefetch_qari():
    surah = request.args.get("surah", "1")
    ayah = request.args.get("ayah", "1")
    path, url = download_qari(surah, ayah)
    if path:
        return jsonify({"success": True, "cached": True, "url": url})
    return jsonify({"success": False, "url": url})


# ── Your main scoring routes go here ─────────────────────────────────────────
# Paste your existing /api/compare and /api/transcribe implementations here.
# They should call:
# - preprocess_audio(...)
# - _analyze_speech_activity(...)
# - transcribe_audio(...)
# - compute_dtw_score(...)
# - compute_phoneme_accuracy(...)
# - verify_tajweed_timing(...)
# - compute_hybrid_score(...)
# etc.


# ── Entry point (Render-compatible) ───────────────────────────────────────────
if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8000"))
    print(f"🚀 API Running at http://0.0.0.0:{port}/")
    app.run(
        host="0.0.0.0",  # required so Render's health check can see the service [web:6]
        port=port,       # use the PORT env var that Render injects [web:27]
        debug=False,
        use_reloader=False,
        threaded=True,
    )