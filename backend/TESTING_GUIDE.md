# Hybrid Scoring System - Testing Guide

## Testing Overview

Test the `/api/compare` endpoint to verify the hybrid scoring system works correctly.

---

## 🛠️ Testing Tools

### Option 1: cURL (Command Line)
```bash
# Simple, built-in on Windows PowerShell
curl -X POST http://localhost:8000/api/compare \
  -F "audio=@path/to/audio.wav" \
  -F "surah=1" \
  -F "ayah=1"
```

### Option 2: Postman (GUI)
- Download: https://www.postman.com/downloads/
- User-friendly interface
- Can save test collections
- Easy to see formatted responses

### Option 3: Python (Script)
```python
import requests
response = requests.post(
    "http://localhost:8000/api/compare",
    files={"audio": open("test.wav", "rb")},
    data={"surah": 1, "ayah": 1}
)
print(response.json())
```

### Option 4: Frontend Testing
- Test directly in the Flutter app
- Record audio and submit
- See results in UI

---

## 📋 Test Scenarios

### Test 1: Health Check (Verify Backend is Running)
```bash
curl http://localhost:8000/api/health
```

**Expected Response:**
```json
{
  "status": "ReciteRight backend chal raha hai ✅",
  "model_loaded": true,
  "reference_ayaat": [number],
  "api_version": "2.0"
}
```

---

### Test 2: Basic Comparison (Without Audio)
```bash
curl -X POST http://localhost:8000/api/compare \
  -F "surah=1" \
  -F "ayah=1"
```

**Expected Response:**
```json
{
  "error": "Audio file required",
  "success": false
}
```

---

### Test 3: Full Comparison (With Audio)

#### Command:
```bash
curl -X POST http://localhost:8000/api/compare \
  -F "audio=@C:\path\to\test_audio.wav" \
  -F "surah=1" \
  -F "ayah=1"
```

#### Expected Response (Success):
```json
{
  "success": true,
  "overall_score": 85.5,
  "grade": "Very Good ✓",
  "feedback": "Bohot acha! Thodi aur practice karo 👍",
  "transcribed_text": "الحمد لله رب العالمين",
  "correct_text": "الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ",
  
  "hybrid_scoring": {
    "audio_quality_score": 84.0,
    "phoneme_accuracy_score": 89.0,
    "tajweed_timing_score": 95.0,
    "method": "Hybrid (Audio 20% + Phoneme 60% + Tajweed 20%)",
    "dtw_enabled": true,
    "explanation": {
      "audio_quality": "Overall voice quality, timbre, energy",
      "phoneme_accuracy": "DTW-aligned phoneme matching",
      "tajweed_timing": "Verification of Tajweed rule timing"
    }
  },
  
  "word_results": [
    {
      "word": "الْحَمْدُ",
      "transcribed": "الحمد",
      "status": "correct",
      "color": "green",
      "similarity": 1.0,
      "phonemes": ["aa", "l", "H", "a", "m", "d"],
      "tajweed_rules": [...]
    }
  ],
  
  "metrics": {
    "whisper_score": 88.5,
    "mfcc_score": 84.0,
    "final_score": 85.5
  },
  
  "inference_time_ms": 523.4
}
```

---

## 🎯 Test Cases by Scenario

### Test Case 1: Perfect Recitation
**Scenario:** User recites perfectly with good voice quality

**Setup:**
1. Record yourself reciting Surah Al-Fatiha Ayah 1 clearly
2. Save as: `perfect_recitation.wav`

**Command:**
```bash
curl -X POST http://localhost:8000/api/compare \
  -F "audio=@perfect_recitation.wav" \
  -F "surah=1" \
  -F "ayah=1"
```

**Expected Results:**
- `overall_score`: 85-95% ✅
- `grade`: "Excellent ✨" or "Very Good ✓"
- `audio_quality_score`: 80%+
- `phoneme_accuracy_score`: 90%+
- `tajweed_timing_score`: 90%+
- All words: status "correct" or "close"

**What to Check:**
- ✅ Score is high
- ✅ All components are 80%+
- ✅ Feedback is positive
- ✅ Phoneme matches correct

---

### Test Case 2: Fast Recitation (Tempo Test)
**Scenario:** User recites correctly but 20% faster than Qari

**Setup:**
1. Speed up a perfect recording by 20%
2. Save as: `fast_recitation.wav`

**Command:**
```bash
curl -X POST http://localhost:8000/api/compare \
  -F "audio=@fast_recitation.wav" \
  -F "surah=1" \
  -F "ayah=1"
```

