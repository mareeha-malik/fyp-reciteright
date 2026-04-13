# -*- coding: utf-8 -*-
"""
Gamification Data Models for ReciteRight
Handles user profiles, sessions, memorization progress, streaks, levels, etc.
"""
from dataclasses import dataclass, field, asdict
from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta
import json


@dataclass
class UserProfile:
    """User profile with gamification metadata"""
    id: str
    name: str
    email: str
    joined_at: str  # ISO 8601 UTC timestamp
    daily_goal_minutes: int = 10
    daily_goal_ayahs: int = 0
    level: int = 1
    xp: int = 0
    longest_streak: int = 0
    avatar_url: Optional[str] = None
    timezone_offset: int = 0  # Minutes offset from UTC

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'UserProfile':
        return cls(**data)


@dataclass
class Session:
    """Single recitation session"""
    id: str
    user_id: str
    surah: int
    start_ayah: int
    end_ayah: int
    duration_minutes: float
    date: str  # UTC date (YYYY-MM-DD)
    accuracy_score: float  # 0-100
    mode: str  # "recitation" | "tajweed_lesson" | "review"
    created_at: str  # ISO 8601 UTC timestamp
    xp_earned: int = 0

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'Session':
        return cls(**data)


@dataclass
class MemorizationProgress:
    """Memorization progress for a surah"""
    user_id: str
    surah: int
    ayah_count_memorized: int = 0
    last_reviewed_at: Optional[str] = None  # ISO 8601 UTC timestamp
    high_accuracy_sessions: Dict[int, int] = field(default_factory=dict)  # {ayah_num: count}

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'MemorizationProgress':
        return cls(**data)


@dataclass
class DailyProgress:
    """Daily progress metrics"""
    date: str  # YYYY-MM-DD
    total_minutes: int = 0
    sessions_count: int = 0
    accuracy_average: float = 0.0
    status: str = "not_started"  # "not_started" | "in_progress" | "completed"

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass
class WeeklySummary:
    """Weekly progress summary"""
    week_start: str  # YYYY-MM-DD (Monday)
    total_minutes: int = 0
    days_active: int = 0
    average_minutes_per_day: float = 0.0
    daily_breakdown: List[DailyProgress] = field(default_factory=list)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "week_start": self.week_start,
            "total_minutes": self.total_minutes,
            "days_active": self.days_active,
            "average_minutes_per_day": self.average_minutes_per_day,
            "daily_breakdown": [d.to_dict() for d in self.daily_breakdown]
        }


@dataclass
class StreakInfo:
    """Streak information"""
    current_streak_days: int = 0
    longest_streak_days: int = 0
    last_session_date: Optional[str] = None  # YYYY-MM-DD

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass
class LevelInfo:
    """Level and XP information"""
    level_number: int
    xp_total: int
    xp_into_level: int
    xp_for_next_level: int
    percentage_to_next: float  # 0-100

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass
class TopSurah:
    """Top memorized surah"""
    surah_number: int
    surah_name: str
    memorized_percent: float
    ayah_count_memorized: int
    total_ayahs: int

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass
class HomeMetrics:
    """Aggregated metrics for home screen"""
    is_new_user: bool
    daily: Dict[str, Any]  # {minutes, goalMinutes, completionRatio, status}
    streak: Dict[str, Any]  # {current, longest}
    week: Dict[str, Any]  # {totalMinutes, daysActive, averagePerDay}
    level: Dict[str, Any]  # {xp, level, xpIntoLevel, xpForNextLevel, percentToNext}
    memorization: Dict[str, Any]  # {overallPercent, topSurahs}
    last_session: Optional[Dict[str, Any]] = None

    def to_dict(self) -> Dict[str, Any]:
        return {
            "isNewUser": self.is_new_user,
            "daily": self.daily,
            "streak": self.streak,
            "week": self.week,
            "level": self.level,
            "memorization": self.memorization,
            "lastSession": self.last_session,
        }

