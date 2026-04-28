#!/bin/bash
# ReciteRight - RUN COMMANDS

# ============================================
# TERMINAL 1: START BACKEND
# ============================================
# Copy and paste this entire block into PowerShell or Command Prompt

cd F:\ReciteRight\backend
python app.py

# Expected output (wait for this):
# 🔄 Model load ho raha hai...
# ✅ Model ready! 80 reference ayaat loaded.
# 🔄 Loading OpenAI Whisper model (large-v3-turbo) on cpu/cuda...
# ✅ OpenAI Whisper model loaded!
# * Running on http://0.0.0.0:8000
# * Running on http://127.0.0.1:8000
# Press CTRL+C to quit

# ============================================
# TERMINAL 2: BUILD & RUN FLUTTER (NEW TERMINAL)
# ============================================
# ONLY after backend is running, open a NEW terminal and run:

cd F:\ReciteRight\frontend\Frontend

# Get dependencies
flutter pub get

# For connected Android device:
flutter run

# OR for specific device:
flutter run -d 08908252CG004901

# ============================================
# ON PHONE - USER WORKFLOW
# ============================================

# 1. App launches → Sign in page
#    Option A: Email/Password login
#    Option B: Google Sign-In
#
# 2. Home screen loads
#    - Select Surah dropdown (default: 1. Al-Fatiha)
#    - Select Ayah dropdown (default: 1)
#    - Arabic text displays automatically
#
# 3. Select a Qari
#    - Choose from 5 famous Qaris
#    - Click "Listen to Qari - [Name]"
#    - Audio plays automatically
#
# 4. Record recitation
#    - Click "Start Recording" button
#    - Phone prompts for microphone permission
#    - Tap "Allow" if not already allowed
#    - Recite the same Ayah clearly
#    - Click "Stop Recording"
#    - Status shows "✅ Recording complete"
#
# 5. Compare with Qari
#    - Click "Compare with Qari" button
#    - App sends recording to backend
#    - Backend analyzes (~15-60 seconds)
#    - Results page shows:
#      * Overall score (0-100)
#      * Grade (Excellent/Very Good/Good/etc)
#      * Word-by-word results
#      * Tajweed rules for each word
#      * Detailed feedback
#
# 6. Review results
#    - Tap on each word to see:
#      * Correct/incorrect status
#      * Tajweed rules applied
#      * Pronunciation tips
#    - Scroll to see all words
#    - Tap on tajweed badge to see rule explanation
#
# 7. Try again
#    - Go back to record another attempt
#    - Compare again to see improvement

# ============================================
# QUICK TROUBLESHOOTING
# ============================================

# Problem: Backend won't start
# Solution:
netstat -ano | findstr :8000
taskkill /PID <PID> /F
cd F:\ReciteRight\backend && python app.py

# Problem: Flutter won't compile
# Solution:
cd F:\ReciteRight\frontend\Frontend
flutter clean
flutter pub get
flutter run

# Problem: App can't connect to backend
# Solution:
# 1. Find your PC IP:
ipconfig
# Look for IPv4 Address (e.g., 192.168.1.100)

# 2. Edit the app code:
# Open: F:\ReciteRight\frontend\Frontend\lib\screens\EnhancedReciteScreen.dart
# Find line: 'http://192.168.100.7:8000/api/compare'
# Replace with: 'http://YOUR_IP:8000/api/compare'
# (Use YOUR actual IP from ipconfig)

# 3. Rebuild:
flutter clean
flutter run

# Problem: No microphone permission
# Solution:
# On phone: Settings → Apps → Permissions → Microphone → ReciteRight → Allow

# ============================================
# FILES TO KNOW
# ============================================

# Backend:
#   F:\ReciteRight\backend\app.py (787 lines)
#   Dependencies: Flask, librosa, openai-whisper, scikit-learn
#
# Frontend:
#   F:\ReciteRight\frontend\Frontend\lib\main.dart (entry point)
#   F:\ReciteRight\frontend\Frontend\lib\screens\EnhancedReciteScreen.dart (main screen)
#   F:\ReciteRight\frontend\Frontend\lib\services\auth_service.dart (auth)
#   F:\ReciteRight\frontend\Frontend\pubspec.yaml (dependencies)

# ============================================
# API ENDPOINTS (BACKEND)
# ============================================