**Expected Results:**
- `overall_score`: Still 80%+ (DTW should handle tempo!) ✅
- `phoneme_accuracy_score`: 85%+ (DTW alignment)
- NOT penalized heavily for speed

**What to Check:**
- ✅ Score doesn't drop below 75%
- ✅ DTW score is high (90%+)
- ✅ Phoneme matching good despite speed
- ✅ Feedback doesn't mention speed issue

**This validates DTW is working!**

---

### Test Case 3: Slow Recitation (Tempo Test)
**Scenario:** User recites correctly but 20% slower than Qari

**Setup:**
1. Slow down a perfect recording by 20%
2. Save as: `slow_recitation.wav`

**Command:**
```bash
curl -X POST http://localhost:8000/api/compare \
  -F "audio=@slow_recitation.wav" \
  -F "surah=1" \
  -F "ayah=1"
```

**Expected Results:**
- `overall_score`: Still 80%+ (DTW should handle tempo!)
- `phoneme_accuracy_score`: 85%+
- NOT penalized for being slow

**What to Check:**
- ✅ Score acceptable despite slow pace
- ✅ DTW handles both fast and slow equally
- ✅ Fair scoring regardless of tempo

---

### Test Case 4: Pronunciation Error
**Scenario:** User mispronounces one phoneme

**Setup:**
1. Record yourself saying "الحمد لقه رب العالمين" (ق instead of ل)
2. Save as: `pronunciation_error.wav`

**Command:**
```bash
curl -X POST http://localhost:8000/api/compare \
  -F "audio=@pronunciation_error.wav" \
  -F "surah=1" \
  -F "ayah=1"
```

**Expected Results:**
- `overall_score`: 75-85% (lower, but not too much)
- One word has `status: "close"` or `status: "missing"`
- Feedback mentions specific error

**What to Check:**
- ✅ Score reflects the error
- ✅ Word showing the error highlighted
- ✅ Phoneme accuracy lower than perfect
- ✅ Feedback specific about what was wrong

---

### Test Case 5: Missing Word
**Scenario:** User skips a word

**Setup:**
1. Record: "الحمد رب العالمين" (skipped "لله")
2. Save as: `missing_word.wav`

**Command:**
```bash
curl -X POST http://localhost:8000/api/compare \
  -F "audio=@missing_word.wav" \
  -F "surah=1" \
  -F "ayah=1"
```

**Expected Results:**
- `overall_score`: 60-75% (significant penalty)
- One word shows `status: "missing"`
- Color: red

**What to Check:**
- ✅ Score appropriately lower
- ✅ Missing word clearly marked
- ✅ Feedback mentions missing content

---

### Test Case 6: Tajweed Rule Not Applied
**Scenario:** User says words correctly but forgets Tajweed rule

**Setup:**
1. Record yourself saying "السلام" without elongating Madd
2. Save as: `tajweed_issue.wav`

**Command:**
```bash
curl -X POST http://localhost:0000/api/compare \
  -F "audio=@tajweed_issue.wav" \
  -F "surah=36" \
  -F "ayah=58"
```

**Expected Results:**
- `overall_score`: 75-85% (phoneme correct, but timing off)
- `phoneme_accuracy_score`: 85%+ (phonemes present)
- `tajweed_timing_score`: 60-70% (timing incorrect) ⚠️
- Feedback mentions specific Tajweed rule

**What to Check:**
- ✅ Tajweed component score is lower
- ✅ Phoneme accuracy still good
- ✅ Feedback specific about which rule
- ✅ System catches Tajweed issues

---

## 🧪 Python Testing Script

Create a file: `test_scoring.py`

