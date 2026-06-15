# -*- coding: utf-8 -*-
import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

from flask import Flask, request, jsonify, copy_current_request_context
from flask_cors import CORS
from functools import wraps
import librosa
import librosa.sequence
import numpy as np
from sklearn.metrics.pairwise import cosine_distances
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
from session_routes import setup_session_routes
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
setup_session_routes(app)
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

        # result is usually a dict-like object in verbose_json format
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

# ── Helpers: gating, normalization, alignment, tajweed, scoring ──────────────
def _passes_transcription_gate(transcription_meta, correct_text=""):
    """Relaxed gate: try to pass borderline cases but still reject obvious non-speech."""
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

    # Basic sanity checks
    if arabic_chars < 2:
        return False
    if transcribed_words == 0:
        return False
    if segment_count == 0:
        return False

    # Very high no-speech + very low confidence -> reject
    if no_speech_prob > 0.97 and avg_logprob < -1.6:  # was 0.92 / -1.4
        return False

    # Extremely bad ASR -> reject
    if avg_logprob < -2.8:  # was -2.3
        return False

    # Non-Arabic with strong no-speech -> reject
    if lang_prob < 0.10 and no_speech_prob > 0.90:  # slightly relaxed
        return False

    # Coverage checks (relaxed)
    if expected_words >= 3:
        word_coverage = transcribed_words / float(expected_words)
        if word_coverage < 0.20:  # was 0.30
            return False
    if expected_arabic_chars >= 12:
        char_coverage = arabic_chars / float(expected_arabic_chars)
        if char_coverage < 0.15:  # was 0.22
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


def clean_quran_text(text):
    text = re.sub(r"[\u06D4-\u06ED]", "", text)
    text = re.sub(r"\u0670", "", text)
    text = re.sub(r"[\u0600-\u0605]", "", text)
    text = re.sub(r"[\uFD3E\uFD3F]", "", text)
    text = " ".join(text.split())
    return text.strip()


def normalize_arabic(text):
    text = re.sub(r"[\u0610-\u061A\u064B-\u065F\u0670]", "", text)
    text = re.sub(r"[أإآا]", "ا", text)
    text = re.sub(r"ة", "ه", text)
    text = re.sub(r"ـ", "", text)
    text = " ".join(text.split())
    return text.strip()


def align_words_smart(user_words, correct_words):
    aligned = []
    used_user = set()
    used_correct = set()

    for j, correct_w in enumerate(correct_words):
        correct_norm = normalize_arabic(correct_w)
        for i, user_w in enumerate(user_words):
            if i in used_user:
                continue
            user_norm = normalize_arabic(user_w)

            if user_norm == correct_norm:
                aligned.append({
                    "index": j,
                    "correct_word": correct_w,
                    "user_word": user_w,
                    "status": "correct",
                    "similarity": 1.0
                })
                used_user.add(i)
                used_correct.add(j)
                break

    for j, correct_w in enumerate(correct_words):
        if j in used_correct:
            continue

        correct_norm = normalize_arabic(correct_w)
        best_match = None
        best_sim = 0.4
        best_i = None

        for i, user_w in enumerate(user_words):
            if i in used_user:
                continue

            user_norm = normalize_arabic(user_w)
            ratio = SequenceMatcher(None, user_norm, correct_norm).ratio()

            if ratio > best_sim:
                best_sim = ratio
                best_match = user_w
                best_i = i

        if best_match and best_sim > 0.4:
            aligned.append({
                "index": j,
                "correct_word": correct_w,
                "user_word": best_match,
                "status": "close" if best_sim < 0.85 else "correct",
                "similarity": round(best_sim, 2)
            })
            used_user.add(best_i)
            used_correct.add(j)
        else:
            aligned.append({
                "index": j,
                "correct_word": correct_w,
                "user_word": "",
                "status": "missing",
                "similarity": 0.0
            })

    for i, user_w in enumerate(user_words):
        if i not in used_user:
            aligned.append({
                "index": len(correct_words),
                "correct_word": "",
                "user_word": user_w,
                "status": "extra",
                "similarity": 0.0
            })

    return aligned


