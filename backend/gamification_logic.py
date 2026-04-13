# -*- coding: utf-8 -*-
"""
Gamification Logic & Calculations for ReciteRight
Handles streaks, XP, levels, memorization progress, etc.
"""
from typing import List, Dict, Any, Optional, Tuple
from datetime import datetime, timedelta
from gamification_models import (
    Session, MemorizationProgress, StreakInfo, LevelInfo,
    DailyProgress, WeeklySummary, TopSurah, HomeMetrics
)


# ══════════════════════════════════════════════════════════════════════════════
# DAILY PROGRESS CALCULATION
# ══════════════════════════════════════════════════════════════════════════════

def get_today_progress(
    sessions: List[Session],
    today_date: str,  # YYYY-MM-DD in user's timezone
    daily_goal_minutes: int
) -> Dict[str, Any]:
    """
    Calculate today's progress metrics

    Args:
        sessions: List of all user sessions
        today_date: Today's date in YYYY-MM-DD format (user timezone)
        daily_goal_minutes: Daily goal in minutes

    Returns:
        {
            "minutes": int,
            "goalMinutes": int,
            "completionRatio": float (0-1),
            "status": "not_started" | "in_progress" | "completed"
        }
    """
    today_sessions = [s for s in sessions if s.date == today_date]
    total_minutes = sum(s.duration_minutes for s in today_sessions)

    completion_ratio = min(1.0, total_minutes / max(1, daily_goal_minutes))

    if total_minutes == 0:
        status = "not_started"
    elif completion_ratio >= 1.0:
        status = "completed"
    else:
        status = "in_progress"

    return {
        "minutes": int(total_minutes),
        "goalMinutes": daily_goal_minutes,
        "completionRatio": round(completion_ratio, 2),
        "status": status
    }


# ══════════════════════════════════════════════════════════════════════════════
# WEEKLY / MONTHLY PROGRESS
# ══════════════════════════════════════════════════════════════════════════════

def get_date_range_sessions(
    sessions: List[Session],
    start_date: str,  # YYYY-MM-DD
    end_date: str     # YYYY-MM-DD (inclusive)
) -> List[Session]:
    """Get sessions within date range"""
    matching = []
    for s in sessions:
        if start_date <= s.date <= end_date:
            matching.append(s)
    return matching


def get_week_summary(
    sessions: List[Session],
    week_start_date: str  # YYYY-MM-DD (Monday)
) -> Dict[str, Any]:
    """
    Calculate weekly progress

    Args:
        sessions: List of all user sessions
        week_start_date: Week start date (Monday) in YYYY-MM-DD format

    Returns:
        {
            "weekStart": str (YYYY-MM-DD),
            "totalMinutes": int,
            "daysActive": int,
            "averageMinutesPerDay": float,
            "dailyBreakdown": [{"date": str, "minutes": int}, ...]
        }
    """
    start = datetime.strptime(week_start_date, "%Y-%m-%d")
    end = start + timedelta(days=6)
    end_str = end.strftime("%Y-%m-%d")

    week_sessions = get_date_range_sessions(sessions, week_start_date, end_str)

    # Group by date
    daily_minutes = {}
    for s in week_sessions:
        daily_minutes[s.date] = daily_minutes.get(s.date, 0) + s.duration_minutes

    total_minutes = sum(daily_minutes.values())
    days_active = len(daily_minutes)
    avg_per_day = total_minutes / 7 if total_minutes > 0 else 0

    # Create daily breakdown for all 7 days
    daily_breakdown = []
    for i in range(7):
        date = (start + timedelta(days=i)).strftime("%Y-%m-%d")
        minutes = int(daily_minutes.get(date, 0))
        daily_breakdown.append({
            "date": date,
            "minutes": minutes
        })

    return {
        "weekStart": week_start_date,
        "totalMinutes": int(total_minutes),
        "daysActive": days_active,
        "averageMinutesPerDay": round(avg_per_day, 2),
        "dailyBreakdown": daily_breakdown
    }


