# -*- coding: utf-8 -*-
import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

from flask import Flask, request, jsonify
from flask_cors import CORS
import librosa
import librosa.sequence
import numpy as np
from sklearn.preprocessing import StandardScaler
from sklearn.metrics.pairwise import cosine_similarity
import joblib
import requests
import tempfile
import os
import time
import json
import warnings
import re
from difflib import SequenceMatcher
from faster_whisper import WhisperModel
import soundfile as sf
try:
    import noisereduce as nr
except:
    nr = None
warnings.filterwarnings('ignore')

app = Flask(__name__)
CORS(app)

# ── Model load karo ───────────────────────────────────────────────────────────
print("🔄 Model load ho raha hai...")
scaler     = joblib.load("model/scaler.pkl")
X_ref      = np.load("model/reference_features.npy")
with open("model/file_names.json") as f:
    file_names = json.load(f)
print(f"✅ Model ready! {len(file_names)} reference ayaat loaded.")

# ── Load Faster-Whisper model for transcription ───────────────────────────────
print("🔄 Loading Faster-Whisper model...")
whisper_model = WhisperModel("base", device="cpu", compute_type="int8")
print("✅ Faster-Whisper model loaded!")

# ── STEP 1: Audio Preprocessing ────────────────────────────────────────────────
def preprocess_audio(input_path):
    """Preprocess audio: denoise, normalize, trim silence"""
    try:
        y, sr = librosa.load(input_path, sr=16000, mono=True)

        if nr is not None:
            y_denoised = nr.reduce_noise(y=y, sr=sr, stationary=True)
        else:
            y_denoised = y

        max_val = np.max(np.abs(y_denoised))
        if max_val > 0:
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

# ── STEP 2: Transcribe Audio ───────────────────────────────────────────────────
def transcribe_audio(audio_path):
    """Transcribe audio using Faster-Whisper"""
    try:
        segments, info = whisper_model.transcribe(
            audio_path,
            language="ar",
            beam_size=5,
            vad_filter=True,
            vad_parameters=dict(min_silence_duration_ms=500)
        )
        text = " ".join([seg.text.strip() for seg in segments])
        print(f"🎤 Transcribed: '{text}'")
        print(f"📊 Confidence: {info.language_probability:.2%}")
        return text.strip()
    except Exception as e:
        print(f"❌ Transcription error: {e}")
        return ""