```python
import requests
import json
import os
from pathlib import Path

# Configuration
API_URL = "http://localhost:8000/api/compare"
TEST_AUDIO_DIR = "test_audio"

def test_health():
    """Test if backend is running"""
    print("=" * 60)
    print("TEST 1: Health Check")
    print("=" * 60)
    
    response = requests.get("http://localhost:8000/api/health")
    print(f"Status: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    
    assert response.status_code == 200
    assert response.json()["status"]
    print("✅ PASSED\n")

def test_no_audio():
    """Test error handling when no audio provided"""
    print("=" * 60)
    print("TEST 2: Missing Audio")
    print("=" * 60)
    
    response = requests.post(
        API_URL,
        data={"surah": 1, "ayah": 1}
    )
    print(f"Status: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    
    assert response.status_code == 400
    assert not response.json()["success"]
    print("✅ PASSED\n")

def test_comparison(audio_file, surah, ayah, test_name):
    """Test full comparison"""
    print("=" * 60)
    print(f"TEST: {test_name}")
    print("=" * 60)
    
    if not os.path.exists(audio_file):
        print(f"❌ SKIPPED - Audio file not found: {audio_file}\n")
        return
    
    with open(audio_file, "rb") as f:
        files = {"audio": f}
        data = {"surah": surah, "ayah": ayah}
        response = requests.post(API_URL, files=files, data=data)
    
    print(f"Status: {response.status_code}")
    result = response.json()
    
    # Print summary
    if result.get("success"):
        print(f"✅ Success")
        print(f"  Overall Score: {result.get('overall_score')}%")
        print(f"  Grade: {result.get('grade')}")
        print(f"  Feedback: {result.get('feedback')}")
        
        # Print hybrid scoring breakdown
        hybrid = result.get("hybrid_scoring", {})
        if hybrid:
            print(f"\n  Hybrid Scoring Breakdown:")
            print(f"    Audio Quality:     {hybrid.get('audio_quality_score')}%")
            print(f"    Phoneme Accuracy:  {hybrid.get('phoneme_accuracy_score')}%")
            print(f"    Tajweed Timing:    {hybrid.get('tajweed_timing_score')}%")
        
        print(f"\n  Transcribed: {result.get('transcribed_text')}")
        print(f"  Correct:    {result.get('correct_text')}")
        print(f"  Inference Time: {result.get('inference_time_ms')}ms")
        
        # Print word results
        words = result.get("word_results", [])
        if words:
            print(f"\n  Word Results:")
            for word in words[:5]:  # First 5 words
                status = word.get("status")
                print(f"    '{word.get('word')}' → status: {status}")
        
        print("\n✅ PASSED")
    else:
        print(f"❌ Failed: {result.get('error')}")
        print("❌ FAILED")
    
    print()

def run_all_tests():
    """Run all tests"""
    print("\n")
    print("╔" + "═" * 58 + "╗")
    print("║" + " HYBRID SCORING SYSTEM - TEST SUITE ".center(58) + "║")
    print("╚" + "═" * 58 + "╝")
    print("\n")
    
    # Basic tests
    test_health()
    test_no_audio()
    
    # Scenario tests (if audio files exist)
    test_comparison(
        f"{TEST_AUDIO_DIR}/perfect.wav",
        1, 1,
        "Perfect Recitation"
    )
    test_comparison(
        f"{TEST_AUDIO_DIR}/fast.wav",
        1, 1,
        "Fast Recitation (20% faster)"
    )
    test_comparison(
        f"{TEST_AUDIO_DIR}/error.wav",
        1, 1,
        "Pronunciation Error"
    )
    
    print("\n" + "=" * 60)
    print("TEST SUITE COMPLETE")
    print("=" * 60 + "\n")

if __name__ == "__main__":
    # Make sure backend is running
    try:
        requests.get("http://localhost:8000/api/health", timeout=5)
    except:
        print("❌ ERROR: Backend not running!")
        print("   Start backend with: python app.py")
        exit(1)
    
    run_all_tests()
```

**Run the tests:**
```bash
python test_scoring.py
```

---

## 📊 cURL Testing Examples

### Quick Test Script
Create: `test_api.ps1`

```powershell
# Start backend if not running
$backend_process = Get-Process python -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*app.py*" }
if (-not $backend_process) {
    Write-Host "Starting backend..." -ForegroundColor Green
    Start-Process python -ArgumentList "app.py" -NoNewWindow
    Start-Sleep -Seconds 3
}

# Test 1: Health
Write-Host "Test 1: Health Check" -ForegroundColor Blue
curl http://localhost:8000/api/health
Write-Host ""

# Test 2: Missing Audio
Write-Host "Test 2: Missing Audio (should fail)" -ForegroundColor Blue
curl -X POST http://localhost:8000/api/compare `
  -F "surah=1" `
  -F "ayah=1"
Write-Host ""

# Test 3: With Audio (if file exists)
Write-Host "Test 3: With Audio" -ForegroundColor Blue
if (Test-Path "test_audio.wav") {
    curl -X POST http://localhost:8000/api/compare `
      -F "audio=@test_audio.wav" `
      -F "surah=1" `
      -F "ayah=1"
} else {
    Write-Host "No test audio file found. Create test_audio.wav to test."
}
```

**Run:**
```powershell
.\test_api.ps1
```

---

## 🎤 Creating Test Audio Files

### Option 1: Use Your Phone
1. Open ReciteRight app
2. Record yourself reciting
3. Download the audio file
4. Use for testing

### Option 2: Use Audacity (Free)
1. Download: https://www.audacityteam.org/
2. Open reference Qari audio
3. Record yourself over it
4. Export as WAV
5. Use for testing

### Option 3: Use Python to Create Test Audio
```python
from pydub import AudioSegment
import os

