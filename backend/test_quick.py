#!/usr/bin/env python3
"""
Quick Testing Script for Hybrid Scoring System
Run this to test the /api/compare endpoint
"""

import requests
import json
import sys
import time
from pathlib import Path

# Configuration
BASE_URL = "http://localhost:8000"
HEALTH_URL = f"{BASE_URL}/api/health"
COMPARE_URL = f"{BASE_URL}/api/compare"

# Colors
GREEN = "\033[92m"
RED = "\033[91m"
BLUE = "\033[94m"
YELLOW = "\033[93m"
RESET = "\033[0m"

def print_header(text):
    """Print section header"""
    print(f"\n{BLUE}{'='*60}{RESET}")
    print(f"{BLUE}{text.center(60)}{RESET}")
    print(f"{BLUE}{'='*60}{RESET}\n")

def print_test(name):
    """Print test name"""
    print(f"{YELLOW}► {name}{RESET}")

def print_pass(msg):
    """Print pass message"""
    print(f"{GREEN}✅ {msg}{RESET}")

def print_fail(msg):
    """Print fail message"""
    print(f"{RED}❌ {msg}{RESET}")

def print_info(msg):
    """Print info message"""
    print(f"  ℹ️ {msg}")

def test_1_health():
    """Test 1: Health Check"""
    print_test("Test 1: Health Check")

    try:
        response = requests.get(HEALTH_URL, timeout=5)

        if response.status_code == 200:
            data = response.json()
            print_pass(f"Backend is running!")
            print_info(f"Status: {data.get('status')}")
            print_info(f"API Version: {data.get('api_version')}")
            print_info(f"Reference Ayaat: {data.get('reference_ayaat')}")
            return True
        else:
            print_fail(f"Unexpected status code: {response.status_code}")
            return False
    except requests.exceptions.ConnectionError:
        print_fail("Cannot connect to backend!")
        print_info("Make sure to start backend: python app.py")
        return False
    except Exception as e:
        print_fail(f"Error: {str(e)}")
        return False

def test_2_missing_audio():
    """Test 2: Missing Audio Error Handling"""
    print_test("Test 2: Missing Audio (Should Return Error)")

    try:
        response = requests.post(
            COMPARE_URL,
            data={"surah": 1, "ayah": 1},
            timeout=10
        )

        if response.status_code == 400:
            data = response.json()
            if not data.get("success") and "error" in data:
                print_pass("Correctly rejected missing audio")
                print_info(f"Error message: {data.get('error')}")
                return True
            else:
                print_fail("Error response format incorrect")
                return False
        else:
            print_fail(f"Expected 400, got {response.status_code}")
            return False
    except Exception as e:
        print_fail(f"Error: {str(e)}")
        return False

def test_3_with_audio(audio_path, surah, ayah, test_name):
    """Test 3: Full Comparison with Audio"""
    print_test(f"Test 3: {test_name}")

    if not Path(audio_path).exists():
        print_fail(f"Audio file not found: {audio_path}")
        print_info("To test with audio, provide a WAV file")
        return None

    try:
        print_info("Sending audio file for comparison...")
        start_time = time.time()

        with open(audio_path, "rb") as f:
            files = {"audio": f}
            data = {"surah": str(surah), "ayah": str(ayah)}
            response = requests.post(COMPARE_URL, files=files, data=data, timeout=30)

        elapsed = time.time() - start_time

        if response.status_code == 200:
            result = response.json()

            if result.get("success"):
                print_pass(f"Comparison successful! ({elapsed:.1f}s)")

                # Print scores
                score = result.get("overall_score", 0)
                grade = result.get("grade", "Unknown")
                print_info(f"Overall Score: {score}% ({grade})")

                # Print hybrid scoring
                hybrid = result.get("hybrid_scoring", {})
                if hybrid:
                    print_info(f"Audio Quality:     {hybrid.get('audio_quality_score')}%")
                    print_info(f"Phoneme Accuracy:  {hybrid.get('phoneme_accuracy_score')}%")
                    print_info(f"Tajweed Timing:    {hybrid.get('tajweed_timing_score')}%")

                    if hybrid.get("dtw_enabled"):
                        print_pass("DTW (Dynamic Time Warping) enabled ✓")

                # Print transcription
                transcribed = result.get("transcribed_text", "")
                correct = result.get("correct_text", "")
                print_info(f"Transcribed: {transcribed}")
                print_info(f"Correct:     {correct}")

                # Print word results
                words = result.get("word_results", [])
                if words:
                    print_info(f"Word Accuracy: {sum(1 for w in words if w.get('status') == 'correct')}/{len(words)} correct")

                # Print feedback
                feedback = result.get("feedback", "")
                if feedback:
                    print_info(f"Feedback: {feedback}")

                print_info(f"Inference time: {result.get('inference_time_ms', 0)}ms")

                return True
            else:
                error = result.get("error", "Unknown error")
                print_fail(f"Comparison failed: {error}")
                return False
        else:
            print_fail(f"Server error: {response.status_code}")
            print_info(response.text[:200])
            return False

    except requests.exceptions.Timeout:
        print_fail("Request timeout - backend may be slow or stuck")
        return False
    except Exception as e:
        print_fail(f"Error: {str(e)}")
        return False

def main():
    """Run all tests"""
    print_header("HYBRID SCORING SYSTEM - QUICK TEST")

    results = {}

    # Test 1: Health
    results["Health Check"] = test_1_health()

    if not results["Health Check"]:
        print("\n" + RED + "❌ Backend not running! Cannot continue." + RESET)
        print(f"{YELLOW}Start backend with: python app.py{RESET}\n")
        return False

    # Test 2: Error handling
    results["Error Handling"] = test_2_missing_audio()

    # Test 3: Full comparison (optional - only if audio file provided)
    audio_file = "test_audio.wav" if len(sys.argv) < 2 else sys.argv[1]
    if Path(audio_file).exists():
        results["Comparison"] = test_3_with_audio(audio_file, 1, 1, "Full Comparison")
    else:
        print_test("Test 3: Full Comparison with Audio")
        print_info("No audio file provided. Skipping this test.")
        print_info(f"Usage: python test_quick.py <audio_file.wav>")
        results["Comparison"] = None

    # Print summary
    print_header("TEST SUMMARY")

    passed = sum(1 for v in results.values() if v is True)
    failed = sum(1 for v in results.values() if v is False)
    skipped = sum(1 for v in results.values() if v is None)

    for test_name, result in results.items():
        if result is True:
            print(f"{GREEN}✅ PASS{RESET} - {test_name}")
        elif result is False:
            print(f"{RED}❌ FAIL{RESET} - {test_name}")
        else:
            print(f"{YELLOW}⊘ SKIP{RESET} - {test_name}")

    print(f"\n{GREEN}Passed: {passed}{RESET} | {RED}Failed: {failed}{RESET} | {YELLOW}Skipped: {skipped}{RESET}")

    if failed == 0 and passed > 0:
        print(f"\n{GREEN}🎉 All tests passed!{RESET}\n")
        return True
    else:
        print(f"\n{RED}⚠️ Some tests failed or skipped{RESET}\n")
        return False

if __name__ == "__main__":
    try:
        success = main()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print(f"\n{YELLOW}Test interrupted by user{RESET}\n")
        sys.exit(1)

