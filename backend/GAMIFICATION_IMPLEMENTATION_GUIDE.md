# Gamification Implementation Guide for ReciteRight

## Overview

This guide implements a complete gamification system for the ReciteRight Quran recitation app, including:

- ✅ **Daily Progress Tracking** - Minutes/ayahs with visual progress rings
- ✅ **Weekly/Monthly Analytics** - Aggregated stats and charts
- ✅ **Streak System** - Current and longest streaks with edge cases
- ✅ **XP & Leveling** - Dynamic XP calculation with bonuses and 10 levels
- ✅ **Memorization Progress** - Per-surah and overall progress tracking
- ✅ **New vs Returning User States** - Conditional onboarding UX
- ✅ **Home Screen API** - Single endpoint aggregating all metrics

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    FLUTTER FRONTEND                      │
│                   (Mobile / Web App)                      │
├─────────────────────────────────────────────────────────┤
│  • GamificationService (Dio HTTP client)                │
│  • gamification_models.dart (Data classes)              │
│  • HomeScreen (UI that displays metrics)                │
└────────────────┬────────────────────────────────────────┘
                 │
                 │ HTTP REST API
                 │
┌────────────────▼────────────────────────────────────────┐
│                   FLASK BACKEND                          │
│                  (Python / Database)                      │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  gamification_routes.py                                  │
│  ├─ GET  /api/gamification/home-metrics                 │
│  ├─ POST /api/gamification/session                      │
│  ├─ GET  /api/gamification/daily-progress              │
│  ├─ GET  /api/gamification/week-summary                │
│  ├─ GET  /api/gamification/streak                      │
│  ├─ GET  /api/gamification/level                       │
│  ├─ GET  /api/gamification/memorization                │
│  └─ PUT  /api/gamification/daily-goal                  │
│                                                           │
│  gamification_logic.py                                   │
│  ├─ Daily/Weekly/Monthly calculations                  │
│  ├─ Streak algorithm                                    │
│  ├─ XP & Level system                                  │
│  ├─ Memorization tracking                              │
│  └─ Helper functions (date handling, etc)              │
│                                                           │
│  gamification_models.py                                  │
│  ├─ UserProfile, Session, MemorizationProgress         │
│  ├─ HomeMetrics, LevelInfo, StreakInfo, etc.           │
│  └─ Data serialization                                  │
│                                                           │
│  gamification_service.py                                 │
│  └─ Service layer for aggregating metrics              │
│                                                           │
└─────────────────────────────────────────────────────────┘
         │
         │ Database (Firebase Firestore / SQLite)
         │
    ┌────▼───────────────────┐
    │  Users                  │
    │  Sessions               │
    │  MemorizationProgress   │
    └────────────────────────┘
```

## Database Schema

### Users Collection
```json
{
  "id": "user123",
  "name": "Ahmed",
  "email": "ahmed@example.com",
  "joinedAt": "2026-01-15T10:00:00Z",
  "dailyGoalMinutes": 10,
  "level": 2,
  "xp": 750,
  "longestStreak": 15,
  "timezone": 180  // +3:00 hours in minutes
}
```

### Sessions Collection
```json
{
  "id": "session456",
  "userId": "user123",
  "surah": 2,
  "startAyah": 5,
  "endAyah": 10,
  "durationMinutes": 8.5,
  "date": "2026-04-13",  // UTC date in YYYY-MM-DD
  "accuracyScore": 92.5,
  "mode": "recitation",
  "createdAt": "2026-04-13T14:30:00Z",
  "xpEarned": 127
}
```

### MemorizationProgress Collection
```json
{
  "userId": "user123",
  "surah": 2,
  "ayahCountMemorized": 15,
  "lastReviewedAt": "2026-04-12T10:00:00Z",
  "highAccuracySessions": {
    "1": 3,
    "2": 2,
    "3": 4
  }
}
```

## Implementation Steps

### Step 1: Backend Setup

#### 1.1 Add dependencies to `requirements.txt`:
```bash
flask==2.3.0
flask-cors==4.0.0
python-dataclasses-json==0.5.14
```

#### 1.2 Import in your `app.py`:
```python
from gamification_models import *
from gamification_logic import *
from gamification_service import get_gamification_service
from gamification_routes import setup_gamification_routes

