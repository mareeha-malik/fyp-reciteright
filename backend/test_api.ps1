# Hybrid Scoring System - Testing Script (PowerShell)
# Usage: .\test_api.ps1 [optional_audio_file]

# Configuration
$BASE_URL = "http://localhost:8000"
$HEALTH_URL = "$BASE_URL/api/health"
$COMPARE_URL = "$BASE_URL/api/compare"

# Colors
$GREEN = [System.ConsoleColor]::Green
$RED = [System.ConsoleColor]::Red
$BLUE = [System.ConsoleColor]::Cyan
$YELLOW = [System.ConsoleColor]::Yellow

function Print-Header {
    param([string]$text)
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor $BLUE
    Write-Host $text.PadLeft(($text.Length + (60-$text.Length)/2)) -ForegroundColor $BLUE
    Write-Host ("=" * 60) -ForegroundColor $BLUE
    Write-Host ""
}

function Print-Test {
    param([string]$name)
    Write-Host "► $name" -ForegroundColor $YELLOW
}

function Print-Pass {
    param([string]$msg)
    Write-Host "✅ $msg" -ForegroundColor $GREEN
}

function Print-Fail {
    param([string]$msg)
    Write-Host "❌ $msg" -ForegroundColor $RED
}

function Print-Info {
    param([string]$msg)
    Write-Host "   ℹ️ $msg"
}

function Test-Health {
    Print-Test "Test 1: Health Check"

    try {
        $response = Invoke-WebRequest -Uri $HEALTH_URL -Method GET -TimeoutSec 5 -ErrorAction Stop

        if ($response.StatusCode -eq 200) {
            $data = $response.Content | ConvertFrom-Json
            Print-Pass "Backend is running!"
            Print-Info "Status: $($data.status)"
            Print-Info "API Version: $($data.api_version)"
            Print-Info "Reference Ayaat: $($data.reference_ayaat)"
            return $true
        } else {
            Print-Fail "Unexpected status code: $($response.StatusCode)"
            return $false
        }
    } catch {
        Print-Fail "Cannot connect to backend!"
        Print-Info "Make sure to start backend: python app.py"
        Print-Info "Error: $($_.Exception.Message)"
        return $false
    }
}

function Test-MissingAudio {
    Print-Test "Test 2: Missing Audio (Should Return Error)"

    try {
        $body = @{
            surah = "1"
            ayah = "1"
        } | ConvertTo-Json

        $response = Invoke-WebRequest -Uri $COMPARE_URL -Method POST `
            -Body $body -ContentType "application/json" `
            -TimeoutSec 10 -ErrorAction Stop

        Print-Fail "Expected error, but got: $($response.StatusCode)"
        return $false
    } catch {
        if ($_.Exception.Response.StatusCode -eq 400) {
            $errorContent = $_.Exception.Response.Content.ReadAsStream()
            $reader = New-Object System.IO.StreamReader($errorContent)
            $data = $reader.ReadToEnd() | ConvertFrom-Json
            $reader.Close()

            if (-not $data.success -and $data.error) {
                Print-Pass "Correctly rejected missing audio"
                Print-Info "Error message: $($data.error)"
                return $true
            } else {
                Print-Fail "Error response format incorrect"
                return $false
            }
        } else {
            Print-Fail "Unexpected error: $($_.Exception.Message)"
            return $false
        }
    }
}

