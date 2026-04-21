# ReciteRight FYP Viva Preparation Document

## 1) Project in One Minute (Opening Answer)

**ReciteRight** is a mobile-assisted Quran recitation training system.
It helps a learner:
1. listen to a reference imam/qari recitation,
2. record their own voice,
3. compare both recitations automatically,
4. get word-level and Tajweed-focused feedback,
5. track progress over time (sessions, streaks, memorization status).

The system has:
- **Frontend:** Flutter app (Android-first in current setup)
- **Backend:** Flask + ML/audio processing pipeline
- **Auth/Cloud:** Firebase Authentication (plus Firestore scaffolding)
- **Persistence for progress:** local JSON files on backend (`backend/data/...`)

---

## 2) Problem Statement and Why This Matters

Many learners can read Quran text but struggle with:
- correct pronunciation (Makharij/phoneme quality),
- Tajweed timing (Madd, Ghunnah, etc.),
- consistent self-assessment without a teacher always present.

ReciteRight addresses this by giving **instant, structured, repeatable feedback** using speech transcription + audio similarity + Tajweed rule logic.

---

## 3) High-Level Architecture

## 3.1 Frontend (Flutter)
Main responsibilities:
- User login/auth state handling (`frontend/Frontend/lib/main.dart`)
- Ayah browsing and playback UI (`frontend/Frontend/lib/screens/AyahDisplayScreen.dart`)
- Recording audio using `record` package
- Sending compare requests to backend (`/api/compare`)
- Showing detailed feedback (overall score, word status, Tajweed breakdown)
- Session and memorization dashboard via backend session APIs

## 3.2 Backend (Flask)
Main file: `backend/app.py`
- Loads audio feature scaler and reference features
- Loads Faster-Whisper model
- Exposes APIs for compare, transcribe, health, qari URL, sessions/memorization via route modules
- Implements hybrid scoring pipeline for recitation quality

## 3.3 Data/Auth Layer
- Firebase Auth for user authentication in app
- Backend stores recitation session history and memorization state in JSON files through `backend/database.py`

---

## 4) End-to-End Data Flow (What happens when user presses Compare)

1. User selects Surah/Ayah in `AyahDisplayScreen`.
2. User records voice (`record` plugin).
3. Frontend sends multipart POST to `POST /api/compare` with:
   - audio file,
   - surah,
   - ayah,
   - correct text (if available),
   - qari id.
4. Backend validates speech activity (rejects silence/very weak input).
5. Backend preprocesses audio (denoise/normalize/trim).
6. Backend transcribes Arabic with Faster-Whisper.
7. Backend aligns transcribed words with expected words.
8. Backend computes:
   - audio quality similarity,
   - DTW-based phoneme/temporal similarity,
   - Tajweed timing/rhythm checks.
9. Backend combines scores into final hybrid score and returns JSON.
10. Frontend renders results and optionally stores session/memorization updates.

---

## 5) Important Viva Question: "Are ayahs loaded from an online API?"

**Yes, in the current app flow they are online.**

Evidence:
- `AyahDisplayScreen._fetchAyahs()` fetches from Quran.com API:
  - `https://api.quran.com/api/v4/verses/by_chapter/...`
- `quran_lesson_service.dart` also calls online endpoints for verse/word data.

So core ayah text and related metadata are currently fetched from external APIs (not fully offline bundled Quran database).

---

## 6) Important Viva Question: "Are lessons fetched from an API?"

**Main lesson curriculum is local (hardcoded), but lesson enrichments use online API.**

- Core lesson content (titles, explanations, quiz questions) is in:
  - `frontend/Frontend/lib/models/tajweed_lesson.dart`
  - `final List<TajweedLesson> lessons = [...]`
- In lesson detail pages, some dynamic enrichments are fetched online:
  - Word-by-word data from Quran.com (`quran_lesson_service.dart`)
  - Tajweed text endpoint (alquran.cloud)
  - Audio URL from verses.quran.com

There is also a Firestore `TajweedService` file, but in current flow the displayed lesson list is based on local hardcoded `lessons`.

---

## 7) Important Viva Question: "How do you compare user and imam voice?"

Comparison is done using a **hybrid scoring model** (backend `app.py`).

## 7.1 Input
- User recorded audio (wav)
- Reference qari audio (downloaded for specific surah/ayah)

## 7.2 Steps
1. **Speech gate**: reject silent/noise-only audio.
2. **ASR transcription** with Faster-Whisper (Arabic).
3. **Word alignment** between user words and correct words.
4. **Phoneme extraction + similarity** on aligned words.
5. **DTW on MFCC feature sequences** for tempo-invariant similarity.
6. **Tajweed rule analysis** (Madd, Ghunnah, Qalqalah, Ikhfa, Idgham, Iqlab, Izhar, etc.).
7. **Timing/rhythm verification** using duration and onset envelope similarity.

## 7.3 Final Score Formula
The backend combines components as:
- Audio Quality: **20%**
- Phoneme Accuracy: **60%**
- Tajweed Timing: **20%**

Then applies a confidence multiplier to penalize low-confidence/suspicious recitation input.

---

## 8) Technologies Used