app = Flask(__name__)
CORS(app)

# ... existing routes ...

# Setup gamification endpoints
setup_gamification_routes(app)

if __name__ == "__main__":
    app.run(debug=True, port=8000, host="0.0.0.0")
```

#### 1.3 Integrate with database:
Replace the in-memory storage in `gamification_service.py` with actual database calls:

```python
def get_home_metrics(self, user_id: str, user_profile: Dict, today_date: str):
    # Load from database instead of in-memory
    sessions = load_sessions_from_db(user_id)
    memo_progress = load_memorization_from_db(user_id)
    
    # ... rest of calculation ...
```

### Step 2: Frontend Setup

#### 2.1 Generate Dart models:
```bash
cd frontend/Frontend
flutter pub run build_runner build
```

#### 2.2 Add to main.dart providers:
```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => ThemeService()),
    Provider(create: (_) => GamificationService()),  // ← Add this
  ],
  // ...
)
```

#### 2.3 Use in screens:
```dart
import 'package:tajweed_corrector/services/gamification_service.dart';

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<HomeMetrics> _metricssFuture;

  @override
  void initState() {
    super.initState();
    final service = context.read<GamificationService>();
    _metricsFuture = service.getHomeMetrics(userId: "USER_ID");
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HomeMetrics>(
      future: _metricsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final metrics = snapshot.data!;
          return buildHomeUI(metrics);
        }
        return LoadingScreen();
      },
    );
  }
}
```

## Key Calculations

### Daily Progress

```
totalMinutes = sum of all session durations today
completionRatio = min(totalMinutes / dailyGoalMinutes, 1.0)
status = {
  "not_started": if totalMinutes == 0
  "in_progress": if 0 < totalMinutes < dailyGoalMinutes
  "completed": if totalMinutes >= dailyGoalMinutes
}
```

### Streak Calculation

```
1. Get unique session dates, sort descending
2. Start from today, count consecutive days backwards
3. Break if gap found (> 1 day)
4. Compare with recorded longest streak

Edge cases:
- No sessions → 0 streak
- Session 2 days ago → streak broken
- Session today only → streak = 1
```

### XP System

```
baseXp = durationMinutes × 10

Accuracy bonuses:
- score >= 90: baseXp × 1.5
- score >= 75: baseXp × 1.25

Daily goal bonus: +50 XP if goal met

Levels:
- Level 1: 0 XP
- Level 2: 500 XP ("Consistent Reciter")
- Level 3: 1500 XP ("Dedicated Learner")
- Level 4: 2999 XP ("Tajweed Student")
- ... (see gamification_logic.py for full)
```

### Memorization Tracking

```
An ayah is memorized when:
- Recited 3+ times with accuracy > 90%, OR
- User explicitly marks as memorized