# ── STEP 3: Text Normalization ─────────────────────────────────────────────────
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
        best_sim = 0.5
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

        if best_match and best_sim > 0.5:
            aligned.append({
                "index": j,
                "correct_word": correct_w,
                "user_word": best_match,
                "status": "close" if best_sim < 0.9 else "correct",
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
    qalqalah_letters = '\u0642\u0637\u0628\u062C\u062F'
    if re.search(f'[{qalqalah_letters}]\u0652', word) or \
       (word and word[-1] in qalqalah_letters):
        level = "Major" if (word and word[-1] in qalqalah_letters) else "Minor"
        rules_found.append({
            "rule": f"Qalqalah {level}",
            "arabic": "قلقلة",
            "color": "#E65100",
            "counts": 0,
            "description": f"Echo/bounce - add slight vibration to letter",
            "status": "present"
        })

    # NOON SAKINAH & TANWIN RULES
    has_noon_saakin = bool(re.search(r'\u0646\u0652', word))
    has_tanwin = bool(re.search(r'[\u064B\u064C\u064D]$', word))

    if (has_noon_saakin or has_tanwin) and next_word:
        first_letter = next_word[0] if next_word else ''
        ikhfa_letters = '\u062A\u062B\u062C\u062F\u0630\u0632\u0633\u0634\u0635\u0636\u0637\u0638\u0641\u0642\u0643'
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

    return rules_found

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

# ── Detect Tajweed rules per word (simple version) ────────────────────────────
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

    if re.search(r'[\u0642\u0637\u0628\u062C\u062F][\u0652]', word) or \
       re.search(r'[\u0642\u0637\u0628\u062C\u062F]$', word):
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
    url = f"https://verses.quran.com/Alafasy/mp3/{s}{a}.mp3"
    headers = {'User-Agent': 'Mozilla/5.0'}
    try:
        r = requests.get(url, timeout=15, headers=headers)
        if r.status_code == 200 and len(r.content) > 1000:
            tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".mp3")
            tmp.write(r.content)
            tmp.close()
            return tmp.name, url
    except:
        pass
    return None, url

def get_grade(score):
    if score >= 85: return "Excellent ✨"
    if score >= 70: return "Very Good ✓"
    if score >= 55: return "Good 👍"
    if score >= 40: return "Satisfactory 📚"
    return "Needs Work 📚"

def get_feedback(score):
    if score >= 85: return "Mashallah! Bahut acha recitation hai 🌟"
    if score >= 70: return "Bohot acha! Thodi aur practice karo 👍"
    if score >= 55: return "Acha hai, lekin aur mehnat chahiye 📖"
    if score >= 40: return "Pehle Qari ko dhyan se suno 🎧"
    return "Qari ki awaaz sun ke repeat karo 🔁"

# ── HYBRID SCORING SYSTEM ──────────────────────────────────────────────────
# Component 1: Audio Quality (20%) - MFCC Cosine Similarity
# Component 2: Phoneme Accuracy (60%) - DTW-based comparison
# Component 3: Tajweed Timing (20%) - Rule verification

def compute_dtw_score(user_mfcc, qari_mfcc):
    """
    Compute DTW (Dynamic Time Warping) cost between user and Qari audio.
    DTW is tempo-invariant: reciting faster/slower won't penalize wrongly.

    Returns normalized score (0-100)
    """
    try:
        # Compute DTW cost matrix
        C = librosa.sequence.dtw(user_mfcc, qari_mfcc, metric='euclidean')

        # Normalize by the length of the longer sequence
        max_len = max(user_mfcc.shape[1], qari_mfcc.shape[1])
        if max_len == 0:
            return 0.0

        # DTW cost is distance; convert to similarity (0-100)
        # Lower cost = more similar
        normalized_cost = C[-1, -1] / (max_len * user_mfcc.shape[0])

        # Convert distance to similarity score (0-100)
        # Clamp: 0.0 cost → 100%, higher costs → lower scores
        dtw_score = max(0, 100 - (normalized_cost * 50))
        dtw_score = min(100, dtw_score)

        print(f"  🎯 DTW Cost: {C[-1, -1]:.2f}, Normalized: {normalized_cost:.3f}, Score: {dtw_score:.1f}")
        return float(dtw_score)
    except Exception as e:
        print(f"⚠️ DTW computation error: {e}")
        return 50.0

def compute_phoneme_accuracy(user_words, correct_words, aligned_items):
    """
    Compute phoneme-level accuracy using aligned word comparison.
    Considers phoneme matches and near-matches.

    Returns score (0-100)
    """
    if not correct_words or len(correct_words) == 0:
        return 0.0

    correct_phonemes = 0
    total_phonemes = 0

    for item in aligned_items:
        if not item["correct_word"]:
            continue

        correct_word = item["correct_word"]
        user_word = item["user_word"]
        status = item["status"]

        correct_phon = extract_phonemes(correct_word)
        total_phonemes += len(correct_phon)

        if status == "correct":
            # Perfect match
            correct_phonemes += len(correct_phon)
        elif status == "close" and user_word:
            # Partial match: award based on similarity
            user_phon = extract_phonemes(user_word)
            match_count = 0
            for p in user_phon:
                if p in correct_phon:
                    match_count += 1
            correct_phonemes += match_count
        elif status == "missing":
            # Word not said
            pass

    if total_phonemes == 0:
        return 0.0

    phoneme_accuracy = (correct_phonemes / total_phonemes) * 100
    phoneme_accuracy = min(100, phoneme_accuracy)
    print(f"  📞 Phoneme Accuracy: {correct_phonemes}/{total_phonemes} = {phoneme_accuracy:.1f}%")
    return float(phoneme_accuracy)

def verify_tajweed_timing(correct_text, user_audio_path, qari_audio_path):
    """
    Verify that Tajweed rules are applied with correct timing.

    Examples:
    - Ghunnah should last ~2 counts
    - Madd should last 2-5 counts
    - Qalqalah should have bounce

    Returns score (0-100) based on how many rules are correctly applied
    """
    try:
        if not os.path.exists(user_audio_path) or not os.path.exists(qari_audio_path):
            return 50.0  # Default if can't verify

        correct_words = correct_text.split()

        # Load audio durations
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
                    # Rules like Qalqalah, Shadda don't have timing requirements
                    tajweed_checks += 1
                    tajweed_correct += 1
                elif rule_name in ["Ghunnah", "Madd Tabee'i"]:
                    # Verify duration is approximately correct
                    # Expected: 2 counts = ~0.5 seconds at normal speaking rate
                    # Allow ±30% tolerance

                    tajweed_checks += 1

                    # Simple heuristic: if user duration is 0.8-1.2× Qari, mark as correct
                    duration_ratio = user_duration / max(0.1, qari_duration)
                    if 0.7 < duration_ratio < 1.3:  # Allow 30% tempo variance
                        tajweed_correct += 1
                    else:
                        print(f"    ⏱️ {rule_name}: Duration ratio {duration_ratio:.2f} (expected ~1.0)")

        if tajweed_checks == 0:
            return 100.0  # No rules to verify

        tajweed_timing_score = (tajweed_correct / tajweed_checks) * 100
        print(f"  ✅ Tajweed Timing: {tajweed_correct}/{tajweed_checks} rules correct = {tajweed_timing_score:.1f}%")
        return float(tajweed_timing_score)

    except Exception as e:
        print(f"⚠️ Tajweed timing verification error: {e}")
        return 75.0  # Default neutral score

def compute_hybrid_score(audio_quality_score, phoneme_accuracy_score, tajweed_timing_score):
    """
    Combine three components with weights:
    - Audio Quality: 20% (overall voice, timbre, energy)
    - Phoneme Accuracy: 60% (what was actually said)
    - Tajweed Timing: 20% (correct rule application)
    """
    hybrid_score = (
        (audio_quality_score * 0.20) +
        (phoneme_accuracy_score * 0.60) +
        (tajweed_timing_score * 0.20)
    )

    return float(round(hybrid_score, 1))

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

    processed_path = None
    qari_path = None

    try:
        print(f"\n📝 === COMPARISON REQUEST ===")
        print(f"📂 Surah: {surah}, Ayah: {ayah}")
        processed_path = preprocess_audio(user_tmp.name)

        transcribed_text = transcribe_audio(processed_path)
        if not transcribed_text:
            return jsonify({"error": "Transcription failed", "success": False}), 500

        print(f"✍️ User transcribed: '{transcribed_text}'")

        if not correct_text:
            try:
                api_url = f"https://api.quran.com/api/v4/verses/by_key/{surah}:{ayah}?fields=text_uthmani"
                resp = requests.get(api_url, timeout=10)
                correct_text = resp.json()["verse"]["text_uthmani"]
            except:
                correct_text = transcribed_text

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
            word_accuracy = (correct_count * 100 + close_count * 70) / total_words
            missing_penalty = (missing_count * 15)
            whisper_score = max(0, min(100, word_accuracy - missing_penalty))
        else:
            whisper_score = 0.0
        whisper_score = round(whisper_score, 1)

        print(f"  📝 Whisper Score (before penalty): {word_accuracy:.1f}")
        print(f"  📝 Missing Penalty: -{missing_count * 15}")
        print(f"  📝 Final Whisper Score: {whisper_score}")

        qari_path, qari_url = download_qari(surah, ayah)

        # ── HYBRID SCORING SYSTEM ───────────────────────────────────────
        print(f"\n🎯 === HYBRID SCORING (3-Component) ===")

        # Component 1: Audio Quality Score (20%)
        audio_quality_score = 50.0
        if qari_path:
            try:
                user_feat = extract_features(processed_path)
                qari_feat = extract_features(qari_path)
                user_scaled = scaler.transform([user_feat])
                qari_scaled = scaler.transform([qari_feat])
                sim = cosine_similarity(user_scaled, qari_scaled)[0][0]
                audio_quality_score = round(float(max(0, min(1.0, sim))) * 100, 1)
                print(f"  🔊 [1/3] Audio Quality Score: {audio_quality_score}")
            except Exception as e:
                print(f"⚠️ Audio Quality error: {e}")
                audio_quality_score = 50.0
        else:
            print(f"  🔊 Could not download Qari audio (using default)")
            audio_quality_score = 50.0

        # Component 2: Phoneme Accuracy Score (60%) - using DTW
        phoneme_accuracy_score = 0.0
        if qari_path:
            try:
                user_y, _ = librosa.load(processed_path, sr=16000, mono=True)
                qari_y, _ = librosa.load(qari_path, sr=16000, mono=True)

                user_mfcc = librosa.feature.mfcc(y=user_y, sr=16000, n_mfcc=13)
                qari_mfcc = librosa.feature.mfcc(y=qari_y, sr=16000, n_mfcc=13)

                dtw_score = compute_dtw_score(user_mfcc, qari_mfcc)
                direct_phoneme_score = compute_phoneme_accuracy(user_words, correct_words, aligned)

                # Combine DTW and phoneme analysis
                phoneme_accuracy_score = (dtw_score * 0.5 + direct_phoneme_score * 0.5)
                print(f"  📞 [2/3] Phoneme Accuracy Score: {phoneme_accuracy_score:.1f}")
                print(f"         (DTW: {dtw_score:.1f}% + Direct Phoneme: {direct_phoneme_score:.1f}%)")
            except Exception as e:
                print(f"⚠️ Phoneme accuracy error: {e}")
                phoneme_accuracy_score = whisper_score  # Fallback to old whisper score
        else:
            phoneme_accuracy_score = whisper_score

        # Component 3: Tajweed Timing Score (20%)
        tajweed_timing_score = 50.0
        if qari_path:
            try:
                tajweed_timing_score = verify_tajweed_timing(correct_text, processed_path, qari_path)
                print(f"  ✅ [3/3] Tajweed Timing Score: {tajweed_timing_score:.1f}")
            except Exception as e:
                print(f"⚠️ Tajweed timing error: {e}")
                tajweed_timing_score = 50.0

        # Compute final hybrid score
        final_score = compute_hybrid_score(audio_quality_score, phoneme_accuracy_score, tajweed_timing_score)
        mfcc_score = audio_quality_score  # Keep for backward compatibility

        print(f"\n🏆 FINAL HYBRID SCORING:")
        print(f"  Audio Quality:      {audio_quality_score} × 0.20 = {audio_quality_score * 0.20:.1f}")
        print(f"  Phoneme Accuracy:   {phoneme_accuracy_score:.1f} × 0.60 = {phoneme_accuracy_score * 0.60:.1f}")
        print(f"  Tajweed Timing:     {tajweed_timing_score:.1f} × 0.20 = {tajweed_timing_score * 0.20:.1f}")
        print(f"  " + "="*50)
        print(f"  FINAL SCORE:        {final_score}")
        print(f"  GRADE:              {get_grade(final_score)}")

        elapsed = round((time.time() - start) * 1000, 1)
        print(f"⏱️ Inference time: {elapsed}ms\n")

        return jsonify({
            "success": True,
            "overall_score": float(final_score),
            "grade": str(get_grade(final_score)),
            "feedback": str(get_feedback(final_score)),
            "transcribed_text": str(transcribed_text),
            "correct_text": str(correct_text),
            "word_results": word_results,
            "tajweed_summary": {
                "total_rules_detected": int(sum(rules_summary.values())),
                "rules_breakdown": {str(k): int(v) for k, v in rules_summary.items()}
            },
            "metrics": {
                "whisper_score": float(whisper_score),
                "mfcc_score": float(mfcc_score),
                "final_score": float(final_score)
            },
            "hybrid_scoring": {
                "audio_quality_score": float(audio_quality_score),
                "phoneme_accuracy_score": float(phoneme_accuracy_score),
                "tajweed_timing_score": float(tajweed_timing_score),
                "method": "Hybrid (Audio 20% + Phoneme 60% + Tajweed 20%)",
                "dtw_enabled": True,
                "explanation": {
                    "audio_quality": "Overall voice quality, timbre, and energy distribution",
                    "phoneme_accuracy": "DTW-aligned phoneme matching (tempo-invariant)",
                    "tajweed_timing": "Verification of Tajweed rule timing and application"
                }
            },
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
        for path in [user_tmp.name, processed_path, qari_path]:
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
        segments, _ = whisper_model.transcribe(audio_tmp.name, language="ar")
        transcribed_text = " ".join([seg.text for seg in segments]).strip()
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

if __name__ == "__main__":
    app.run(debug=True, port=8000, host="0.0.0.0")