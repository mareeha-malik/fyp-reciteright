# -*- coding: utf-8 -*-
import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

from flask import Flask, request, jsonify, Response, copy_current_request_context
import signal
from functools import wraps
from flask_cors import CORS
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
import whisper
import torch
import threading
import soundfile as sf
try:
    import noisereduce as nr
except:
    nr = None
warnings.filterwarnings('ignore')

from openai import OpenAI
import os

# ── OpenAI client with API key check ───────────────────────────────────────────
api_key = os.getenv("OPENAI_API_KEY")
if not api_key:
    raise RuntimeError("OPENAI_API_KEY is not set in the environment")
client = OpenAI(api_key=api_key)

app = Flask(__name__)
CORS(app)

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

# Timeout handler for long-running requests (Windows-compatible)
from threading import Timer
import threading


class TimeoutError(Exception):
    pass


def with_timeout(seconds=55):
    """Decorator to add timeout to route handlers - Windows compatible"""
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
                # Thread is still running, timeout occurred
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


# ── Model load karo ───────────────────────────────────────────────────────────
print("🔄 Model load ho raha hai...")
scaler     = joblib.load("model/scaler.pkl")
X_ref      = np.load("model/reference_features.npy")
with open("model/file_names.json") as f:
    file_names = json.load(f)
print(f"✅ Model ready! {len(file_names)} reference ayaat loaded.")

# ── Load OpenAI Whisper model for transcription (local whisper lib) ───────────
DEFAULT_WHISPER_MODEL = "large-v3-turbo" if torch.cuda.is_available() else "small"
WHISPER_MODEL_NAME = os.getenv("WHISPER_MODEL_NAME", DEFAULT_WHISPER_MODEL)
WHISPER_CACHE_DIR = r"F:\.cache\whisper"
WHISPER_MODEL_PATH = os.path.join(WHISPER_CACHE_DIR, f"{WHISPER_MODEL_NAME}.pt")
ASR_DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

try:
    COMPARE_TIMEOUT_SECONDS = int(os.getenv("COMPARE_TIMEOUT_SECONDS", "300"))
except ValueError:
    COMPARE_TIMEOUT_SECONDS = 300

print(f"🔄 Loading OpenAI Whisper model ({WHISPER_MODEL_NAME}) on {ASR_DEVICE}...")
print(f"⏱️ Compare timeout set to {COMPARE_TIMEOUT_SECONDS}s")
try:
    whisper_model = whisper.load_model(
        WHISPER_MODEL_NAME,
        device=ASR_DEVICE,
        download_root=WHISPER_CACHE_DIR
    )
except RuntimeError as e:
    raise RuntimeError(
        "Failed to initialize Whisper model 'large-v3-turbo'. "
        "If running on CPU, ensure enough free RAM/pagefile and avoid Flask reloader double-start. "
        f"Original error: {e}"
    ) from e
print("✅ OpenAI Whisper model loaded!")

# ── STEP 1: Audio Preprocessing ────────────────────────────────────────────────
def preprocess_audio(input_path):
    """Preprocess audio: denoise, normalize, trim silence"""
    try:
        y, sr = librosa.load(input_path, sr=16000, mono=True)

        raw_rms = float(np.sqrt(np.mean(np.square(y)))) if y is not None and y.size > 0 else 0.0
        raw_peak = float(np.max(np.abs(y))) if y is not None and y.size > 0 else 0.0

        if nr is not None:
            y_denoised = nr.reduce_noise(y=y, sr=sr, stationary=True)
        else:
            y_denoised = y

        max_val = np.max(np.abs(y_denoised)) if y_denoised is not None and y_denoised.size > 0 else 0.0

        # Never amplify near-silent/noise-floor recordings; this can make silence look like speech.
        should_normalize = (raw_rms >= 0.0045 and raw_peak >= 0.025 and max_val > 0)
        if should_normalize:
            y_normalized = y_denoised / max_val * 0.95
        else:
            y_normalized = y_denoised

        y_trimmed, _ = librosa.effects.trim(y_normalized, top_db=20)

        output_path = input_path.replace('.wav', '_processed.wav')
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

# ── STEP 2: Transcribe Audio (local whisper) ───────────────────────────────────
def transcribe_audio(audio_path, expected_text=""):
    """Transcribe audio using local Whisper with optimizations for speed."""
    try:
        quran_prompt = "بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ " + (expected_text or "")
        result = whisper_model.transcribe(
            audio_path,
            language="ar",
            task="transcribe",
            fp16=(ASR_DEVICE == "cuda"),
            temperature=0.0,
            condition_on_previous_text=False,
            no_speech_threshold=0.4,
            logprob_threshold=-1.5,
            word_timestamps=True,
            initial_prompt=quran_prompt,
            beam_size=1,  # speed
            best_of=1
        )
        segments = result.get("segments", []) or []
        text = (result.get("text", "") or "").strip()

        no_speech_vals = [float((seg or {}).get("no_speech_prob", 0.0) or 0.0) for seg in segments]
        logprob_vals = [float((seg or {}).get("avg_logprob", -2.0) or -2.0) for seg in segments]
        detected_lang = (result.get("language", "") or "").lower()
        language_probability = 1.0 if detected_lang == "ar" else 0.0

        meta = {
            "text": text,
            "segment_count": len(segments),
            "mean_no_speech_prob": float(np.mean(no_speech_vals)) if no_speech_vals else 1.0,
            "avg_logprob": float(np.mean(logprob_vals)) if logprob_vals else -5.0,
            "language_probability": float(language_probability),
        }

        print(f"🎤 Transcribed: '{text}'")
        print(f"📊 Confidence: {meta['language_probability']:.2%}")
        print(
            f"🧪 ASR meta: segments={meta['segment_count']}, "
            f"no_speech={meta['mean_no_speech_prob']:.3f}, avg_logprob={meta['avg_logprob']:.3f}"
        )
        return meta
    except Exception as e:
        print(f"❌ Transcription error: {e}")
        return {
            "text": "",
            "segment_count": 0,
            "mean_no_speech_prob": 1.0,
            "avg_logprob": -5.0,
            "language_probability": 0.0,
        }


def _passes_transcription_gate(transcription_meta, correct_text=""):
    """Reject empty or low-confidence ASR outputs that commonly come from silence/noise."""
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


def _compute_confidence_multiplier(speech_stats, transcription_meta, correct_words_count=0, transcribed_words_count=0):
    """Down-weight scores when speech/transcription confidence is weak."""
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
        (voiced_factor * 0.35) +
        (rms_factor * 0.20) +
        (logprob_factor * 0.20) +
        (no_speech_factor * 0.15) +
        (coverage_factor * 0.10)
    )

    if not _passes_transcription_gate(transcription_meta):
        confidence = min(confidence, 0.12)
    elif voiced_ratio < 0.04:
        confidence = min(confidence, 0.08)
    else:
        confidence = max(0.9, confidence * 1.3)

    return _clamp(confidence, 0.0, 1.0)