## 8.1 Frontend
- Flutter (Dart)
- Packages used include (from `pubspec.yaml`):
  - `record`, `just_audio`, `audioplayers`
  - `dio`, `http`
  - `provider`
  - `fl_chart`
  - Firebase packages (`firebase_core`, `firebase_auth`, `cloud_firestore`, etc.)

## 8.2 Backend
- Python + Flask
- `librosa`, `numpy`, `scikit-learn`, `joblib`
- `faster-whisper`
- `soundfile`
- `requests`

## 8.3 Data/Auth
- Firebase Authentication
- JSON-file persistence for session/memorization metrics (`backend/data/...`)

---

## 9) Key APIs You Should Memorize for Viva

- `GET /api/health` -> service/model health
- `POST /api/compare` -> main recitation comparison endpoint
- `POST /api/transcribe` -> transcription + similarity
- `POST /api/sessions` -> save recitation session
- `GET /api/user/progress` -> weekly progress
- `GET /api/user/home-metrics` -> streak/minutes
- `GET /api/user/mistakes` -> mistake analytics
- `GET /api/memorization/summary` -> memorization summary
- `POST /api/memorization/update` -> update ayah memorization state

---

## 10) What Is Innovative in This FYP (Defensible Points)

1. **Hybrid scoring** rather than one metric only.
2. **DTW-based temporal robustness** (fast/slow recitation does not immediately fail).
3. **Word-level and Tajweed-level explainability**, not just a single final score.
4. **Practice + memorization tracking** in one app flow.
5. **Actionable UI feedback** for learner improvement cycle.

---

## 11) Likely Viva Questions with Strong Answers

## Q1. Why did you choose DTW?
**Answer:** Reciters naturally vary speed/tempo. DTW aligns two feature sequences even if one is faster/slower, making similarity fairer than plain frame-by-frame matching.

## Q2. Why not rely only on Whisper transcription score?
**Answer:** ASR text alone misses recitation acoustics and timing quality. We combine ASR/phoneme evidence with audio-feature similarity and Tajweed timing to reduce bias from any single component.

## Q3. Is this a full Tajweed scholar replacement?
**Answer:** No. It is an assistive learning tool for frequent practice and feedback, not a replacement for qualified teacher judgment.

## Q4. Are ayahs and audio offline?
**Answer:** Current implementation fetches ayahs/audio online from Quran endpoints. An offline cache/database is planned as future work.

## Q5. How do you handle bad recordings or silence?
**Answer:** Backend has speech activity checks and low-confidence gates; returns 422 with user-friendly error reason instead of fake scoring.

## Q6. What if backend cannot download qari audio?
**Answer:** System has fallback paths and debug flags; some components degrade gracefully rather than crashing.

## Q7. How do you store user progress?
**Answer:** Session and memorization states are persisted by backend in structured JSON files under `backend/data/`.

## Q8. Why Flutter + Flask?
**Answer:** Flutter gives one codebase for mobile UI; Flask is lightweight and flexible for Python audio/ML ecosystem integration.

## Q9. How do you ensure fairness of score?
**Answer:** Multi-component score with weighted factors + confidence gating + explicit word alignment reduces over-reliance on a single noisy signal.

## Q10. What are limitations?
**Answer:** Network dependency for Quran sources, device microphone quality variability, and heuristic Tajweed timing checks that can be improved with larger labeled datasets.

## Q11. Can this scale to many users?
**Answer:** Current JSON persistence is ideal for prototype/small deployment. For scale, migrate to PostgreSQL and async task queue for heavy audio jobs.

## Q12. Privacy concerns?
**Answer:** Audio is sent for processing, so explicit consent, secure transport, retention policy, and optional on-device/offline options are important future improvements.

---

## 12) Limitations (Say this honestly in viva)

- Requires internet for ayah/word/audio API in current flow.
- Mobile device and environment noise impact capture quality.
- Some scoring parts are heuristic; not equivalent to certified human tajweed examiner.
- Current backend storage is JSON files (good for prototype, not large-scale production).

---

## 13) Future Work (Strong FYP closing)

1. Full offline Quran text/audio cache in app.
2. Model calibration using labeled recitation dataset per Tajweed rule.
3. Better personalized coaching recommendations.
4. Move persistence to production database + background worker queue.
5. Add teacher dashboard and reviewer feedback loop.
6. Add App Check/hardening and stricter security controls.

---

## 14) 5-Minute Demo Script for Viva

1. Login to app.
2. Open a surah, choose an ayah.
3. Play qari audio.
4. Record your recitation.
5. Press compare.
6. Show:
   - overall score,
   - word-level status (correct/close/missing),
   - Tajweed rule breakdown.
7. Save session and open progress/memorization view.
8. Explain how repeated practice changes memorization status over time.

---

## 15) Quick "If Examiner Asks Deep Technical" Notes

- DTW here is applied on MFCC sequences after normalization.
- Word alignment uses normalized Arabic text + sequence similarity.
- Tajweed timing combines explicit rule checks + rhythm envelope similarity + duration ratio.
- Confidence multiplier protects against weak/no speech and low ASR confidence.

---

## 16) One-Line Conclusion for Viva Ending

"ReciteRight is a practical intelligent recitation coach: it combines Quran text APIs, speech transcription, DTW-based audio matching, and Tajweed-aware feedback to support daily guided Quran practice with measurable progress."