function Test-WithAudio {
    param(
        [string]$audioPath,
        [string]$surah = "1",
        [string]$ayah = "1",
        [string]$testName = "Full Comparison"
    )

    Print-Test "Test 3: $testName"

    if (-not (Test-Path $audioPath)) {
        Print-Fail "Audio file not found: $audioPath"
        Print-Info "To test with audio, provide a WAV file"
        return $null
    }

    try {
        Print-Info "Sending audio file for comparison..."
        $startTime = Get-Date

        # Create multipart form data
        $boundary = [System.Guid]::NewGuid().ToString()
        $body = New-Object System.IO.MemoryStream

        # Add surah field
        $bodyString = @"
--$boundary
Content-Disposition: form-data; name="surah"

$surah
--$boundary
Content-Disposition: form-data; name="ayah"

$ayah
--$boundary
Content-Disposition: form-data; name="audio"; filename="$(Split-Path $audioPath -Leaf)"
Content-Type: audio/wav

"@
        $encoding = [System.Text.Encoding]::UTF8
        $body.Write($encoding.GetBytes($bodyString), 0, $encoding.GetByteCount($bodyString))

        # Add audio file
        $fileBytes = [System.IO.File]::ReadAllBytes($audioPath)
        $body.Write($fileBytes, 0, $fileBytes.Length)

        # End boundary
        $bodyString = "`r`n--$boundary--`r`n"
        $body.Write($encoding.GetBytes($bodyString), 0, $encoding.GetByteCount($bodyString))

        $body.Position = 0

        $response = Invoke-WebRequest -Uri $COMPARE_URL -Method POST `
            -ContentType "multipart/form-data; boundary=$boundary" `
            -Body $body -TimeoutSec 30

        $elapsed = ((Get-Date) - $startTime).TotalSeconds

        if ($response.StatusCode -eq 200) {
            $result = $response.Content | ConvertFrom-Json

            if ($result.success) {
                Print-Pass "Comparison successful! ($([math]::Round($elapsed, 1))s)"

                # Print scores
                $score = $result.overall_score
                $grade = $result.grade
                Print-Info "Overall Score: $score% ($grade)"

                # Print hybrid scoring
                if ($result.hybrid_scoring) {
                    $hybrid = $result.hybrid_scoring
                    Print-Info "Audio Quality:     $($hybrid.audio_quality_score)%"
                    Print-Info "Phoneme Accuracy:  $($hybrid.phoneme_accuracy_score)%"
                    Print-Info "Tajweed Timing:    $($hybrid.tajweed_timing_score)%"

                    if ($hybrid.dtw_enabled) {
                        Print-Pass "DTW (Dynamic Time Warping) enabled ✓"
                    }
                }

                # Print transcription
                Print-Info "Transcribed: $($result.transcribed_text)"
                Print-Info "Correct:     $($result.correct_text)"

                # Print word accuracy
                if ($result.word_results) {
                    $correctWords = ($result.word_results | Where-Object { $_.status -eq "correct" }).Count
                    $totalWords = $result.word_results.Count
                    Print-Info "Word Accuracy: $correctWords/$totalWords correct"
                }

                # Print feedback
                if ($result.feedback) {
                    Print-Info "Feedback: $($result.feedback)"
                }

                Print-Info "Inference time: $($result.inference_time_ms)ms"

                return $true
            } else {
                Print-Fail "Comparison failed: $($result.error)"
                return $false
            }
        } else {
            Print-Fail "Server error: $($response.StatusCode)"
            Print-Info $response.Content.Substring(0, [Math]::Min(200, $response.Content.Length))
            return $false
        }
    } catch {
        if ($_.Exception.Message -like "*timed out*") {
            Print-Fail "Request timeout - backend may be slow or stuck"
        } else {
            Print-Fail "Error: $($_.Exception.Message)"
        }
        return $false
    }
}

# Main execution
function Main {
    Print-Header "HYBRID SCORING SYSTEM - QUICK TEST"

    $results = @{}

    # Test 1: Health
    Write-Host ""
    $results["Health Check"] = Test-Health

    if (-not $results["Health Check"]) {
        Write-Host ""
        Write-Host "❌ Backend not running! Cannot continue." -ForegroundColor $RED
        Write-Host "Start backend with: python app.py" -ForegroundColor $YELLOW
        Write-Host ""
        return $false
    }

    # Test 2: Error handling
    Write-Host ""
    $results["Error Handling"] = Test-MissingAudio

    # Test 3: Full comparison (optional)
    Write-Host ""
    if ($args.Count -gt 0) {
        $audioFile = $args[0]
    } else {
        $audioFile = "test_audio.wav"
    }

    if (Test-Path $audioFile) {
        $results["Comparison"] = Test-WithAudio -audioPath $audioFile -surah "1" -ayah "1"
    } else {
        Print-Test "Test 3: Full Comparison with Audio"
        Print-Info "No audio file provided. Skipping this test."
        Print-Info "Usage: .\test_api.ps1 <audio_file.wav>"
        $results["Comparison"] = $null
    }

    # Print summary
    Print-Header "TEST SUMMARY"

    $passed = ($results.Values | Where-Object { $_ -eq $true }).Count
    $failed = ($results.Values | Where-Object { $_ -eq $false }).Count
    $skipped = ($results.Values | Where-Object { $_ -eq $null }).Count

    foreach ($testName in $results.Keys) {
        $result = $results[$testName]
        if ($result -eq $true) {
            Write-Host "✅ PASS - $testName" -ForegroundColor $GREEN
        } elseif ($result -eq $false) {
            Write-Host "❌ FAIL - $testName" -ForegroundColor $RED
        } else {
            Write-Host "⊘ SKIP - $testName" -ForegroundColor $YELLOW
        }
    }

    Write-Host ""
    Write-Host "Passed: $passed" -ForegroundColor $GREEN -NoNewline
    Write-Host " | " -NoNewline
    Write-Host "Failed: $failed" -ForegroundColor $RED -NoNewline
    Write-Host " | " -NoNewline
    Write-Host "Skipped: $skipped" -ForegroundColor $YELLOW
    Write-Host ""

    if ($failed -eq 0 -and $passed -gt 0) {
        Write-Host "🎉 All tests passed!" -ForegroundColor $GREEN
        Write-Host ""
        return $true
    } else {
        Write-Host "⚠️ Some tests failed or skipped" -ForegroundColor $RED
        Write-Host ""
        return $false
    }
}

# Run main
$success = Main
exit ($success ? 0 : 1)