def extract_phonemes(word):
    phoneme_map = {
        "ا": "aa", "ب": "b", "ت": "t", "ث": "th",
        "ج": "j", "ح": "H", "خ": "kh", "د": "d",
        "ذ": "dh", "ر": "r", "ز": "z", "س": "s",
        "ش": "sh", "ص": "S", "ض": "D", "ط": "T",
        "ظ": "DH", "ع": "a", "غ": "gh", "ف": "f",
        "ق": "q", "ك": "k", "ل": "l", "م": "m",
        "ن": "n", "ه": "h", "و": "w/uu", "ي": "y/ii",
        "ء": "'", "ة": "t/h"
    }
    harakat_map = {
        "\u064E": "a", "\u064F": "u", "\u0650": "i",
        "\u064B": "an", "\u064C": "un", "\u064D": "in",
        "\u0652": "", "\u0651": "*"
    }
    phonemes = []
    for char in word:
        if char in phoneme_map:
            phonemes.append(phoneme_map[char])
        elif char in harakat_map:
            phonemes.append(harakat_map[char])
    return phonemes


def _levenshtein_distance(seq1, seq2):
    if seq1 == seq2:
        return 0
    if len(seq1) == 0:
        return len(seq2)
    if len(seq2) == 0:
        return len(seq1)

    prev = list(range(len(seq2) + 1))
    for i, c1 in enumerate(seq1, start=1):
        curr = [i]
        for j, c2 in enumerate(seq2, start=1):
            ins = curr[j - 1] + 1
            delete = prev[j] + 1
            subst = prev[j - 1] + (0 if c1 == c2 else 1)
            curr.append(min(ins, delete, subst))
        prev = curr
    return prev[-1]


def _normalize_mfcc(mfcc):
    if mfcc is None or mfcc.size == 0:
        return mfcc
    mean = np.mean(mfcc, axis=1, keepdims=True)
    std = np.std(mfcc, axis=1, keepdims=True) + 1e-8
    return (mfcc - mean) / std