Overall % = (total memorized ayahs / 6236 total Quran ayahs) × 100
```

## API Endpoints

### GET /api/gamification/home-metrics
**Single endpoint for all home screen data**

Query: `userId=user123`

Response:
```json
{
  "isNewUser": false,
  "daily": {
    "minutes": 8,
    "goalMinutes": 10,
    "completionRatio": 0.8,
    "status": "in_progress"
  },
  "streak": {
    "current": 3,
    "longest": 10
  },
  "week": {
    "totalMinutes": 45,
    "daysActive": 4,
    "averagePerDay": 11.25,
    "dailyBreakdown": [
      {"date": "2026-04-13", "minutes": 12},
      {"date": "2026-04-12", "minutes": 10},
      ...
    ]
  },
  "level": {
    "xp": 1350,
    "level": 2,
    "levelTitle": "Consistent Reciter",
    "xpIntoLevel": 350,
    "xpForNextLevel": 1000,
    "percentToNext": 35.0
  },
  "memorization": {
    "overallPercent": 18,
    "topSurahs": [
      {
        "surahNumber": 1,
        "surahName": "Al-Fatiha",
        "memorizedPercent": 100,
        "ayahCountMemorized": 7,
        "totalAyahs": 7
      }
    ]
  },
  "lastSession": {
    "surah": 2,
    "surahName": "Al-Baqara",
    "startAyah": 5,
    "endAyah": 7,
    "lastRecitedAt": "2026-04-12",
    "accuracyScore": 92.5,
    "durationMinutes": 8
  }
}
```

### POST /api/gamification/session
**Record a new session after recitation**

Body:
```json
{
  "userId": "user123",
  "surah": 2,
  "startAyah": 5,
  "endAyah": 10,
  "durationMinutes": 8.5,
  "accuracyScore": 92.5,
  "mode": "recitation"
}
```

Response:
```json
{
  "success": true,
  "sessionId": "session456",
  "xpEarned": 150,
  "levelUp": false,
  "newLevel": 2,
  "totalXp": 1500,
  "message": "Session recorded! +150 XP earned"
}
```

### GET /api/gamification/daily-progress
Get progress for specific date

Query: `userId=user123&date=2026-04-13`

### GET /api/gamification/week-summary
Get weekly summary

Query: `userId=user123&weekStart=2026-04-07`

### GET /api/gamification/streak
Get current streak info

Query: `userId=user123`

### GET /api/gamification/level
Get level and XP info

Query: `userId=user123`

### GET /api/gamification/memorization
Get memorization progress

Query: `userId=user123`

### PUT /api/gamification/daily-goal
Update user's daily goal

Body:
```json
{
  "userId": "user123",
  "dailyGoalMinutes": 15
}
```

## Frontend UI Components

### Progress Ring
```dart
CircularPercentIndicator(
  radius: 120.0,
  lineWidth: 8.0,
  percent: metrics.dailyCompletion,
  center: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text('${metrics.dailyMinutes}/${metrics.dailyGoal}'),
      Text('minutes today'),
    ],
  ),
  progressColor: Colors.blue,
  backgroundColor: Colors.grey[200],
)
```

### Streak Pill
```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration(
    color: metrics.currentStreak > 0 ? Colors.orange : Colors.grey,
    borderRadius: BorderRadius.circular(20),
  ),
  child: Row(
    children: [
      Icon(Icons.local_fire_department),
      Text('${metrics.currentStreak} day streak'),
    ],
  ),
)
```

### Level Card
```dart
Card(
  child: Padding(
    padding: EdgeInsets.all(16),
    child: Column(
      children: [
        Text('Level ${metrics.userLevel}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        LinearProgressIndicator(value: metrics.percentToNextLevel / 100),
        Text('${metrics.totalXp} / ${metrics.totalXp + (1000 - metrics.totalXp % 1000)} XP'),
      ],
    ),
  ),
)
```

### Memorization Progress
```dart
ListView.builder(
  itemCount: metrics.topSurahs.length,
  itemBuilder: (context, index) {
    final surah = metrics.topSurahs[index];
    return ListTile(
      title: Text(surah['surahName']),
      subtitle: Text('${surah['memorizedPercent']}% memorized'),
      trailing: CircularPercentIndicator(
        radius: 20,
        percent: surah['memorizedPercent'] / 100,
      ),
    );
  },
)
```

## Time Zone Handling

### Backend (Python)
```python
def get_utc_today_date(timezone_offset_minutes: int = 0) -> str:
    """Get today's date in user's timezone"""
    now = datetime.utcnow()
    user_now = now + timedelta(minutes=timezone_offset_minutes)
    return user_now.strftime("%Y-%m-%d")
```

### Frontend (Dart)
```dart
// In GamificationService
final userTimezone = DateTime.now().timeZoneOffset.inMinutes;

final todayResponse = await _dio.get(
  '/api/gamification/daily-progress',
  queryParameters: {
    'userId': userId,
    'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
    'timezone': userTimezone,
  },
);
```

## Error Handling

### Handle NaN and Division by Zero
```python
def get_week_summary(...):
    avg_per_day = total_minutes / 7 if total_minutes > 0 else 0  # ✓ Safe
    avg_per_day = total_minutes / 7  # ✗ Could error
```

### Handle Empty States
```dart
if (metrics.topSurahs.isEmpty) {
  return Center(child: Text('Start reciting to track progress!'));
}
```

### Handle Network Errors
```dart
Future<HomeMetrics> getHomeMetrics({required String userId}) async {
  try {
    final response = await _dio.get(...);
    return HomeMetrics.fromJson(response.data);
  } on DioException catch (e) {
    if (e.type == DioExceptionType.connectionTimeout) {
      // Handle offline
      return HomeMetrics.fromCache();
    }
    rethrow;
  }
}
```

## Performance Optimization

### 1. Cache Metrics Locally
```dart
class CachedGamificationService extends GamificationService {
  HomeMetrics? _cachedMetrics;
  DateTime? _lastFetch;
  
  Future<HomeMetrics> getHomeMetrics({required String userId}) async {
    if (_lastFetch != null && 
        DateTime.now().difference(_lastFetch!).inMinutes < 5) {
      return _cachedMetrics!;
    }
    
    final metrics = await super.getHomeMetrics(userId: userId);
    _cachedMetrics = metrics;
    _lastFetch = DateTime.now();
    return metrics;
  }
}
```

### 2. Use Single Home Endpoint
Don't make 5 separate API calls; use `/api/gamification/home-metrics` instead:
```dart
// ✓ Good: 1 request
final metrics = await service.getHomeMetrics(userId);

// ✗ Bad: 5+ requests
final daily = await service.getDailyProgress();
final weekly = await service.getWeekSummary();
final streak = await service.getStreakInfo();
final level = await service.getLevelInfo();
final memo = await service.getMemorizationProgress();
```

### 3. Paginate Top Surahs
```python
def get_top_surahs(memorization_progress, limit=5):
    # Only return top 5 surahs instead of all 114
    return sorted_surahs[:limit]
```

## Testing

### Unit Tests (Python)
```python
def test_streak_calculation():
    sessions = [
        Session(..., date="2026-04-13"),
        Session(..., date="2026-04-12"),
        Session(..., date="2026-04-11"),
    ]
    today = "2026-04-13"
    streak = get_current_streak(sessions, today)
    assert streak.current_streak_days == 3

def test_xp_calculation():
    session = Session(..., duration_minutes=10, accuracy_score=92)
    xp = calculate_xp_for_session(session, daily_goal_met=True)
    assert xp == 200  # 10 * 10 * 1.5 (bonus) + 50 (daily goal)
```

### Widget Tests (Flutter)
```dart
void main() {
  group('HomeMetrics', () {
    test('Daily completion ratio caps at 1.0', () {
      final metrics = HomeMetrics(
        daily: {'minutes': 15, 'goalMinutes': 10, 'completionRatio': 1.0},
        ...
      );
      expect(metrics.dailyCompletion, 1.0);
    });
  });
}
```

## Future Enhancements

1. **Achievements/Badges**
   - "First Surah Memorized"
   - "7-Day Streak"
   - "100 XP Earned"

2. **Leaderboards**
   - Top recitors by XP
   - Top by accuracy
   - Top by memorization %

3. **Social Features**
   - Share streaks
   - Challenge friends
   - Group competitions

4. **Advanced Analytics**
   - Accuracy trends
   - Best performing surahs
   - Peak practice times

5. **Personalized Recommendations**
   - "You're 2 minutes away from daily goal"
   - "Review this surah you struggled with"
   - "You haven't recited in 2 days!"

## Troubleshooting

| Problem | Solution |
|---------|----------|
| NaN in charts | Add default value: `avg ?? 0.0` |
| Streak broken unexpectedly | Check UTC vs local time conversion |
| XP not updating | Verify session endpoint writes to DB |
| Level title missing | Ensure all levels are in LEVEL_TITLES dict |
| Empty top surahs | User hasn't memorized anything yet → show onboarding |

## References

- **Flutter JSON Serialization**: https://flutter.dev/docs/development/data-and-backend/json
- **Dio HTTP Client**: https://pub.dev/packages/dio
- **Flask Documentation**: https://flask.palletsprojects.com/
- **Python datetime**: https://docs.python.org/3/library/datetime.html

## Support

For questions about the implementation, refer to the comments in:
- `backend/gamification_logic.py` - Core calculation logic
- `backend/gamification_routes.py` - API endpoints
- `frontend/Frontend/lib/services/gamification_service.dart` - Frontend service