# ── STEP 3: Text Normalization ─────────────────────────────────────────────────
def clean_quran_text(text):
    """Remove Quranic annotation symbols that users don't recite"""
    text = re.sub(r'[\u06D4-\u06ED]', '', text)
    text = re.sub(r'\u0670', '', text)
    text = re.sub(r'[\u0600-\u0605]', '', text)
    text = re.sub(r'[\uFD3E\uFD3F]', '', text)
    text = ' '.join(text.split())
    return text.strip()


def normalize_arabic(text):
    """Normalize Arabic text for comparison"""
    text = re.sub(r'[\u0610-\u061A\u064B-\u065F\u0670]', '', text)
    text = re.sub(r'[أإآا]', 'ا', text)
    text = re.sub(r'ة', 'ه', text)
    text = re.sub(r'ـ', '', text)
    text = ' '.join(text.split())
    return text.strip()

# ── STEP 4: Word Alignment (Improved) ───────────────────────────────────────────
def align_words_smart(user_words, correct_words):
    aligned = []
    used_user = set()
    used_correct = set()

    # First pass: exact normalized matches
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

    # Second pass: similarity-based matching
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

    # Extra user words
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

# ── STEP 5: Phoneme Extraction ─────────────────────────────────────────────────
def extract_phonemes(word):
    phoneme_map = {
        'ا': 'aa', 'ب': 'b', 'ت': 't', 'ث': 'th',
        'ج': 'j', 'ح': 'H', 'خ': 'kh', 'د': 'd',
        'ذ': 'dh', 'ر': 'r', 'ز': 'z', 'س': 's',
        'ش': 'sh', 'ص': 'S', 'ض': 'D', 'ط': 'T',
        'ظ': 'DH', 'ع': 'a', 'غ': 'gh', 'ف': 'f',
        'ق': 'q', 'ك': 'k', 'ل': 'l', 'م': 'm',
        'ن': 'n', 'ه': 'h', 'و': 'w/uu', 'ي': 'y/ii',
        'ء': "'", 'ة': 't/h'
    }
    harakat_map = {
        '\u064E': 'a', '\u064F': 'u', '\u0650': 'i',
        '\u064B': 'an', '\u064C': 'un', '\u064D': 'in',
        '\u0652': '', '\u0651': '*'
    }
    phonemes = []
    for char in word:
        if char in phoneme_map:
            phonemes.append(phoneme_map[char])
        elif char in harakat_map:
            phonemes.append(harakat_map[char])
    return phonemes

# ── STEP 6: Tajweed Rule Analysis ──────────────────────────────────────────────
def _unique_rules(rules):
    seen = set()
    unique_rules = []
    for rule in rules:
        rule_name = rule.get("rule", "")
        if not rule_name or rule_name in seen:
            continue
        seen.add(rule_name)
        unique_rules.append(rule)
    return unique_rules


def analyze_tajweed(word, next_word="", prev_word=""):
    rules_found = []

    # MADD (Elongation)
    if re.search(r'\u064E\u0627|\u064F\u0648|\u0650\u064A', word):
        rules_found.append({
            "rule": "Madd Tabee'i",
            "arabic": "مد طبيعي",
            "color": "#1565C0",
            "counts": 2,
            "description": "Natural elongation - extend vowel for 2 counts",
            "status": "present"
        })
    if re.search(r'[\u0627\u0648\u064A]\u0621', word) or \
       (re.search(r'[\u0627\u0648\u064A]$', word) and next_word and next_word[0] == '\u0621'):
        rules_found.append({
            "rule": "Madd Muttasil" if re.search(r'[\u0627\u0648\u064A]\u0621', word) else "Madd Munfasil",
            "arabic": "مد متصل" if re.search(r'[\u0627\u0648\u064A]\u0621', word) else "مد منفصل",
            "color": "#0D47A1",
            "counts": 4,
            "description": "Extended elongation - extend for 4-5 counts",
            "status": "present"
        })

    # GHUNNAH (Nasalization)
    if re.search(r'[\u0646\u0645]\u0651', word):
        rules_found.append({
            "rule": "Ghunnah",
            "arabic": "غنة",
            "color": "#2E7D32",
            "counts": 2,
            "description": "Nasalize through nose for 2 counts",
            "status": "present"
        })

    # QALQALAH (Echo/Bounce)
    qalqalah_letters = '\u0642\u0637\u0628\u062C\u062D'
    if re.search(f'[{qalqalah_letters}]\u0652', word):
        level = "Minor"
        rules_found.append({
            "rule": f"Qalqalah {level}",
            "arabic": "قلقلة",
            "color": "#E65100",
            "counts": 0,
            "description": "Echo/bounce - add slight vibration to letter",
            "status": "present"
        })
    elif not next_word and word and word[-1] in qalqalah_letters:
        level = "Major"
        rules_found.append({
            "rule": f"Qalqalah {level}",
            "arabic": "قلقلة",
            "color": "#E65100",
            "counts": 0,
            "description": "Echo/bounce - add slight vibration to letter",
            "status": "present"
        })

    # NOON SAKINAH & TANWIN RULES
    has_noon_saakin = bool(re.search(r'\u0646\u0652', word))
    has_tanwin = bool(re.search(r'[\u064B\u064C\u064D]$', word))

    if (has_noon_saakin or has_tanwin) and next_word:
        first_letter = next_word[0] if next_word else ''
        ikhfa_letters = '\u062A\u062B\u062C\u062D\u0632\u0633\u0634\u0635\u0636\u0637\u0638\u0641\u0642\u0643'
        idgham_with_ghunnah = '\u064A\u0646\u0645\u0648'
        idgham_without_ghunnah = '\u0644\u0631'
        iqlab_letter = '\u0628'
        izhar_letters = '\u0621\u0647\u0639\u062D\u063A\u062E'

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

    # MEEM SAKINAH RULES
    has_meem_saakin = bool(re.search(r'\u0645\u0652', word))
    if has_meem_saakin and next_word:
        first_letter = next_word[0] if next_word else ''
        if first_letter == '\u0645':
            rules_found.append({
                "rule": "Idgham Shafawi",
                "arabic": "إدغام شفوي",
                "color": "#AD1457",
                "counts": 2,
                "description": "Merge meem into next meem with ghunnah",
                "status": "present"
            })
        elif first_letter == '\u0628':
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

    # SHADDA (Emphasis)
    if '\u0651' in word:
        rules_found.append({
            "rule": "Shadda",
            "arabic": "شدة",
            "color": "#F57F17",
            "counts": 0,
            "description": "Double the letter - stress and emphasis",
            "status": "present"
        })

    # TAFKHIM (Heavy/Full-mouth pronunciation)
    heavy_letters = '\u0635\u0636\u0637\u0638\u0642\u063A\u062E'
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

    return _unique_rules(rules_found)

