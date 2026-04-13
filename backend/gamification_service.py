# -*- coding: utf-8 -*-
"""
Gamification API Endpoints for ReciteRight
Integrates with Flask app to provide home metrics and session tracking
"""
from typing import Dict, Any, List
from gamification_models import Session, HomeMetrics, MemorizationProgress
from gamification_logic import (
    get_today_progress,
    get_week_summary,
    get_month_summary,
    get_current_streak,
    get_level_from_xp,
    calculate_xp_for_session,
    get_overall_memorization_percent,
    get_top_surahs,
    is_new_user,
    get_utc_today_date,
    get_week_start_date,
    get_month_start_date,
    LEVEL_TITLES,
)


class GamificationService:
    """Service for aggregating gamification metrics"""

    def __init__(self):
        self.sessions: Dict[str, List[Session]] = {}  # user_id -> sessions
        self.memorization_progress: Dict[str, Dict[int, MemorizationProgress]] = {}
        self.user_profiles: Dict[str, Dict[str, Any]] = {}

    def add_session(
        self,
        user_id: str,
        session_data: Dict[str, Any]
    ) -> None:
        """Add a new session for a user"""
        if user_id not in self.sessions:
            self.sessions[user_id] = []

        session = Session(**session_data)
        self.sessions[user_id].append(session)

    def get_home_metrics(
        self,
        user_id: str,
        user_profile: Dict[str, Any],
        today_date: str,  # YYYY-MM-DD in user's timezone
    ) -> HomeMetrics:
        """
        Aggregate all home screen metrics

        Args:
            user_id: User ID
            user_profile: User profile dict
            today_date: Today's date

        Returns:
            HomeMetrics with all aggregated data
        """
        sessions = self.sessions.get(user_id, [])
        memo_progress = self.memorization_progress.get(user_id, {})

        # Daily progress
        daily_goal = user_profile.get("daily_goal_minutes", 10)
        daily_metrics = get_today_progress(sessions, today_date, daily_goal)

        # Streak
        longest_streak_record = user_profile.get("longest_streak", 0)
        streak_info = get_current_streak(sessions, today_date, longest_streak_record)

        # Week summary
        week_start = get_week_start_date(today_date)
        week_metrics = get_week_summary(sessions, week_start)

        # Level
        total_xp = user_profile.get("xp", 0)
        level_info = get_level_from_xp(total_xp)

        # Memorization
        overall_memo = get_overall_memorization_percent(memo_progress)
        top_surahs = get_top_surahs(memo_progress, limit=5)

        # Last session
        last_session = None
        if sessions:
            sessions_sorted = sorted(sessions, key=lambda s: s.created_at, reverse=True)
            last = sessions_sorted[0]
            last_session = {
                "surah": last.surah,
                "surahName": f"Surah {last.surah}",
                "startAyah": last.start_ayah,
                "endAyah": last.end_ayah,
                "lastRecitedAt": last.date,
                "accuracyScore": last.accuracy_score,
                "durationMinutes": last.duration_minutes
            }

        # Check if new user
        joined_at = user_profile.get("joined_at", "")
        new_user = is_new_user(joined_at, sessions)

        return HomeMetrics(
            is_new_user=new_user,
            daily={
                "minutes": daily_metrics["minutes"],
                "goalMinutes": daily_metrics["goalMinutes"],
                "completionRatio": daily_metrics["completionRatio"],
                "status": daily_metrics["status"]
            },
            streak={
                "current": streak_info.current_streak_days,
                "longest": streak_info.longest_streak_days
            },
            week={
                "totalMinutes": week_metrics["totalMinutes"],
                "daysActive": week_metrics["daysActive"],
                "averagePerDay": week_metrics["averageMinutesPerDay"],
                "dailyBreakdown": week_metrics["dailyBreakdown"]
            },
            level={
                "xp": level_info.xp_total,
                "level": level_info.level_number,
                "levelTitle": LEVEL_TITLES.get(level_info.level_number, "Scholar"),
                "xpIntoLevel": level_info.xp_into_level,
                "xpForNextLevel": level_info.xp_for_next_level,
                "percentToNext": level_info.percentage_to_next
            },
            memorization={
                "overallPercent": overall_memo,
                "topSurahs": top_surahs
            },
            last_session=last_session
        )


# Global service instance (in production, use dependency injection)
_gamification_service = GamificationService()


def get_gamification_service() -> GamificationService:
    """Get the global gamification service"""
    return _gamification_service