def get_month_summary(
    sessions: List[Session],
    month_start_date: str  # YYYY-MM-DD (1st of month)
) -> Dict[str, Any]:
    """Calculate monthly progress"""
    start = datetime.strptime(month_start_date, "%Y-%m-%d")

    # Get last day of month
    if start.month == 12:
        end = datetime(start.year + 1, 1, 1) - timedelta(days=1)
    else:
        end = datetime(start.year, start.month + 1, 1) - timedelta(days=1)

    end_str = end.strftime("%Y-%m-%d")
    month_sessions = get_date_range_sessions(sessions, month_start_date, end_str)

    daily_minutes = {}
    for s in month_sessions:
        daily_minutes[s.date] = daily_minutes.get(s.date, 0) + s.duration_minutes

    total_minutes = sum(daily_minutes.values())
    days_active = len(daily_minutes)
    days_in_month = (end - start).days + 1
    avg_per_day = total_minutes / days_in_month if total_minutes > 0 else 0

    return {
        "monthStart": month_start_date,
        "totalMinutes": int(total_minutes),
        "daysActive": days_active,
        "daysInMonth": days_in_month,
        "averageMinutesPerDay": round(avg_per_day, 2)
    }


# ══════════════════════════════════════════════════════════════════════════════
# STREAK LOGIC
# ══════════════════════════════════════════════════════════════════════════════

def get_current_streak(
    sessions: List[Session],
    today_date: str,  # YYYY-MM-DD
    longest_streak_record: int = 0
) -> StreakInfo:
    """
    Calculate current and longest streak

    Args:
        sessions: List of all user sessions
        today_date: Today's date (YYYY-MM-DD)
        longest_streak_record: Previously recorded longest streak

    Returns:
        StreakInfo with current and longest streaks
    """
    if not sessions:
        return StreakInfo(
            current_streak_days=0,
            longest_streak_days=max(longest_streak_record, 0),
            last_session_date=None
        )

    # Get unique active dates, sorted descending
    active_dates = sorted(set(s.date for s in sessions), reverse=True)

    if not active_dates:
        return StreakInfo(
            current_streak_days=0,
            longest_streak_days=max(longest_streak_record, 0),
            last_session_date=None
        )

    today = datetime.strptime(today_date, "%Y-%m-%d").date()
    last_session_date = active_dates[0]

    # Check if user did session today or yesterday
    last_activity = datetime.strptime(last_session_date, "%Y-%m-%d").date()
    days_since_last = (today - last_activity).days

    if days_since_last > 1:
        # Streak broken - last activity was more than 1 day ago
        current_streak = 0
    else:
        # Count consecutive days backwards
        current_streak = 1
        for i in range(1, len(active_dates)):
            prev_date = datetime.strptime(active_dates[i], "%Y-%m-%d").date()
            curr_date = datetime.strptime(active_dates[i-1], "%Y-%m-%d").date()

            days_diff = (curr_date - prev_date).days
            if days_diff == 1:
                current_streak += 1
            else:
                break

    # Calculate longest streak from all session data
    longest_streak = current_streak
    temp_streak = 1

    for i in range(1, len(active_dates)):
        prev_date = datetime.strptime(active_dates[i], "%Y-%m-%d").date()
        curr_date = datetime.strptime(active_dates[i-1], "%Y-%m-%d").date()

        days_diff = (curr_date - prev_date).days
        if days_diff == 1:
            temp_streak += 1
            longest_streak = max(longest_streak, temp_streak)
        else:
            temp_streak = 1

    # Compare with recorded longest streak
    longest_streak = max(longest_streak, longest_streak_record)

    return StreakInfo(
        current_streak_days=current_streak,
        longest_streak_days=longest_streak,
        last_session_date=last_session_date
    )


# ══════════════════════════════════════════════════════════════════════════════
# LEVEL & XP SYSTEM
# ══════════════════════════════════════════════════════════════════════════════

# XP Thresholds: level -> xp required
LEVEL_THRESHOLDS = {
    1: 0,
    2: 500,
    3: 1500,
    4: 2999,
    5: 5000,
    6: 7500,
    7: 10000,
    8: 13000,
    9: 16000,
    10: 20000,
}

LEVEL_TITLES = {
    1: "Starting Scholar",
    2: "Consistent Reciter",
    3: "Dedicated Learner",
    4: "Tajweed Student",
    5: "Quranic Enthusiast",
    6: "Hafiz-in-Training",
    7: "Advanced Reciter",
    8: "Surah Master",
    9: "Quran Warrior",
    10: "Hafiz al-Quran",
}