# ── Audio features extract karo ───────────────────────────────────────────────
def extract_features(file_path):
    y, sr = librosa.load(file_path, sr=16000, mono=True)
    mfcc        = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=13)
    mfcc_mean   = np.mean(mfcc, axis=1)
    mfcc_std    = np.std(mfcc, axis=1)
    chroma      = librosa.feature.chroma_stft(y=y, sr=sr)
    chroma_mean = np.mean(chroma, axis=1)
    zcr         = np.mean(librosa.feature.zero_crossing_rate(y))
    rms         = np.mean(librosa.feature.rms(y=y))
    return np.concatenate([mfcc_mean, mfcc_std, chroma_mean, [zcr, rms]])

# ── Normalize Arabic text for comparison (duplicate-safe) ─────────────────────
def normalize_arabic_simple(text):
    text = re.sub(r'[\u0610-\u061A\u064B-\u065F\u0670]', '', text)
    text = re.sub(r'[أإآا]', 'ا', text)
    text = re.sub(r'ة', 'ه', text)
    text = re.sub(r'ـ', '', text)
    return text.strip()

def detect_tajweed_rules(word, next_word=""):
    rules = []

    if re.search(r'[\u064E]\u0627|[\u064F]\u0648|[\u0650]\u064A|\u0653|\u0649$', word):
        rules.append({
            "rule": "Madd",
            "color": "#1565C0",
            "description": "Elongate this vowel for 2-6 counts"
        })

    if re.search(r'[\u0646\u0645]\u0651', word):
        rules.append({
            "rule": "Ghunnah",
            "color": "#2E7D32",
            "description": "Nasalize through nose for 2 counts"
        })

    if re.search(r'[\u0642\u0637\u0628\u062C\u062D][\u0652]', word) or \
       re.search(r'[\u0642\u0637\u0628\u062C\u062D]$', word):
        rules.append({
            "rule": "Qalqalah",
            "color": "#E65100",
            "description": "Add slight bounce/echo to this letter"
        })

    ikhfa_letters = 'تثجدذزسشصضطظفقك'
    if re.search(r'\u0646\u0652$|[\u064B\u064C\u064D]$', word) and next_word:
        if len(next_word) > 0 and next_word[0] in ikhfa_letters:
            rules.append({
                "rule": "Ikhfa",
                "color": "#6A1B9A",
                "description": "Partially hide the noon sound"
            })

    idgham_letters = 'ينملو'
    if re.search(r'\u0646\u0652$|[\u064B\u064C\u064D]$', word) and next_word:
        if len(next_word) > 0 and next_word[0] in idgham_letters:
            rules.append({
                "rule": "Idgham",
                "color": "#B71C1C",
                "description": "Merge noon into next letter"
            })

    if re.search(r'\u0646\u0652$|[\u064B\u064C\u064D]$', word) and next_word:
        if len(next_word) > 0 and next_word[0] == 'ب':
            rules.append({
                "rule": "Iqlab",
                "color": "#880E4F",
                "description": "Convert noon to meem sound"
            })

    izhar_letters = 'ءهعحغخ'
    if re.search(r'\u0646\u0652$|[\u064B\u064C\u064D]$', word) and next_word:
        if len(next_word) > 0 and next_word[0] in izhar_letters:
            rules.append({
                "rule": "Izhar",
                "color": "#00695C",
                "description": "Pronounce noon clearly"
            })

    if '\u0651' in word:
        rules.append({
            "rule": "Shadda",
            "color": "#F57F17",
            "description": "Double this letter with emphasis"
        })

    if '\u0652' in word and not any(r["rule"] == "Qalqalah" for r in rules):
        rules.append({
            "rule": "Sukoon",
            "color": "#37474F",
            "description": "Stop vowel sound completely"
        })

    return rules

# ── Qari audio download karo ──────────────────────────────────────────────────
def download_qari(surah, ayah):
    s   = str(surah).zfill(3)
    a   = str(ayah).zfill(3)
    cache_key = f"{surah}:{ayah}"
    url = f"https://verses.quran.com/Alafasy/mp3/{s}{a}.mp3"

    if cache_key in qari_cache and os.path.exists(qari_cache[cache_key]):
        return qari_cache[cache_key], url

    headers = {'User-Agent': 'Mozilla/5.0'}
    try:
        r = requests.get(url, timeout=15, headers=headers)
        if r.status_code == 200 and len(r.content) > 1000:
            os.makedirs(QARI_CACHE_DIR, exist_ok=True)
            save_path = os.path.join(QARI_CACHE_DIR, f"qari_{surah}_{ayah}.mp3")

            with open(save_path, "wb") as tmp:
                tmp.write(r.content)

            qari_cache[cache_key] = save_path
            return save_path, url
    except:
        pass
    return None, url

@app.route("/api/prefetch-qari", methods=["GET"])
def prefetch_qari():
    surah = request.args.get("surah", "1")
    ayah = request.args.get("ayah", "1")
    path, url = download_qari(surah, ayah)
    if path:
        return jsonify({"success": True, "cached": True, "url": url})
    return jsonify({"success": False, "url": url})

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

def _normalize_mfcc(mfcc):
    if mfcc is None or mfcc.size == 0:
        return mfcc
    mean = np.mean(mfcc, axis=1, keepdims=True)
    std = np.std(mfcc, axis=1, keepdims=True) + 1e-8
    return (mfcc - mean) / std

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