# Load original audio
original = AudioSegment.from_wav("qari_original.wav")

# Create variations
perfect = original  # Use as-is
fast = original.speedup(speed=1.2)  # 20% faster
slow = original.speedup(speed=0.8)  # 20% slower

# Export
perfect.export("test_audio/perfect.wav", format="wav")
fast.export("test_audio/fast.wav", format="wav")
slow.export("test_audio/slow.wav", format="wav")

print("✅ Test audio files created!")
```

---

## 📈 What to Check in Results

### Score Validation
```
✅ Score Range: 0-100 (not more, not less)
✅ Components Sum: Check weights add to 100%
✅ Components reasonable: 0-100 range
✅ Final score makes sense given components
```

### Component Scores
```
✅ Audio Quality: 70-95% (normal voices)
✅ Phoneme Accuracy: 50-100% (varies by pronunciation)
✅ Tajweed Timing: 60-100% (varies by rule application)
✅ All three present in response
```

### Feedback
```
✅ Grade matches score (85%+ = Excellent, etc.)
✅ Feedback is encouraging and specific
✅ Mentions specific issues if present
✅ Actionable (tells what to improve)
```

### Word Results
```
✅ Each word has status (correct, close, missing, extra)
✅ Colors match status (green=correct, red=wrong)
✅ Similarity scores reasonable (0-1 range)
✅ Phonemes extracted for each word
✅ Tajweed rules shown for words
```

### Response Structure
```
✅ "success": true/false
✅ "hybrid_scoring" field present
✅ DTW enabled
✅ Inference time reasonable (~600ms)
✅ All expected fields present
```

---

## 🐛 Troubleshooting

### Backend not responding
```
❌ Problem: Connection refused
✅ Solution: Start backend first
  python F:\ReciteRight\backend\app.py
```

### Audio file error
```
❌ Problem: "Audio file not found"
✅ Solution: Check file path and format
  - Use absolute paths
  - WAV format preferred
  - File must exist
```

### Whisper transcription fails
```
❌ Problem: "Transcription failed"
✅ Solution: Check audio quality
  - Reduce background noise
  - Ensure Arabic recitation
  - Audio not too compressed
```

### DTW score anomaly
```
❌ Problem: DTW score very low
✅ Solution: 
  - Check if audio files match
  - Verify Qari audio downloaded
  - Check audio format compatibility
```

### Tajweed timing always 50%
```
❌ Problem: Tajweed component not working
✅ Solution:
  - Verify Qari audio downloaded
  - Check file paths
  - Monitor logs for errors
```

---

## ✅ Validation Checklist

When testing, verify:

- [ ] Backend starts without errors
- [ ] Health endpoint returns 200
- [ ] Error cases handled (missing audio returns 400)
- [ ] Audio comparison returns success
- [ ] Score in valid range (0-100)
- [ ] Grade matches score range
- [ ] All 3 components present
- [ ] Component scores reasonable
- [ ] Word results populated
- [ ] Tajweed rules detected
- [ ] Inference time ~600ms
- [ ] Response JSON valid
- [ ] Feedback specific and helpful
- [ ] DTW enabled flag true
- [ ] No errors in logs

---

## 📋 Test Report Template

After testing, document results:

```
TEST REPORT - Hybrid Scoring System
====================================

Date: 
Backend Version: 2.0
Test Audio:

TEST 1: Health Check
Status: PASS / FAIL
Notes:

TEST 2: Error Handling
Status: PASS / FAIL
Notes:

TEST 3: Perfect Recitation
Score: ____%
Grade: 
Components: Audio _%, Phoneme _%, Tajweed _%
Status: PASS / FAIL
Notes:

TEST 4: Fast Recitation
Score: ____%
DTW Working: YES / NO
Status: PASS / FAIL
Notes:

TEST 5: Pronunciation Error
Score: ____%
Error Detected: YES / NO
Status: PASS / FAIL
Notes:

TEST 6: Tajweed Issue
Tajweed Score: ____%
Feedback Specific: YES / NO
Status: PASS / FAIL
Notes:

OVERALL: PASS / FAIL
Issues Found:
Recommendations:
```

---

## 🚀 Ready to Test!

You now have:
- ✅ 6 test scenarios
- ✅ Python test script
- ✅ cURL command examples
- ✅ PowerShell script template
- ✅ Audio creation guide
- ✅ Validation checklist
- ✅ Troubleshooting guide

**Start testing!** 🧪