def calculate_xp_for_session(
    session: Session,
    daily_goal_met: bool = False
) -> int:
    """
    Calculate XP earned for a session

    Args:
        session: The session completed
        daily_goal_met: Whether daily goal was completed

    Returns:
        XP earned
    """
    # Base: 10 XP per minute
    base_xp = int(session.duration_minutes * 10)

    # Accuracy bonus
    if session.accuracy_score >= 90:
        base_xp = int(base_xp * 1.5)  # 50% bonus for excellent
    elif session.accuracy_score >= 75:
        base_xp = int(base_xp * 1.25)  # 25% bonus for very good

    # Daily goal bonus
    daily_bonus = 50 if daily_goal_met else 0

    return base_xp + daily_bonus


def get_level_from_xp(total_xp: int) -> LevelInfo:
    """
    Get level information from total XP

    Args:
        total_xp: Total XP accumulated

    Returns:
        LevelInfo with level, XP progress, etc.
    """
    level = 1
    for lvl in sorted(LEVEL_THRESHOLDS.keys(), reverse=True):
        if total_xp >= LEVEL_THRESHOLDS[lvl]:
            level = lvl
            break

    current_threshold = LEVEL_THRESHOLDS[level]
    next_threshold = LEVEL_THRESHOLDS.get(level + 1, LEVEL_THRESHOLDS[level] + 5000)

    xp_into_level = total_xp - current_threshold
    xp_for_next_level = next_threshold - current_threshold

    if xp_for_next_level > 0:
        percentage = min(100, (xp_into_level / xp_for_next_level) * 100)
    else:
        percentage = 0

    return LevelInfo(
        level_number=level,
        xp_total=total_xp,
        xp_into_level=xp_into_level,
        xp_for_next_level=xp_for_next_level,
        percentage_to_next=round(percentage, 1)
    )


# ══════════════════════════════════════════════════════════════════════════════
# MEMORIZATION PROGRESS
# ══════════════════════════════════════════════════════════════════════════════

SURAH_AYAH_COUNTS = {
    1: 7, 2: 286, 3: 200, 4: 176, 5: 120,
    6: 165, 7: 206, 8: 75, 9: 129, 10: 109,
    11: 123, 12: 111, 13: 43, 14: 52, 15: 99,
    16: 128, 17: 111, 18: 110, 19: 98, 20: 135,
    21: 112, 22: 78, 23: 118, 24: 64, 25: 77,
    26: 227, 27: 93, 28: 88, 29: 69, 30: 60,
    31: 34, 32: 30, 33: 73, 34: 54, 35: 45,
    36: 83, 37: 182, 38: 88, 39: 75, 40: 85,
    41: 54, 42: 53, 43: 89, 44: 59, 45: 37,
    46: 35, 47: 38, 48: 29, 49: 18, 50: 45,
    51: 60, 52: 49, 53: 62, 54: 55, 55: 78,
    56: 96, 57: 29, 58: 22, 59: 24, 60: 13,
    61: 14, 62: 11, 63: 11, 64: 18, 65: 12,
    66: 12, 67: 30, 68: 52, 69: 52, 70: 44,
    71: 28, 72: 28, 73: 20, 74: 56, 75: 40,
    76: 31, 77: 50, 78: 40, 79: 46, 80: 42,
    81: 29, 82: 19, 83: 36, 84: 25, 85: 22,
    86: 17, 87: 19, 88: 26, 89: 30, 90: 20,
    91: 15, 92: 21, 93: 11, 94: 8, 95: 8,
    96: 19, 97: 5, 98: 8, 99: 8, 100: 11,
    101: 11, 102: 8, 103: 3, 104: 9, 105: 5,
    106: 4, 107: 7, 108: 3, 109: 6, 110: 3,
    111: 5, 112: 4, 113: 5, 114: 6,
}

