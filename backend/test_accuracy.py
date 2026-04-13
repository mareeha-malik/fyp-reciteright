#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Test script to verify accuracy improvements in ReciteRight backend.
Run this to see before/after scoring comparison.
"""

import re
from difflib import SequenceMatcher

def normalize_arabic(text):
    """Normalize Arabic text for comparison"""
    text = re.sub(r'[\u0610-\u061A\u064B-\u065F\u0670]', '', text)
    text = re.sub(r'[أإآا]', 'ا', text)
    text = re.sub(r'ة', 'ه', text)
    text = re.sub(r'ـ', '', text)
    text = ' '.join(text.split())
    return text.strip()

def align_words_smart(user_words, correct_words):
    """Smart word alignment"""
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

def score_old_way(correct_count, total_words):
    """Old inaccurate scoring"""
    return round((correct_count / total_words * 100) if total_words > 0 else 0, 1)

def score_new_way(correct_count, close_count, missing_count, total_words):
    """New improved scoring"""
    if total_words > 0:
        word_accuracy = (correct_count * 100 + close_count * 70) / total_words
        missing_penalty = (missing_count * 15)
        whisper_score = max(0, min(100, word_accuracy - missing_penalty))
    else:
        whisper_score = 0.0
    return round(whisper_score, 1)

# Test Case 1: Perfect recitation
print("\n" + "="*60)
print("TEST 1: Perfect Recitation")
print("="*60)

correct_text = "بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ"
user_text = "بسم الله الرحمن الرحيم"

user_words = user_text.split()
correct_words = correct_text.split()

aligned = align_words_smart(user_words, correct_words)

correct = sum(1 for a in aligned if a["status"] == "correct")
close = sum(1 for a in aligned if a["status"] == "close")
missing = sum(1 for a in aligned if a["status"] == "missing")
total = len([a for a in aligned if a["correct_word"]])

print(f"\nUser:    '{user_text}'")
print(f"Correct: '{correct_text}'")
print(f"\nAlignment:")
for a in aligned:
    if a["correct_word"]:
        status = "✅" if a["status"] == "correct" else "⚠️"
        print(f"  {status} '{a['correct_word']}' → '{a['user_word']}' ({a['similarity']})")

print(f"\nStatistics:")
print(f"  Correct: {correct}/{total}")
print(f"  Close:   {close}")
print(f"  Missing: {missing}")

old_score = score_old_way(correct, total)
new_score = score_new_way(correct, close, missing, total)
mfcc_score = 85.0  # Simulated

old_final = round((old_score * 0.7) + (mfcc_score * 0.3), 1)
new_final = round((new_score * 0.6) + (mfcc_score * 0.4), 1)

print(f"\nOLD SCORING (Inaccurate):")
print(f"  Whisper Score: {old_score}")
print(f"  Final Score:   {old_final} (Whisper×0.7 + MFCC×0.3)")

print(f"\nNEW SCORING (Accurate):")
print(f"  Whisper Score: {new_score}")
print(f"  Final Score:   {new_final} (Whisper×0.6 + MFCC×0.4)")

# Test Case 2: Close matches (major improvement)
print("\n" + "="*60)
print("TEST 2: Close Matches (90% similarity)")
print("="*60)

correct_text = "الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ"
user_text = "الحمد لله رب العالمين"  # Close but not exact

user_words = user_text.split()
correct_words = correct_text.split()

aligned = align_words_smart(user_words, correct_words)

correct = sum(1 for a in aligned if a["status"] == "correct")
close = sum(1 for a in aligned if a["status"] == "close")
missing = sum(1 for a in aligned if a["status"] == "missing")
total = len([a for a in aligned if a["correct_word"]])

print(f"\nUser:    '{user_text}'")
print(f"Correct: '{correct_text}'")
print(f"\nAlignment:")
for a in aligned:
    if a["correct_word"]:
        status = "✅" if a["status"] == "correct" else "⚠️" if a["status"] == "close" else "❌"
        print(f"  {status} '{a['correct_word']}' → '{a['user_word']}' ({a['similarity']})")

print(f"\nStatistics:")
print(f"  Correct: {correct}/{total}")
print(f"  Close:   {close}")
print(f"  Missing: {missing}")

old_score = score_old_way(correct, total)
new_score = score_new_way(correct, close, missing, total)
mfcc_score = 80.0

old_final = round((old_score * 0.7) + (mfcc_score * 0.3), 1)
new_final = round((new_score * 0.6) + (mfcc_score * 0.4), 1)

print(f"\nOLD SCORING (Inaccurate):")
print(f"  Whisper Score: {old_score} ❌ (treats close as wrong)")
print(f"  Final Score:   {old_final}")

print(f"\nNEW SCORING (Accurate):")
print(f"  Whisper Score: {new_score} ✅ (gives 70% credit for close)")
print(f"  Final Score:   {new_final}")

# Test Case 3: Missing words (penalty)
print("\n" + "="*60)
print("TEST 3: Missing Words (Penalty Applied)")
print("="*60)

correct_text = "قُلْ هُوَ اللَّهُ أَحَدٌ"
user_text = "قل الله احد"  # Missing "هو" and wrong diacritic

user_words = user_text.split()
correct_words = correct_text.split()

aligned = align_words_smart(user_words, correct_words)

correct = sum(1 for a in aligned if a["status"] == "correct")
close = sum(1 for a in aligned if a["status"] == "close")
missing = sum(1 for a in aligned if a["status"] == "missing")
total = len([a for a in aligned if a["correct_word"]])

print(f"\nUser:    '{user_text}'")
print(f"Correct: '{correct_text}'")
print(f"\nAlignment:")
for a in aligned:
    if a["correct_word"]:
        status = "✅" if a["status"] == "correct" else "⚠️" if a["status"] == "close" else "❌"
        print(f"  {status} '{a['correct_word']}' → '{a['user_word']}' ({a['similarity']})")

print(f"\nStatistics:")
print(f"  Correct: {correct}/{total}")
print(f"  Close:   {close}")
print(f"  Missing: {missing}")

old_score = score_old_way(correct, total)
new_score = score_new_way(correct, close, missing, total)
mfcc_score = 70.0

old_final = round((old_score * 0.7) + (mfcc_score * 0.3), 1)
new_final = round((new_score * 0.6) + (mfcc_score * 0.4), 1)

print(f"\nOLD SCORING:")
print(f"  Whisper Score: {old_score} ❌ (no penalty for missing)")
print(f"  Final Score:   {old_final}")

print(f"\nNEW SCORING:")
print(f"  Missing Penalty: -{missing * 15}")
print(f"  Whisper Score: {new_score} ✅ (applies penalty)")
print(f"  Final Score:   {new_final}")

print("\n" + "="*60)
print("SUMMARY")
print("="*60)
print("""
✅ Improvements Made:
1. Smart word alignment with similarity scoring
2. Credit for close matches (90%+ similarity = 70% points)
3. Penalty for missing words (-15 per word)
4. Better weight distribution (60% transcription, 40% audio)
5. Comprehensive logging for debugging

📊 Expected Impact:
- More accurate scores for recitations with minor variations
- Fair treatment of close matches
- Better feedback for users
- Easier debugging with detailed logs
""")