# ── HYBRID SCORING SYSTEM ──────────────────────────────────────────────────
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
            user_norm = user_norm[:, ::max(1, user_norm.shape[1]//max_frames)]
        if qari_norm.shape[1] > max_frames:
            qari_norm = qari_norm[:, ::max(1, qari_norm.shape[1]//max_frames)]

        local_cost = cosine_distances(user_norm.T, qari_norm.T)
        D, wp = librosa.sequence.dtw(C=local_cost, step_sizes_sigma=np.array([[1, 1], [0, 1], [1, 0]]))

        path_len = max(1, len(wp))
        avg_path_cost = float(D[-1, -1]) / path_len

        duration_ratio = min(user_mfcc.shape[1], qari_mfcc.shape[1]) / max(1, max(user_mfcc.shape[1], qari_mfcc.shape[1]))
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
            next_word = correct_words[idx+1] if idx+1 < len(correct_words) else ""
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
        (audio_quality_score * 0.20) +
        (phoneme_accuracy_score * 0.60) +
        (tajweed_timing_score * 0.20)
    )
    return float(round(hybrid_score, 1))

def _get_rule_correction(rule_name, word_arabic, user_said):
    corrections = {
        "Madd Tabee'i": {
            "message": f"'{word_arabic}' — Madd (Elongation) was too short or missing.",
            "how_to_fix": "Extend the vowel sound for exactly 2 counts (about 0.4-0.5 seconds). "
                          "Count '1-2' in your mind while holding the sound. "
                          "The letters Alef (ا), Waw (و), and Yaa (ي) after their matching vowels must be elongated.",
            "duration": "2 counts (~0.5 sec)"
        },
        "Madd Muttasil": {
            "message": f"'{word_arabic}' — Connected Madd must be extended longer.",
            "how_to_fix": "When a Madd letter is followed by Hamza (ء) in the SAME word, "
                          "you must extend for 4-5 counts. Count '1-2-3-4' slowly. "
                          "This is obligatory — you cannot shorten it.",
            "duration": "4-5 counts (~1 sec)"
        },
        "Madd Munfasil": {
            "message": f"'{word_arabic}' — Separated Madd requires longer elongation.",
            "how_to_fix": "When a Madd letter ends a word and the next word starts with Hamza, "
                          "extend for 4-5 counts in connected recitation. "
                          "Example: إِنَّا أَعْطَيْنَاكَ — extend the 'naa' sound.",
            "duration": "4-5 counts (~1 sec)"
        },
        "Madd Lazim": {
            "message": f"'{word_arabic}' — Obligatory Madd must always be 6 counts.",
            "how_to_fix": "This Madd is OBLIGATORY — it must always be exactly 6 counts. "
                          "Never make it shorter. Count '1-2-3-4-5-6' while holding the sound. "
                          "This occurs when a Madd letter is followed by Sukoon or Shadda.",
            "duration": "6 counts (~1.5 sec)"
        },
        "Ghunnah": {
            "message": f"'{word_arabic}' — Ghunnah (nasal sound) was missing or weak.",
            "how_to_fix": "When Noon (ن) or Meem (م) has a Shadda, you must produce a nasal sound "
                          "through your NOSE for 2 counts. "
                          "Test: pinch your nose while saying it — the sound should change. "
                          "If it doesn't change, you're not using your nose correctly.",
            "duration": "2 counts (~0.5 sec)"
        },
        "Qalqalah Major": {
            "message": f"'{word_arabic}' — Strong Qalqalah echo was not applied when stopping.",
            "how_to_fix": "When stopping on a word ending with ق ط ب ج د, you must add a STRONG echo/bounce. "
                          "The sound should echo clearly from your throat or lips. "
                          "Practice: say the letter and let it vibrate — like a bouncing ball sound.",
            "duration": "Brief bounce"
        },
        "Qalqalah Minor": {
            "message": f"'{word_arabic}' — Slight Qalqalah echo missing in the middle of word.",
            "how_to_fix": "When ق ط ب ج د has Sukoon in the MIDDLE of a word, add a slight echo. "
                          "It should be subtle — not as strong as Major Qalqalah. "
                          "Just enough to complete the letter sound properly.",
            "duration": "Brief subtle bounce"
        },
        "Ikhfa": {
            "message": f"'{word_arabic}' — Ikhfa (hidden Noon) was not applied correctly.",
            "how_to_fix": "When Noon Sakinah or Tanwin is followed by one of 15 letters "
                          "(ت ث ج د ذ ز س ش ص ض ط ظ ف ق ك), you must HIDE the Noon sound. "
                          "It should be between Izhar (clear) and Idgham (merged). "
                          "Hold a nasal sound for 2 counts without fully saying the Noon.",
            "duration": "2 counts nasal (~0.5 sec)"
        },
        "Idgham with Ghunnah": {
            "message": f"'{word_arabic}' — Idgham with Ghunnah: Noon must merge into next letter with nasal.",
            "how_to_fix": "When Noon Sakinah ends a word and next word starts with ي ن م و, "
                          "MERGE the Noon completely into the next letter. "
                          "Add Ghunnah (nasal sound) for 2 counts. "
                          "The Noon should completely disappear — only the merged sound remains.",
            "duration": "2 counts with nasal"
        },
        "Idgham without Ghunnah": {
            "message": f"'{word_arabic}' — Idgham without Ghunnah: merge Noon silently into ل or ر.",
            "how_to_fix": "When Noon Sakinah is followed by ل or ر, merge the Noon completely "
                          "into the next letter WITHOUT any nasal sound. "
                          "The transition should be smooth and silent — no nasal at all.",
            "duration": "Silent merge"
        },
        "Iqlab": {
            "message": f"'{word_arabic}' — Iqlab: Noon must convert to Meem sound before ب.",
            "how_to_fix": "When Noon Sakinah or Tanwin comes before ب (Ba), "
                          "convert the Noon sound to MEEM. "
                          "Close your lips slightly (as if saying Meem) and hold nasal for 2 counts. "
                          "Look for the small م written above ن in the Quran — that marks Iqlab.",
            "duration": "2 counts nasal"
        },
        "Izhar": {
            "message": f"'{word_arabic}' — Izhar: Noon must be pronounced clearly, no nasal.",
            "how_to_fix": "When Noon Sakinah or Tanwin is followed by ء ه ع ح غ خ, "
                          "pronounce the Noon CLEARLY and COMPLETELY. "
                          "NO nasal sound at all. Open your throat fully. "
                          "These 6 are throat letters — they require clear pronunciation.",
            "duration": "Clear, no nasal"
        },
        "Shadda": {
            "message": f"'{word_arabic}' — Shadda (double letter) was not emphasized enough.",
            "how_to_fix": "The Shadda doubles the letter. Say it TWICE — "
                          "first with Sukoon (closed), then with its vowel. "
                          "Example: إِنَّ = in-NA (the Noon is said twice with stress). "
                          "The stress should be clear and emphasized.",
            "duration": "Double emphasis"
        },
        "Tafkhim": {
            "message": f"'{word_arabic}' — Heavy letter (Tafkhim) was pronounced too lightly.",
            "how_to_fix": "The letters ص ض ط ظ ق غ خ are HEAVY letters. "
                          "Your mouth should feel FULL when saying them. "
                          "Pull your tongue slightly back and raise it toward the roof of your mouth. "
                          "Think of the sound filling your entire mouth.",
            "duration": "Full mouth pronunciation"
        },
    }

    return corrections.get(rule_name, {
        "message": f"'{word_arabic}' — Incorrect pronunciation.",
        "how_to_fix": f"Review the {rule_name} rule and practice this word carefully.",
        "duration": ""
    })

def _get_rule_praise(rule_name, word_arabic):
    praise = {
        "Madd Tabee'i":    f"✓ '{word_arabic}' — Good Madd elongation (2 counts)",
        "Madd Muttasil":   f"✓ '{word_arabic}' — Excellent Connected Madd (4-5 counts)",
        "Ghunnah":         f"✓ '{word_arabic}' — Good Ghunnah nasal sound",
        "Qalqalah Major":  f"✓ '{word_arabic}' — Good strong Qalqalah echo",
        "Qalqalah Minor":  f"✓ '{word_arabic}' — Good subtle Qalqalah",
        "Ikhfa":           f"✓ '{word_arabic}' — Good Ikhfa application",
        "Idgham with Ghunnah": f"✓ '{word_arabic}' — Correct Idgham with nasal",
        "Shadda":          f"✓ '{word_arabic}' — Good Shadda emphasis",
        "Tafkhim":         f"✓ '{word_arabic}' — Correct heavy pronunciation",
    }
    return praise.get(rule_name, f"✓ '{word_arabic}' — Correct")

def generate_teacher_feedback(word_results, correct_text, transcribed_text, final_score):
    feedback_items = []

    correct_words = correct_text.split()

    for idx, word in enumerate(word_results):
        word_arabic = word.get("word", "")
        status      = word.get("status", "")
        transcribed = word.get("transcribed", "")
        tajweed_rules = _unique_rules(word.get("tajweed_rules", []))

        if status == "correct":
            for rule in tajweed_rules[:2]:
                rule_name = rule.get("rule", "")
                if not rule_name:
                    continue
                feedback_items.append({
                    "word": word_arabic,
                    "type": "correct",
                    "rule": rule_name,
                    "message": _get_rule_praise(rule_name, word_arabic),
                    "severity": "good",
                    "color": rule.get("color", "#2E7D32")
                })

        elif status in ["wrong", "close"]:
            if tajweed_rules:
                primary_rule = tajweed_rules[0]
                rule_name = primary_rule.get("rule", "")
                tip = _get_rule_correction(rule_name, word_arabic, transcribed)
                if tip:
                    if status == "close":
                        close_message = tip["message"].replace("was too short or missing", "may need a little more control")
                        close_fix = tip["how_to_fix"].replace("must", "should").replace("always", "usually")
                    else:
                        close_message = tip["message"]
                        close_fix = tip["how_to_fix"]

                    feedback_items.append({
                        "word": word_arabic,
                        "type": "error",
                        "rule": rule_name,
                        "message": close_message,
                        "how_to_fix": close_fix,
                        "duration": tip.get("duration", ""),
                        "severity": "error",
                        "color": primary_rule.get("color", "#B71C1C")
                    })

                if len(tajweed_rules) > 1:
                    extra_rules = ", ".join(r.get("rule", "") for r in tajweed_rules[1:3] if r.get("rule", ""))
                    if extra_rules:
                        feedback_items.append({
                            "word": word_arabic,
                            "type": "error",
                            "rule": "",
                            "message": f"Also review: {extra_rules}.",
                            "how_to_fix": "Focus on one rule at a time, then add the next layer of Tajweed.",
                            "duration": "",
                            "severity": "error",
                            "color": "#F57C00"
                        })

        elif status == "missing":
            feedback_items.append({
                "word": word_arabic,
                "type": "missing",
                "rule": "Missing Word",
                "message": f"You skipped the word '{word_arabic}'",
                "how_to_fix": f"Make sure to recite '{word_arabic}' clearly. Do not skip any word.",
                "duration": "",
                "severity": "critical",
                "color": "#B71C1C"
            })

    errors   = [f for f in feedback_items if f["type"] == "error"]
    missing  = [f for f in feedback_items if f["type"] == "missing"]

    if final_score >= 85:
        summary = "Mashallah! Your recitation is excellent. Minor refinements needed."
    elif final_score >= 70:
        summary = f"Good recitation! Focus on {len(errors)} Tajweed corrections below."
    elif final_score >= 55:
        summary = f"Decent attempt. You have {len(errors)} errors and {len(missing)} missing words to fix."
    elif final_score >= 40:
        summary = f"Needs practice. Listen to the Qari carefully and repeat. {len(missing)} words were skipped."
    else:
        summary = "Please listen to the Qari first, then try recording. Focus on one word at a time."

    return {
        "summary": summary,
        "total_errors": len(errors),
        "total_missing": len(missing),
        "feedback_items": feedback_items,
        "priority_fix": feedback_items[0] if feedback_items else None
    }

# ── Routes ────────────────────────────────────────────────────────────────────
@app.route("/", methods=["GET"])
@app.route("/api/health", methods=["GET"])
def health():
    return jsonify({
        "status": "ReciteRight backend chal raha hai ✅",
        "model_loaded": True,
        "reference_ayaat": len(file_names),
        "api_version": "2.0"
    })

@app.route("/qaris", methods=["GET"])
def get_qaris():
    return jsonify({"qaris": [
        {"id": "7",  "name": "Mishary Rashid Alafasy"},
        {"id": "1",  "name": "AbdulBaset AbdulSamad"},
        {"id": "5",  "name": "Mahmoud Khalil Al-Hussary"},
        {"id": "12", "name": "Saad Al-Ghamdi"},
        {"id": "9",  "name": "Abdul Rahman Al-Sudais"},
    ]})

@app.route("/api/qari-url", methods=["GET"])
def qari_url():
    surah = request.args.get("surah", "1")
    ayah  = request.args.get("ayah",  "1")
    s = str(surah).zfill(3)
    a = str(ayah).zfill(3)
    url = f"https://verses.quran.com/Alafasy/mp3/{s}{a}.mp3"
    return jsonify({"url": url})

@app.route("/api/compare", methods=["POST"])
@with_timeout(COMPARE_TIMEOUT_SECONDS)
def compare():
    start = time.time()

    if "audio" not in request.files:
        return jsonify({"error": "Audio file required", "success": False}), 400

    surah = request.form.get("surah", "1")
    ayah = request.form.get("ayah", "1")
    correct_text = request.form.get("correct_text", "").strip()

    user_tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".wav")
    user_tmp.close()
    request.files["audio"].save(user_tmp.name)

    try:
        y_check, sr_check = librosa.load(user_tmp.name, sr=16000, mono=True)
        audio_duration = len(y_check) / sr_check
        if audio_duration > 120:
            return jsonify({
                "success": False,
                "error": f"Audio too long ({audio_duration:.1f}s). Maximum is 120 seconds.",
                "reason": "audio_too_long"
            }), 422
    except Exception as e:
        print(f"⚠️ Audio length check failed: {e}")

    processed_path = None
    qari_path = None

    audio_cache = {}

    try:
        print(f"\n📝 === COMPARISON REQUEST ===")
        print(f"📂 Surah: {surah}, Ayah: {ayah}, Duration: {audio_duration:.1f}s")
        raw_speech_stats = _analyze_speech_activity(user_tmp.name)
        print(f"🗣️ Raw speech activity: {raw_speech_stats}")
        if not raw_speech_stats.get("speech_detected", False):
            return jsonify({
                "success": False,
                "error": "No recitation detected. Please recite clearly and try again.",
                "reason": "no_speech_detected",
                "speech_activity": raw_speech_stats
            }), 422

        if not correct_text:
            try:
                api_url = f"https://api.quran.com/api/v4/verses/by_key/{surah}:{ayah}?fields=text_uthmani"
                resp = requests.get(api_url, timeout=10)
                correct_text = resp.json()["verse"]["text_uthmani"]
            except:
                correct_text = ""

        processed_path = preprocess_audio(user_tmp.name)

        speech_stats = _analyze_speech_activity(processed_path)
        print(f"🗣️ Speech activity: {speech_stats}")
        if not speech_stats.get("speech_detected", False):
            return jsonify({
                "success": False,
                "error": "No recitation detected. Please recite clearly and try again.",
                "reason": "no_speech_detected",
                "speech_activity": speech_stats
            }), 422

        transcription_meta = transcribe_audio(processed_path, expected_text=correct_text)
        t_transcribe = time.time() - start
        print(f"⏱️ Transcription: {t_transcribe:.1f}s")

        transcribed_text = (transcription_meta or {}).get("text", "").strip()
        if not _passes_transcription_gate(transcription_meta, correct_text=correct_text):
            return jsonify({
                "success": False,
                "error": "Low-confidence transcription. Please recite louder and closer to microphone.",
                "reason": "low_transcription_confidence",
                "speech_activity": speech_stats,
                "transcription_meta": {
                    "segment_count": int(transcription_meta.get("segment_count", 0)),
                    "mean_no_speech_prob": float(transcription_meta.get("mean_no_speech_prob", 1.0)),
                    "avg_logprob": float(transcription_meta.get("avg_logprob", -5.0)),
                    "language_probability": float(transcription_meta.get("language_probability", 0.0)),
                }
            }), 422
        if not transcribed_text:
            return jsonify({"error": "Transcription failed", "success": False}), 500

        print(f"✍️ User transcribed: '{transcribed_text}'")

        if not correct_text:
            correct_text = transcribed_text

        correct_text = clean_quran_text(correct_text)

        print(f"✅ Correct text: '{correct_text}'")

        user_words = transcribed_text.split()
        correct_words = correct_text.split()
        print(f"📊 User words: {len(user_words)}, Correct words: {len(correct_words)}")
        aligned = align_words_smart(user_words, correct_words)

        for a in aligned:
            if a["correct_word"]:
                status_icon = "✅" if a["status"] == "correct" else "⚠️" if a["status"] == "close" else "❌"
                print(f"  {status_icon} '{a['correct_word']}' vs '{a['user_word']}' [{a['status']}] ({a['similarity']})")

        word_results = []
        rules_summary = {}

        for idx, item in enumerate(aligned):
            correct_word = item["correct_word"]
            if not correct_word:
                continue

            item_idx = item["index"]
            next_word = correct_words[item_idx+1] if item_idx+1 < len(correct_words) else ""
            prev_word = correct_words[item_idx-1] if item_idx > 0 else ""

            tajweed_rules = analyze_tajweed(correct_word, next_word, prev_word)
            phonemes = extract_phonemes(correct_word)

            for rule in tajweed_rules:
                rule_name = rule["rule"]
                rules_summary[rule_name] = rules_summary.get(rule_name, 0) + 1

            if item["status"] == "correct":
                display_color = "green"
            elif item["status"] == "close":
                display_color = "orange"
            elif item["status"] == "missing":
                display_color = "red"
            elif item["status"] == "extra":
                display_color = "yellow"
            else:
                display_color = "orange"

            word_results.append({
                "word": correct_word,
                "transcribed": item["user_word"],
                "status": item["status"],
                "color": display_color,
                "similarity": item.get("similarity", 0.0),
                "phonemes": phonemes,
                "tajweed_rules": [{"rule": r.get("rule", ""), "color": r.get("color", "")} for r in tajweed_rules]
            })

        correct_count = sum(1 for w in word_results if w["status"] == "correct")
        close_count = sum(1 for w in word_results if w["status"] == "close")
        missing_count = sum(1 for w in word_results if w["status"] == "missing")
        extra_count = sum(1 for w in word_results if w["status"] == "extra")
        total_words = len([w for w in word_results if w["word"]])

        print(f"\n📈 SCORING BREAKDOWN:")
        print(f"  ✅ Correct: {correct_count}/{total_words}")
        print(f"  ⚠️ Close: {close_count}")
        print(f"  ❌ Missing: {missing_count}")
        print(f"  🔶 Extra: {extra_count}")

        word_accuracy = 0.0
        if total_words > 0:
            word_accuracy = (correct_count * 100 + close_count * 85) / total_words
            missing_penalty = (missing_count / total_words) * 15
            whisper_score = max(0, min(100, word_accuracy - missing_penalty))
        else:
            whisper_score = 0.0
        whisper_score = round(whisper_score, 1)

        print(f"  📝 Whisper Score (before penalty): {word_accuracy:.1f}")
        print(f"  📝 Missing Penalty: -{missing_count * 15}")
        print(f"  📝 Final Whisper Score: {whisper_score}")

        qari_path, qari_url = download_qari(surah, ayah)

        print(f"\n🎯 === HYBRID SCORING (3-Component) ===")

        audio_quality_score = 20.0
        dtw_score = 0.0
        direct_phoneme_score = 0.0
        scoring_debug = {
            "qari_audio_available": bool(qari_path),
            "fallbacks": []
        }
        if qari_path:
            try:
                user_y_raw, _ = librosa.load(processed_path, sr=16000)
                qari_y_raw, _ = librosa.load(qari_path, sr=16000)

                user_mfcc_raw = librosa.feature.mfcc(y=user_y_raw, sr=16000, n_mfcc=20)
                qari_mfcc_raw = librosa.feature.mfcc(y=qari_y_raw, sr=16000, n_mfcc=20)

                def cmvn_normalize(mfcc):
                    mean = np.mean(mfcc, axis=1, keepdims=True)
                    std = np.std(mfcc, axis=1, keepdims=True) + 1e-8
                    return (mfcc - mean) / std

                user_mfcc_norm = cmvn_normalize(user_mfcc_raw)
                qari_mfcc_norm = cmvn_normalize(qari_mfcc_raw)

                user_feat_norm = np.concatenate([
                    np.mean(user_mfcc_norm, axis=1),
                    np.std(user_mfcc_norm, axis=1)
                ])
                qari_feat_norm = np.concatenate([
                    np.mean(qari_mfcc_norm, axis=1),
                    np.std(qari_mfcc_norm, axis=1)
                ])

                sim = cosine_similarity([user_feat_norm], [qari_feat_norm])[0][0]
                audio_quality_score = round(float(max(0, sim)) * 100, 1)
                print(f"  🔊 [1/3] Audio Quality Score: {audio_quality_score}")
            except Exception as e:
                print(f"⚠️ Audio Quality error: {e}")
                audio_quality_score = 20.0
                scoring_debug["fallbacks"].append("audio_quality_default")
        else:
            print(f"  🔊 Could not download Qari audio (using default)")
            audio_quality_score = 20.0
            scoring_debug["fallbacks"].append("qari_audio_missing")

        phoneme_accuracy_score = 0.0
        t_phoneme_start = time.time()
        if qari_path:
            try:
                user_y, _ = librosa.load(processed_path, sr=16000, mono=True)
                qari_y, _ = librosa.load(qari_path, sr=16000, mono=True)

                user_mfcc = librosa.feature.mfcc(y=user_y, sr=16000, n_mfcc=13)
                qari_mfcc = librosa.feature.mfcc(y=qari_y, sr=16000, n_mfcc=13)

                dtw_score = compute_dtw_score(user_mfcc, qari_mfcc)
                direct_phoneme_score = compute_phoneme_accuracy(user_words, correct_words, aligned)

                if whisper_score >= 60:
                    phoneme_accuracy_score = (
                        whisper_score * 0.70 +
                        direct_phoneme_score * 0.20 +
                        dtw_score * 0.10
                    )
                else:
                    phoneme_accuracy_score = (
                        whisper_score * 0.40 +
                        direct_phoneme_score * 0.30 +
                        dtw_score * 0.30
                    )

                phoneme_accuracy_score = round(_clamp(phoneme_accuracy_score), 1)

                t_phoneme = time.time() - t_phoneme_start
                print(f"  📞 [2/3] Phoneme Accuracy Score: {phoneme_accuracy_score:.1f}")
                print(f"         (Whisper Floor: {whisper_score:.1f} | DTW: {dtw_score:.1f}% + Direct Phoneme: {direct_phoneme_score:.1f}%)")
                print(f"  ⏱️ Phoneme computation: {t_phoneme:.1f}s")
            except Exception as e:
                print(f"⚠️ Phoneme accuracy error: {e}")
                phoneme_accuracy_score = whisper_score
                scoring_debug["fallbacks"].append("phoneme_fallback_to_whisper")
        else:
            phoneme_accuracy_score = whisper_score
            scoring_debug["fallbacks"].append("phoneme_fallback_no_qari")

        tajweed_timing_score = 20.0
        t_tajweed_start = time.time()
        if qari_path:
            try:
                tajweed_timing_score = verify_tajweed_timing(correct_text, processed_path, qari_path)
                t_tajweed = time.time() - t_tajweed_start
                print(f"  ✅ [3/3] Tajweed Timing Score: {tajweed_timing_score:.1f}")
                print(f"  ⏱️ Tajweed computation: {t_tajweed:.1f}s")
            except Exception as e:
                print(f"⚠️ Tajweed timing error: {e}")
                tajweed_timing_score = 20.0
                scoring_debug["fallbacks"].append("tajweed_timing_default")

        confidence_multiplier = _compute_confidence_multiplier(
            speech_stats,
            transcription_meta,
            correct_words_count=len(correct_words),
            transcribed_words_count=len(user_words)
        )

        raw_hybrid_score = compute_hybrid_score(audio_quality_score, phoneme_accuracy_score, tajweed_timing_score)
        final_score = round(raw_hybrid_score * confidence_multiplier, 1)

        if whisper_score >= 80 and missing_count == 0:
            final_score = max(final_score, 65.0)
        elif whisper_score >= 65 and missing_count <= 1:
            final_score = max(final_score, 50.0)

        final_score = round(_clamp(final_score), 1)

        mfcc_score = audio_quality_score

        print(f"\n🏆 FINAL HYBRID SCORING:")
        print(f"  Audio Quality:      {audio_quality_score} × 0.20 = {audio_quality_score * 0.20:.1f}")
        print(f"  Phoneme Accuracy:   {phoneme_accuracy_score:.1f} × 0.60 = {phoneme_accuracy_score * 0.60:.1f}")
        print(f"  Tajweed Timing:     {tajweed_timing_score:.1f} × 0.20 = {tajweed_timing_score * 0.20:.1f}")
        print(f"  " + "="*50)
        print(f"  Raw Hybrid Score:   {raw_hybrid_score}")
        print(f"  Confidence Mult:    {confidence_multiplier:.3f}")
        print(f"  FINAL SCORE:        {final_score}")
        print(f"  GRADE:              {get_grade(final_score)}")

        elapsed = round((time.time() - start) * 1000, 1)
        print(f"⏱️ Inference time: {elapsed}ms\n")

        teacher_feedback = generate_teacher_feedback(
            word_results, request.form.get("correct_text_display", correct_text), transcribed_text, final_score)

        return jsonify({
            "success": True,
            "overall_score": float(final_score),
            "grade": str(get_grade(final_score)),
            "feedback": str(get_feedback(final_score)),
            "teacher_feedback": teacher_feedback,
            "transcribed_text": str(transcribed_text),
            "correct_text": str(correct_text),
            "word_results": word_results,
            "tajweed_summary": {
                "total_rules_detected": int(sum(rules_summary.values())),
                "rules_breakdown": {str(k): int(v) for k, v in rules_summary.items()}
            },
            "metrics": {
                "whisper_score": float(whisper_score),
                "dtw_score": float(dtw_score),
                "direct_phoneme_score": float(direct_phoneme_score),
                "mfcc_score": float(mfcc_score),
                "phoneme_accuracy_score": float(phoneme_accuracy_score),
                "tajweed_timing_score": float(tajweed_timing_score),
                "final_score": float(final_score)
            },
            "hybrid_scoring": {
                "raw_hybrid_score": float(raw_hybrid_score),
                "confidence_multiplier": float(confidence_multiplier),
                "audio_quality_score": float(audio_quality_score),
                "dtw_score": float(dtw_score),
                "direct_phoneme_score": float(direct_phoneme_score),
                "phoneme_accuracy_score": float(phoneme_accuracy_score),
                "tajweed_timing_score": float(tajweed_timing_score),
                "method": "Hybrid (Audio 20% + Phoneme 60% + Tajweed 20%)",
                "dtw_enabled": True,
                "debug": scoring_debug,
                "explanation": {
                    "audio_quality": "Overall voice quality, timbre, and energy distribution",
                    "phoneme_accuracy": "DTW-aligned phoneme matching (tempo-invariant)",
                    "tajweed_timing": "Verification of Tajweed rule timing and application",
                    "confidence_multiplier": "Guards against silence/low-confidence ASR by down-weighting the final score"
                }
            },
            "speech_activity": speech_stats,
            "raw_speech_activity": raw_speech_stats,
            "reference_audio_url": str(qari_url) if qari_path else "",
            "inference_time_ms": float(elapsed),
            "surah": str(surah),
            "ayah": str(ayah)
        })

    except Exception as e:
        import traceback
        error_trace = traceback.format_exc()
        print(f"\n❌ ERROR IN /api/compare:")
        print(error_trace)
        return jsonify({"error": str(e), "success": False, "traceback": error_trace}), 500

    finally:
        for path in [user_tmp.name, processed_path]:
            if path and os.path.exists(path):
                try:
                    os.unlink(path)
                except:
                    pass

@app.route("/api/predict-base64", methods=["POST"])
def predict():
    return jsonify({
        "success":        True,
        "detected_rules": ["Madd", "Ghunnah"],
        "inference_time_ms": 120,
        "prediction": {
            "top_rule":       "Madd",
            "top_confidence": 0.87,
        }
    })

@app.route("/api/transcribe", methods=["POST"])
def transcribe():
    start = time.time()

    if "audio" not in request.files:
        return jsonify({"error": "Audio file required", "success": False}), 400

    correct_text = request.form.get("correct_text", "").strip()
    if not correct_text:
        return jsonify({"error": "correct_text field required", "success": False}), 400

    audio_file = request.files["audio"]
    audio_tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".wav")
    audio_file.save(audio_tmp.name)
    audio_tmp.close()

    try:
        print(f"🎤 Transcribing audio: {audio_tmp.name}")
        speech_stats = _analyze_speech_activity(audio_tmp.name)
        if not speech_stats.get("speech_detected", False):
            return jsonify({
                "success": False,
                "error": "No recitation detected. Please recite clearly and try again.",
                "reason": "no_speech_detected",
                "speech_activity": speech_stats,
                "similarity_score": 0.0
            }), 422

        transcription_meta = transcribe_audio(audio_tmp.name, expected_text=correct_text)
        transcribed_text = transcription_meta.get("text", "").strip()
        if not _passes_transcription_gate(transcription_meta, correct_text=correct_text):
            return jsonify({
                "success": False,
                "error": "Low-confidence transcription. Please recite louder and closer to microphone.",
                "reason": "low_transcription_confidence",
                "speech_activity": speech_stats,
                "transcription_meta": {
                    "segment_count": int(transcription_meta.get("segment_count", 0)),
                    "mean_no_speech_prob": float(transcription_meta.get("mean_no_speech_prob", 1.0)),
                    "avg_logprob": float(transcription_meta.get("avg_logprob", -5.0)),
                    "language_probability": float(transcription_meta.get("language_probability", 0.0)),
                },
                "similarity_score": 0.0
            }), 422

        print(f"✅ Transcription: {transcribed_text}")

        ratio = SequenceMatcher(
            None,
            normalize_arabic_simple(transcribed_text),
            normalize_arabic_simple(correct_text)
        ).ratio()
        similarity_score = round(ratio * 100, 1)

        transcribed_words = transcribed_text.split()
        correct_words = correct_text.split()

        word_results = []
        for i in range(max(len(transcribed_words), len(correct_words))):
            trans_word = transcribed_words[i] if i < len(transcribed_words) else ""
            correct_word = correct_words[i] if i < len(correct_words) else ""

            if trans_word and correct_word:
                word_ratio = SequenceMatcher(
                    None,
                    normalize_arabic_simple(correct_word),
                    normalize_arabic_simple(trans_word)
                ).ratio()
            else:
                word_ratio = 0.0

            is_correct = word_ratio >= 0.7

            word_results.append({
                "word": correct_word if correct_word else trans_word,
                "transcribed": trans_word if trans_word else correct_word,
                "correct": is_correct,
                "color": "green" if is_correct else "red"
            })

        if similarity_score >= 90:
            feedback = "Excellent! Your transcription matches very well! 🌟"
        elif similarity_score >= 75:
            feedback = "Very good! Minor differences in transcription. 👍"
        elif similarity_score >= 60:
            feedback = "Good effort! Review the words highlighted in red. 📖"
        elif similarity_score >= 40:
            feedback = "Keep practicing! Focus on the different words. 🎧"
        else:
            feedback = "Listen to the Qari again and try once more. 🔁"

        elapsed = round((time.time() - start) * 1000, 1)

        return jsonify({
            "success": True,
            "transcribed_text": transcribed_text,
            "correct_text": correct_text,
            "similarity_score": similarity_score,
            "word_results": word_results,
            "feedback": feedback,
            "inference_time_ms": elapsed
        })

    except Exception as e:
        print(f"❌ Transcription error: {str(e)}")
        return jsonify({
            "success": False,
            "error": f"Transcription failed: {str(e)}"
        }), 500
    finally:
        if os.path.exists(audio_tmp.name):
            os.unlink(audio_tmp.name)

# ════════════════════════════════════════════════════════════════════════════════
# SETUP GAMIFICATION ROUTES
# ════════════════════════════════════════════════════════════════════════════════
try:
    from gamification_routes import setup_gamification_routes
    setup_gamification_routes(app)
    print("✅ Gamification routes initialized")
except Exception as e:
    print(f"⚠️ Warning: Could not load gamification routes: {e}")
    import traceback
    traceback.print_exc()

# ════════════════════════════════════════════════════════════════════════════════
# SETUP SESSION & PROGRESS ROUTES
# ════════════════════════════════════════════════════════════════════════════════
try:
    from session_routes import setup_session_routes
    setup_session_routes(app)
    print("✅ Session and progress routes initialized")
except Exception as e:
    print(f"⚠️ Warning: Could not load session routes: {e}")
    import traceback
    traceback.print_exc()

if __name__ == "__main__":
    print("🚀 API Running at http://0.0.0.0:8000/")
    app.run(host='0.0.0.0', port=8000, debug=True, use_reloader=False, threaded=True)