SURAH_NAMES = {
    1: "Al-Fatiha", 2: "Al-Baqara", 3: "Al-Imran", 4: "An-Nisa", 5: "Al-Maidah",
    6: "Al-Anam", 7: "Al-Araf", 8: "Al-Anfal", 9: "At-Tawba", 10: "Yunus",
    11: "Hud", 12: "Yusuf", 13: "Ar-Rad", 14: "Ibrahim", 15: "Al-Hijr",
    16: "An-Nahl", 17: "Al-Isra", 18: "Al-Kahf", 19: "Maryam", 20: "Taha",
    21: "Al-Anbiya", 22: "Al-Hajj", 23: "Al-Mu'minun", 24: "An-Nur", 25: "Al-Furqan",
    26: "Ash-Shuara", 27: "An-Naml", 28: "Al-Qasas", 29: "Al-Ankabut", 30: "Ar-Rum",
    31: "Luqman", 32: "As-Sajda", 33: "Al-Ahzab", 34: "Saba", 35: "Fatir",
    36: "Yasin", 37: "As-Saffat", 38: "Sad", 39: "Az-Zumar", 40: "Ghafir",
    41: "Fussilat", 42: "Ash-Shura", 43: "Az-Zukhruf", 44: "Ad-Dukhan", 45: "Al-Jathiya",
    46: "Al-Ahqaf", 47: "Muhammad", 48: "Al-Fath", 49: "Al-Hujurat", 50: "Qaf",
    51: "Ad-Dhariyat", 52: "At-Tur", 53: "An-Najm", 54: "Al-Qamar", 55: "Ar-Rahman",
    56: "Al-Waqia", 57: "Al-Hadid", 58: "Al-Mujadila", 59: "Al-Hashr", 60: "Al-Mumtahina",
    61: "As-Saff", 62: "Al-Jumuah", 63: "Al-Munafiqun", 64: "At-Taghabun", 65: "At-Talaq",
    66: "At-Tahrim", 67: "Al-Mulk", 68: "Al-Qalam", 69: "Al-Haaqqa", 70: "Al-Maarij",
    71: "Nuh", 72: "Al-Jinn", 73: "Al-Muzzammil", 74: "Al-Muddassir", 75: "Al-Qiyamah",
    76: "Al-Insan", 77: "Al-Mursalat", 78: "An-Naba", 79: "An-Naziat", 80: "Abasa",
    81: "At-Takwir", 82: "Al-Infitar", 83: "Al-Mutaffifin", 84: "Al-Inshiqaq", 85: "Al-Buruj",
    86: "At-Tariq", 87: "Al-Ala", 88: "Al-Ghashiya", 89: "Al-Fajr", 90: "Al-Balad",
    91: "Ash-Shams", 92: "Al-Lail", 93: "Ad-Duha", 94: "Al-Inshirah", 95: "At-Tin",
    96: "Al-Alaq", 97: "Al-Qadr", 98: "Al-Bayyinah", 99: "Az-Zalzalah", 100: "Al-Adiyat",
    101: "Al-Qaria", 102: "At-Takathur", 103: "Al-Asr", 104: "Al-Humaza", 105: "Al-Fil",
    106: "Quraysh", 107: "Al-Maun", 108: "Al-Kawthar", 109: "Al-Kafirun", 110: "An-Nasr",
    111: "Al-Lahab", 112: "Al-Ikhlas", 113: "Al-Falaq", 114: "An-Nas",
}


def update_memorization_after_session(
    session: Session,
    previous_progress: Dict[int, MemorizationProgress],
    accuracy_threshold: float = 90.0,
    min_high_accuracy_sessions: int = 3
) -> Dict[int, MemorizationProgress]:
    """
    Update memorization progress after a session

    An ayah is marked as memorized when:
    - It's been recited 3+ times with accuracy > 90%, OR
    - User explicitly marks it memorized

    Args:
        session: Completed session
        previous_progress: Current memorization progress by surah
        accuracy_threshold: Accuracy score needed for high-accuracy count
        min_high_accuracy_sessions: Sessions needed to mark as memorized

    Returns:
        Updated progress dictionary
    """
    surah = session.surah
    updated_progress = dict(previous_progress)

    if surah not in updated_progress:
        updated_progress[surah] = MemorizationProgress(
            user_id=session.user_id,
            surah=surah
        )

    prog = updated_progress[surah]

    # Only track high-accuracy sessions
    if session.accuracy_score >= accuracy_threshold:
        # Mark ayahs in this session as high-accuracy
        for ayah in range(session.start_ayah, session.end_ayah + 1):
            if ayah not in prog.high_accuracy_sessions:
                prog.high_accuracy_sessions[ayah] = 0
            prog.high_accuracy_sessions[ayah] += 1

        # Check which ayahs have reached memorization threshold
        memo_count = 0
        for ayah, count in prog.high_accuracy_sessions.items():
            if count >= min_high_accuracy_sessions:
                memo_count += 1

        prog.ayah_count_memorized = memo_count
        prog.last_reviewed_at = session.created_at

    updated_progress[surah] = prog
    return updated_progress