# Health Check:
# GET http://localhost:8000/api/health
# Response: {"status": "...", "model_loaded": true, ...}

# Comparison (MAIN):
# POST http://localhost:8000/api/compare
# Form data:
#   - audio: WAV file (multipart)
#   - surah: "1"
#   - ayah: "1"
#   - correct_text: "Arabic text with harakat"
# Response: Detailed analysis with tajweed rules, scores, feedback

# Transcription only:
# POST http://localhost:8000/api/transcribe
# Form data:
#   - audio: WAV file (multipart)
#   - correct_text: "Arabic text"
# Response: {"transcribed_text": "...", "similarity_score": 85.5, ...}

# Get Qaris:
# GET http://localhost:8000/qaris
# Response: List of 5 Qaris with IDs and names

# Get Qari URL:
# GET http://localhost:8000/api/qari-url?surah=1&ayah=1
# Response: {"url": "https://verses.quran.com/..."}

# ============================================
# FEATURES & FIXES
# ============================================

# ✅ FIXED: Record package initialization
#    Changed: Record → AudioRecorder
#    Now works with v6.2.0 API

# ✅ FIXED: Google Sign-In compatibility
#    Changed: google_sign_in v7.2.0 → v6.3.0
#    Fixed all API method calls

# ✅ FIXED: Firebase authentication
#    Removed: fetchSignInMethodsForEmail() (deprecated)
#    Fixed: isSignedIn() check

# ✅ WORKING: Audio preprocessing
#    - Denoise (reduce background noise)
#    - Normalize (adjust volume)
#    - Trim silence (remove quiet parts)

# ✅ WORKING: Tajweed detection
#    Detects 11 rules: Madd, Ghunnah, Qalqalah, Ikhfa, Idgham,
#    Iqlab, Izhar, Shadda, Tafkhim, Meem Sakinah, Sukoon

# ✅ WORKING: Scoring system
#    - Whisper Score: Transcription accuracy
#    - MFCC Score: Voice similarity
#    - Final Score: Weighted average
#    - Grade: Based on score

# ============================================
# EXPECTED TIMINGS
# ============================================

# Backend startup: ~10 seconds
# Flutter build: ~2 minutes (first time), ~30s (subsequent)
# App launch: ~5 seconds
# Audio recording: User-controlled
# Backend comparison: ~15-60 seconds (depends on audio length)
# Results display: ~1 second

# ============================================
# REQUIREMENTS
# ============================================

# Hardware:
# - PC/Laptop with 8GB+ RAM
# - Android phone with Android 8.0+
# - USB cable for phone connection

# Software:
# - Python 3.8+
# - Flutter 3.x
# - Java 11 or higher (for Android build)
# - Android SDK

# Network:
# - Phone and PC on same WiFi network
# - Ports: 8000 (backend) available

# ============================================
# DEPLOYMENT CHECKLIST
# ============================================

# [ ] Backend starts without errors
# [ ] All 80 reference ayaat loaded
# [ ] OpenAI Whisper (large-v3-turbo) model loads from C:\Users\hp\.cache\whisper\large-v3-turbo.pt
# [ ] Flutter dependencies resolve
# [ ] App builds without compilation errors
# [ ] Phone connects via USB
# [ ] App installs on phone
# [ ] Can log in (email or Google)
# [ ] Can select Surah & Ayah
# [ ] Arabic text displays
# [ ] Can play Qari audio
# [ ] Can record audio
# [ ] Microphone permission works
# [ ] Can send audio to backend
# [ ] Backend processes recording
# [ ] Results display correctly
# [ ] Tajweed rules show up
# [ ] Score and feedback display
# [ ] Can tap on words for details

# ============================================
# SUCCESS INDICATORS
# ============================================

# ✅ Backend running: See "Running on http://0.0.0.0:8000"
# ✅ Flutter built: No compilation errors
# ✅ App installed: App icon appears on phone
# ✅ Login works: Can authenticate
# ✅ Data loads: Arabic text visible
# ✅ Recording works: Can record audio
# ✅ Processing works: Backend responds
# ✅ Results show: Tajweed analysis visible
# ✅ Grading works: Score and feedback display

# ============================================
# DATE: April 9, 2026
# STATUS: READY FOR DEPLOYMENT ✅
# ============================================