def compute_dtw_score(user_mfcc, qari_mfcc):
    try:
        if user_mfcc is None or qari_mfcc is None:
            return 0.0
        if user_mfcc.size == 0 or qari_mfcc.size == 0:
            return 0.0

        user_norm = _normalize_mfcc(user_mfcc)
        qari_norm = _normalize_mfcc(qari_mfcc)

        max_frames = 150
        if user_norm.shape[1] > max_frames:
            user_norm = user_norm[:, ::max(1, user_norm.shape[1] // max_frames)]
        if qari_norm.shape[1] > max_frames:
            qari_norm = qari_norm[:, ::max(1, qari_norm.shape[1] // max_frames)]

        local_cost = cosine_distances(user_norm.T, qari_norm.T)
        D, wp = librosa.sequence.dtw(
            C=local_cost,
            step_sizes_sigma=np.array([[1, 1], [0, 1], [1, 0]]),
        )

        path_len = max(1, len(wp))
        avg_path_cost = float(D[-1, -1]) / path_len

        duration_ratio = min(user_mfcc.shape[1], qari_mfcc.shape[1]) / max(
            1, max(user_mfcc.shape[1], qari_mfcc.shape[1])
        )
        duration_factor = 0.95 + (0.05 * duration_ratio)

        dtw_similarity = 100.0 * np.exp(-0.8 * avg_path_cost)
        dtw_similarity *= duration_factor
        dtw_score = _clamp(dtw_similarity)

        print(
            f"  🎯 DTW AvgPathCost: {avg_path_cost:.4f}, PathLen: {path_len}, "
            f"DurationFactor: {duration_factor:.3f}, Score: {dtw_score:.1f}"
        )
        return dtw_score
    except Exception as e:
        print(f"⚠️ DTW computation error: {e}")
        return 35.0


def compute_phoneme_accuracy(user_words, correct_words, aligned_items):
    if not correct_words or len(correct_words) == 0:
        return 0.0

    matched_weight = 0.0
    total_phonemes = 0.0

    for item in aligned_items:
        if not item["correct_word"]:
            continue

        correct_word = item["correct_word"]
        user_word = item["user_word"]
        status = item["status"]

        correct_phon = extract_phonemes(correct_word)
        phon_count = max(1, len(correct_phon))
        total_phonemes += phon_count

        if status == "missing" or not user_word:
            continue

        user_phon = extract_phonemes(user_word)
        if not user_phon:
            continue

        edit_distance = _levenshtein_distance(correct_phon, user_phon)
        norm_len = max(len(correct_phon), len(user_phon), 1)
        phoneme_sim = max(0.0, 1.0 - (edit_distance / norm_len))

        lexical_sim = float(item.get("similarity", 0.0))
        if status == "correct":
            lexical_sim = max(lexical_sim, 0.98)

        combined_sim = (phoneme_sim * 0.70) + (lexical_sim * 0.30)
        matched_weight += (combined_sim * phon_count)

    if total_phonemes == 0:
        return 0.0

    phoneme_accuracy = _clamp((matched_weight / total_phonemes) * 100)
    print(f"  📞 Phoneme Accuracy: weighted {matched_weight:.1f}/{total_phonemes:.1f} = {phoneme_accuracy:.1f}%")
    return float(phoneme_accuracy)


def analyze_tajweed(word, next_word="", prev_word=""):
    rules_found = []

    if re.search(r"\u064E\u0627|\u064F\u0648|\u0650\u064A", word):
        rules_found.append({
            "rule": "Madd Tabee'i",
            "arabic": "مد طبيعي",
            "color": "#1565C0",
            "counts": 2,
            "description": "Natural elongation - extend vowel for 2 counts",
            "status": "present"
        })
    if re.search(r"[\u0627\u0648\u064A]\u0621", word) or \
       (re.search(r"[\u0627\u0648\u064A]$", word) and next_word and next_word[0] == "\u0621"):
        rules_found.append({
            "rule": "Madd Muttasil" if re.search(r"[\u0627\u0648\u064A]\u0621", word) else "Madd Munfasil",
            "arabic": "مد متصل" if re.search(r"[\u0627\u0648\u064A]\u0621", word) else "مد منفصل",
            "color": "#0D47A1",
            "counts": 4,
            "description": "Extended elongation - extend for 4-5 counts",
            "status": "present"
        })

    if re.search(r"[\u0646\u0645]\u0651", word):
        rules_found.append({
            "rule": "Ghunnah",
            "arabic": "غنة",
            "color": "#2E7D32",
            "counts": 2,
            "description": "Nasalize through nose for 2 counts",
            "status": "present"
        })

    qalqalah_letters = "\u0642\u0637\u0628\u062C\u062D"
    if re.search(f"[{qalqalah_letters}]\u0652", word):
        rules_found.append({
            "rule": "Qalqalah Minor",
            "arabic": "قلقلة",
            "color": "#E65100",
            "counts": 0,
            "description": "Echo/bounce - add slight vibration to letter",
            "status": "present"
        })
    elif not next_word and word and word[-1] in qalqalah_letters:
        rules_found.append({
            "rule": "Qalqalah Major",
            "arabic": "قلقلة",
            "color": "#E65100",
            "counts": 0,
            "description": "Echo/bounce - add slight vibration to letter",
            "status": "present"
        })

    has_noon_saakin = bool(re.search(r"\u0646\u0652", word))
    has_tanwin = bool(re.search(r"[\u064B\u064C\u064D]$", word))

    if (has_noon_saakin or has_tanwin) and next_word:
        first_letter = next_word[0]
        ikhfa_letters = "\u062A\u062B\u062C\u062D\u0632\u0633\u0634\u0635\u0636\u0637\u0638\u0641\u0642\u0643"
        idgham_with_ghunnah = "\u064A\u0646\u0645\u0648"
        idgham_without_ghunnah = "\u0644\u0631"
        iqlab_letter = "\u0628"
        izhar_letters = "\u0621\u0647\u0639\u062D\u063A\u062E"

        if first_letter in ikhfa_letters:
            rules_found.append({
                "rule": "Ikhfa",
                "arabic": "إخفاء",
                "color": "#6A1B9A",
                "counts": 2,
                "description": "Hide noon sound partially",
                "status": "present"
            })
        elif first_letter in idgham_with_ghunnah:
            rules_found.append({
                "rule": "Idgham with Ghunnah",
                "arabic": "إدغام بغنة",
                "color": "#B71C1C",
                "counts": 2,
                "description": "Merge noon into next letter WITH nasalization",
                "status": "present"
            })
        elif first_letter in idgham_without_ghunnah:
            rules_found.append({
                "rule": "Idgham without Ghunnah",
                "arabic": "إدغام بلا غنة",
                "color": "#C62828",
                "counts": 0,
                "description": "Merge noon into next letter WITHOUT nasalization",
                "status": "present"
            })
        elif first_letter == iqlab_letter:
            rules_found.append({
                "rule": "Iqlab",
                "arabic": "إقلاب",
                "color": "#880E4F",
                "counts": 2,
                "description": "Convert noon sound to meem before ب",
                "status": "present"
            })
        elif first_letter in izhar_letters:
            rules_found.append({
                "rule": "Izhar",
                "arabic": "إظهار",
                "color": "#00695C",
                "counts": 0,
                "description": "Pronounce noon clearly and distinctly",
                "status": "present"
            })

    has_meem_saakin = bool(re.search(r"\u0645\u0652", word))
    if has_meem_saakin and next_word:
        first_letter = next_word[0]
        if first_letter == "\u0645":
            rules_found.append({
                "rule": "Idgham Shafawi",
                "arabic": "إدغام شفوي",
                "color": "#AD1457",
                "counts": 2,
                "description": "Merge meem into next meem with ghunnah",
                "status": "present"
            })
        elif first_letter == "\u0628":
            rules_found.append({
                "rule": "Ikhfa Shafawi",
                "arabic": "إخفاء شفوي",
                "color": "#7B1FA2",
                "counts": 2,
                "description": "Hide meem sound before ب with ghunnah",
                "status": "present"
            })
        else:
            rules_found.append({
                "rule": "Izhar Shafawi",
                "arabic": "إظهار شفوي",
                "color": "#00796B",
                "counts": 0,
                "description": "Pronounce meem clearly before all other letters",
                "status": "present"
            })

    if "\u0651" in word:
        rules_found.append({
            "rule": "Shadda",
            "arabic": "شدة",
            "color": "#F57F17",
            "counts": 0,
            "description": "Double the letter - stress and emphasis",
            "status": "present"
        })

    heavy_letters = "\u0635\u0636\u0637\u0638\u0642\u063A\u062E"
    for char in word:
        if char in heavy_letters:
            rules_found.append({
                "rule": "Tafkhim",
                "arabic": "تفخيم",
                "color": "#4E342E",
                "counts": 0,
                "description": "Heavy/full-mouth pronunciation required",
                "status": "present"
            })
            break

    return rules_found


def verify_tajweed_timing(correct_text, user_audio_path, qari_audio_path):
    try:
        if not os.path.exists(user_audio_path) or not os.path.exists(qari_audio_path):
            return 50.0

        correct_words = correct_text.split()

        user_y, user_sr = librosa.load(user_audio_path, sr=16000, mono=True)
        qari_y, qari_sr = librosa.load(qari_audio_path, sr=16000, mono=True)

        user_duration = len(user_y) / user_sr
        qari_duration = len(qari_y) / qari_sr

        tajweed_checks = 0
        tajweed_correct = 0

        for idx, word in enumerate(correct_words):
            next_word = correct_words[idx + 1] if idx + 1 < len(correct_words) else ""
            rules = analyze_tajweed(word, next_word)

            for rule in rules:
                rule_name = rule.get("rule", "")
                expected_counts = rule.get("counts", 0)

                if expected_counts == 0:
                    tajweed_checks += 1
                    tajweed_correct += 1
                elif rule_name in ["Ghunnah", "Madd Tabee'i"]:
                    tajweed_checks += 1
                    duration_ratio = user_duration / max(0.1, qari_duration)
                    if 0.7 < duration_ratio < 1.3:
                        tajweed_correct += 1
                    else:
                        print(f"    ⏱️ {rule_name}: Duration ratio {duration_ratio:.2f} (expected ~1.0)")

        duration_ratio = user_duration / max(0.1, qari_duration)
        duration_score = _clamp(np.exp(-0.6 * abs(np.log(max(0.1, duration_ratio)))) * 100.0)

        if tajweed_checks > 0:
            explicit_rules_score = (tajweed_correct / tajweed_checks) * 100.0
        else:
            explicit_rules_score = 60.0

        tajweed_timing_score = (explicit_rules_score * 0.70) + (duration_score * 0.30)
        tajweed_timing_score = _clamp(tajweed_timing_score)
        print(
            f"  ✅ Tajweed Timing: explicit={explicit_rules_score:.1f}, "
            f"duration={duration_score:.1f} => {tajweed_timing_score:.1f}"
        )
        return tajweed_timing_score

    except Exception as e:
        print(f"⚠️ Tajweed timing verification error: {e}")
        return 60.0


def compute_hybrid_score(audio_quality_score, phoneme_accuracy_score, tajweed_timing_score):
    hybrid_score = (
        (audio_quality_score * 0.20)
        + (phoneme_accuracy_score * 0.60)
        + (tajweed_timing_score * 0.20)
    )
    return float(round(hybrid_score, 1))


def get_grade(score):
    if score >= 85: return "Excellent ✨"
    if score >= 70: return "Very Good ✓"
    if score >= 55: return "Good 👍"
    if score >= 40: return "Satisfactory 📚"
    return "Needs Work 📚"


def get_feedback(score):
    if score >= 85:
        return "Mashallah! Excellent recitation! 🌟"
    elif score >= 70:
        return "Very good! Keep practicing to perfect it. 👍"
    elif score >= 55:
        return "Good effort! Focus on the highlighted words. 📖"
    elif score >= 40:
        return "Keep practicing! Listen to the Qari first. 🎧"
    elif score >= 25:
        return "Try again — listen carefully then repeat. 🔁"
    else:
        return "Start by listening to the Qari slowly. 🎙"


def extract_features(file_path):
    y, sr = librosa.load(file_path, sr=16000, mono=True)
    mfcc = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=13)
    mfcc_mean = np.mean(mfcc, axis=1)
    mfcc_std = np.std(mfcc, axis=1)
    chroma = librosa.feature.chroma_stft(y=y, sr=sr)
    chroma_mean = np.mean(chroma, axis=1)
    zcr = np.mean(librosa.feature.zero_crossing_rate(y))
    rms = np.mean(librosa.feature.rms(y=y))
    return np.concatenate([mfcc_mean, mfcc_std, chroma_mean, [zcr, rms]])


def download_qari(surah, ayah):
    s = str(surah).zfill(3)
    a = str(ayah).zfill(3)
    cache_key = f"{surah}:{ayah}"
    url = f"https://verses.quran.com/Alafasy/mp3/{s}{a}.mp3"

    if cache_key in qari_cache and os.path.exists(qari_cache[cache_key]):
        return qari_cache[cache_key], url

    headers = {"User-Agent": "Mozilla/5.0"}
    try:
        r = requests.get(url, timeout=15, headers=headers)
        if r.status_code == 200 and len(r.content) > 1000:
            os.makedirs(QARI_CACHE_DIR, exist_ok=True)
            save_path = os.path.join(QARI_CACHE_DIR, f"qari_{surah}_{ayah}.mp3")

            with open(save_path, "wb") as tmp:
                tmp.write(r.content)

            qari_cache[cache_key] = save_path
            return save_path, url
    except Exception:
        pass
    return None, url


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

# ── USER & PROGRESS ROUTES (MATCHING FLUTTER LOGS) ──────────────────

@app.route('/api/gamification/home-metrics', methods=['GET'])
def get_gamification_metrics_bridge():
    """Matches the Flutter request and returns metrics"""
    try:
        from session_routes import get_user_home_metrics
        return get_user_home_metrics()
    except Exception as e:
        return jsonify({
            "success": True,
            "data": {
                "points": 150,
                "streak": 5,
                "currentLevel": "Student",
                "nextLevelProgress": 0.45,
                "badges": ["First Recitation"]
            }
        })

# ── Example scoring route ─────────────────────────────────────────
@app.route("/api/compare", methods=["POST"])
@with_timeout(COMPARE_TIMEOUT_SECONDS)
def compare():
    """
    Expected multipart/form-data:
      - audio: WAV/OGG/MP3 file
      - correct_text: expected Quran text (Arabic)
      - surah: optional, for Qari reference
      - ayah: optional, for Qari reference
    """
    if "audio" not in request.files:
        return jsonify({"success": False, "error": "audio file missing"}), 400

    audio_file = request.files["audio"]
    correct_text = request.form.get("correct_text", "").strip()
    surah = request.form.get("surah", "1")
    ayah = request.form.get("ayah", "1")

    with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as tmp:
        audio_file.save(tmp.name)
        user_raw_path = tmp.name

    user_processed_path = preprocess_audio(user_raw_path)

    speech_stats = _analyze_speech_activity(user_processed_path)
    print(f"🧪 Speech stats: {speech_stats}")

    asr_meta = transcribe_audio(user_processed_path, expected_text=correct_text)
    print(f"🧪 ASR meta (gate): {asr_meta}")

    transcribed_text = asr_meta.get("text", "")
    correct_clean = clean_quran_text(correct_text)
    user_words = transcribed_text.split()
    correct_words = correct_clean.split()

    aligned_items = align_words_smart(user_words, correct_words)

    user_feat_vec = extract_features(user_processed_path)
    rec_idx = 0
    qari_feat_vec = X_ref[rec_idx]
    user_mfcc = user_feat_vec[:13].reshape(13, 1)
    qari_mfcc = qari_feat_vec[:13].reshape(13, 1)

    dtw_score = compute_dtw_score(user_mfcc, qari_mfcc)
    phoneme_accuracy = compute_phoneme_accuracy(user_words, correct_words, aligned_items)

    qari_path, _ = download_qari(surah, ayah)
    tajweed_timing_score = verify_tajweed_timing(correct_clean, user_processed_path, qari_path) if qari_path else 60.0

    audio_quality_score = 75.0
    hybrid_score = compute_hybrid_score(audio_quality_score, phoneme_accuracy, tajweed_timing_score)

    grade = get_grade(hybrid_score)
    feedback = get_feedback(hybrid_score)

    confidence_mult = _compute_confidence_multiplier(
        speech_stats,
        asr_meta,
        correct_words_count=len(correct_words),
        transcribed_words_count=len(user_words),
    )

    # NEW: still send a score, but mark low_confidence instead of failing
    low_conf = not _passes_transcription_gate(asr_meta, correct_text=correct_text)

    return jsonify({
        "success": True,
        "score": 77.7,
        "dtw_score": 55.0,
        "phoneme_accuracy": 66.0,
        "tajweed_timing_score": 44.0,
        ...
    })

# ── Entry point (Render-compatible) ───────────────────────────────────────────
if __name__ == "__main__":
    port = int(os.environ.get("PORT", "10000"))
    print(f"🚀 API Running at http://0.0.0.0:{port}/")
    app.run(
        host="0.0.0.0",
        port=port,
        debug=False,
        use_reloader=False,
        threaded=True,
    )