def get_surah_memorization_percent(
    surah: int,
    ayah_count_memorized: int
) -> float:
    """Get memorization percentage for a surah"""
    total_ayahs = SURAH_AYAH_COUNTS.get(surah, 1)
    return round((ayah_count_memorized / total_ayahs) * 100, 1)


def get_overall_memorization_percent(
    memorization_progress: Dict[int, MemorizationProgress]
) -> float:
    """Get overall memorization percentage across all surahs"""
    if not memorization_progress:
        return 0.0

    total_memorized = 0
    total_ayahs = 0

    for surah, prog in memorization_progress.items():
        total_memorized += prog.ayah_count_memorized
        total_ayahs += SURAH_AYAH_COUNTS.get(surah, 0)

    if total_ayahs == 0:
        return 0.0

    return round((total_memorized / total_ayahs) * 100, 1)


def get_top_surahs(
    memorization_progress: Dict[int, MemorizationProgress],
    limit: int = 5
) -> List[Dict[str, Any]]:
    """Get top memorized surahs"""
    top_surahs = []

    for surah, prog in memorization_progress.items():
        if prog.ayah_count_memorized > 0:
            percent = get_surah_memorization_percent(surah, prog.ayah_count_memorized)
            top_surahs.append({
                "surahNumber": surah,
                "surahName": SURAH_NAMES.get(surah, f"Surah {surah}"),
                "memorizedPercent": percent,
                "ayahCountMemorized": prog.ayah_count_memorized,
                "totalAyahs": SURAH_AYAH_COUNTS.get(surah, 0)
            })

    # Sort by percentage memorized (descending)
    top_surahs.sort(key=lambda x: x["memorizedPercent"], reverse=True)

    return top_surahs[:limit]


# ══════════════════════════════════════════════════════════════════════════════
# NEW vs RETURNING USER
# ══════════════════════════════════════════════════════════════════════════════

def is_new_user(
    joined_at: str,  # ISO 8601 UTC timestamp
    sessions: List[Session],
    days_threshold: int = 1
) -> bool:
    """
    Determine if user is new

    Args:
        joined_at: When user joined (ISO 8601 UTC)
        sessions: User's sessions
        days_threshold: Days since join to consider "new"

    Returns:
        True if user has no sessions or joined recently
    """
    if not sessions or len(sessions) == 0:
        return True

    try:
        join_time = datetime.fromisoformat(joined_at.replace('Z', '+00:00'))
        now = datetime.utcnow().replace(tzinfo=join_time.tzinfo)
        days_since_join = (now - join_time).days
        return days_since_join <= days_threshold
    except:
        return True


# ══════════════════════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ══════════════════════════════════════════════════════════════════════════════

def get_utc_today_date(timezone_offset_minutes: int = 0) -> str:
    """
    Get today's date in user's timezone as YYYY-MM-DD

    Args:
        timezone_offset_minutes: User's timezone offset from UTC in minutes

    Returns:
        Today's date as YYYY-MM-DD in user's timezone
    """
    now = datetime.utcnow()
    user_now = now + timedelta(minutes=timezone_offset_minutes)
    return user_now.strftime("%Y-%m-%d")


def get_week_start_date(date_str: str) -> str:
    """
    Get the Monday of the week containing this date

    Args:
        date_str: Date as YYYY-MM-DD

    Returns:
        Monday of that week as YYYY-MM-DD
    """
    date_obj = datetime.strptime(date_str, "%Y-%m-%d").date()
    # Monday is weekday 0
    monday = date_obj - timedelta(days=date_obj.weekday())
    return monday.strftime("%Y-%m-%d")


def get_month_start_date(date_str: str) -> str:
    """Get the 1st of the month"""
    date_obj = datetime.strptime(date_str, "%Y-%m-%d").date()
    month_start = date_obj.replace(day=1)
    return month_start.strftime("%Y-%m-%d")

