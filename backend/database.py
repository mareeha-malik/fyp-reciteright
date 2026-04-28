# -*- coding: utf-8 -*-
"""
Database persistence layer for ReciteRight gamification
Uses JSON files for simplicity (can be replaced with SQLite/PostgreSQL)
"""
import json
import os
from typing import Dict, Any, List, Optional
from datetime import datetime
from gamification_models import Session, UserProfile, MemorizationProgress


class Database:
    """Simple JSON-based database"""

    def __init__(self, base_dir: str = "data"):
        self.base_dir = base_dir
        self.users_dir = os.path.join(base_dir, "users")
        self.sessions_dir = os.path.join(base_dir, "sessions")

        # Create directories if they don't exist
        os.makedirs(self.users_dir, exist_ok=True)
        os.makedirs(self.sessions_dir, exist_ok=True)

    # ═══════════════════════════════════════════════════════════════════════════
    # USER PROFILE OPERATIONS
    # ═══════════════════════════════════════════════════════════════════════════

    def get_user(self, user_id: str) -> Optional[Dict[str, Any]]:
        """Get user profile"""
        import re
        safe_id = re.sub(r'[\\/*?:"<>|\r\n]', '_', str(user_id)).strip()
        filepath = os.path.join(self.users_dir, f"{safe_id}.json")
        if os.path.exists(filepath):
            with open(filepath, 'r', encoding='utf-8') as f:
                return json.load(f)
        return None

    def save_user(self, user_id: str, user_data: Dict[str, Any]) -> None:
        """Save user profile"""
        import re
        safe_id = re.sub(r'[\\/*?:"<>|\r\n]', '_', str(user_id)).strip()
        filepath = os.path.join(self.users_dir, f"{safe_id}.json")
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(user_data, f, indent=2, ensure_ascii=False)

    def create_user(
        self,
        user_id: str,
        name: str,
        email: str,
        daily_goal_minutes: int = 10
    ) -> Dict[str, Any]:
        """Create a new user"""
        user_data = {
            "id": user_id,
            "name": name,
            "email": email,
            "joined_at": datetime.utcnow().isoformat() + "Z",
            "daily_goal_minutes": daily_goal_minutes,
            "daily_goal_ayahs": 0,
            "level": 1,
            "xp": 0,
            "longest_streak": 0,
            "avatar_url": None,
            "timezone_offset": 0
        }
        self.save_user(user_id, user_data)
        return user_data

    def update_user_xp(self, user_id: str, xp_earned: int) -> Dict[str, Any]:
        """Add XP to user"""
        user = self.get_user(user_id)
        if not user:
            raise ValueError(f"User {user_id} not found")

        user["xp"] = user.get("xp", 0) + xp_earned
        self.save_user(user_id, user)
        return user

    def update_user_longest_streak(self, user_id: str, streak_days: int) -> None:
        """Update user's longest streak"""
        user = self.get_user(user_id)
        if user:
            user["longest_streak"] = max(user.get("longest_streak", 0), streak_days)
            self.save_user(user_id, user)

    # ═══════════════════════════════════════════════════════════════════════════
    # SESSION OPERATIONS
    # ═══════════════════════════════════════════════════════════════════════════

    def save_session(self, user_id: str, session: Dict[str, Any]) -> None:
        """Save a new session"""
        import re
        safe_id = re.sub(r'[\\/*?:"<>|\r\n]', '_', str(user_id)).strip()
        sessions = self.get_user_sessions(safe_id, limit=999)
        sessions.append(session)

        filepath = os.path.join(self.sessions_dir, f"{safe_id}.json")
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(sessions, f, indent=2, ensure_ascii=False)

    def get_session(self, user_id: str, session_id: str) -> Optional[Dict[str, Any]]:
        """Get a specific session"""
        filepath = os.path.join(self.sessions_dir, user_id, f"{session_id}.json")
        if os.path.exists(filepath):
            with open(filepath, 'r', encoding='utf-8') as f:
                return json.load(f)
        return None

    def get_user_sessions(self, user_id: str, limit: int = 50) -> List[Dict[str, Any]]:
        """Get recent sessions for user"""
        import re
        safe_id = re.sub(r'[\\/*?:"<>|\r\n]', '_', str(user_id)).strip()
        filepath = os.path.join(self.sessions_dir, f"{safe_id}.json")
        if not os.path.exists(filepath):
            return []

        with open(filepath, 'r', encoding='utf-8') as f:
            return json.load(f)[:limit]

    def get_sessions_by_date(self, user_id: str, date: str) -> List[Dict[str, Any]]:
        """Get sessions for a specific date (YYYY-MM-DD)"""
        all_sessions = self.get_user_sessions(user_id)
        return [s for s in all_sessions if s.get("date") == date]

    # ═══════════════════════════════════════════════════════════════════════════
    # MEMORIZATION PROGRESS OPERATIONS
    # ═══════════════════════════════════════════════════════════════════════════

    def get_memorization_progress(self, user_id: str) -> Dict[int, Dict[str, Any]]:
        """Get memorization progress for all surahs"""
        filepath = os.path.join(self.users_dir, f"{user_id}_memorization.json")
        if os.path.exists(filepath):
            with open(filepath, 'r', encoding='utf-8') as f:
                data = json.load(f)
                # Convert string keys back to int
                return {int(k): v for k, v in data.items()}
        return {}

    def save_memorization_progress(
        self,
        user_id: str,
        progress: Dict[int, Dict[str, Any]]
    ) -> None:
        """Save memorization progress"""
        filepath = os.path.join(self.users_dir, f"{user_id}_memorization.json")
        # Convert int keys to strings for JSON serialization
        data = {str(k): v for k, v in progress.items()}
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)

    def update_memorization_progress(
        self,
        user_id: str,
        surah: int,
        ayah_count: int,
        last_reviewed_at: Optional[str] = None,
        high_accuracy_sessions: Optional[Dict[int, int]] = None
    ) -> None:
        """Update memorization progress for a surah"""
        progress = self.get_memorization_progress(user_id)

        progress[surah] = {
            "user_id": user_id,
            "surah": surah,
            "ayah_count_memorized": ayah_count,
            "last_reviewed_at": last_reviewed_at,
            "high_accuracy_sessions": high_accuracy_sessions or {}
        }

        self.save_memorization_progress(user_id, progress)

    # ═══════════════════════════════════════════════════════════════════════════
    # RECITATION SESSION OPERATIONS
    # ═══════════════════════════════════════════════════════════════════════════

    def save_recitation_session(self, user_id: str, session_data: Dict[str, Any]) -> None:
        """Save a recitation session"""
        user_sessions_dir = os.path.join(self.sessions_dir, user_id)
        os.makedirs(user_sessions_dir, exist_ok=True)

        session_id = session_data.get("id")
        filepath = os.path.join(user_sessions_dir, f"session_{session_id}.json")

        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(session_data, f, indent=2, ensure_ascii=False)

    def get_recitation_session(self, user_id: str, session_id: str) -> Optional[Dict[str, Any]]:
        """Get a specific recitation session"""
        filepath = os.path.join(self.sessions_dir, user_id, f"session_{session_id}.json")
        if os.path.exists(filepath):
            with open(filepath, 'r', encoding='utf-8') as f:
                return json.load(f)
        return None

    def get_user_recitation_sessions(
        self,
        user_id: str,
        limit: Optional[int] = None,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """Get all recitation sessions for a user with optional filtering"""
        user_sessions_dir = os.path.join(self.sessions_dir, user_id)

        if not os.path.exists(user_sessions_dir):
            return []

        sessions = []
        for filename in os.listdir(user_sessions_dir):
            if filename.endswith('.json') and filename.startswith('session_'):
                filepath = os.path.join(user_sessions_dir, filename)
                with open(filepath, 'r', encoding='utf-8') as f:
                    session = json.load(f)

                    # Filter by date range if provided
                    if start_date or end_date:
                        session_date = session.get("date_time", "")[:10]  # YYYY-MM-DD
                        if start_date and session_date < start_date:
                            continue
                        if end_date and session_date > end_date:
                            continue

                    sessions.append(session)

        # Sort by date_time descending
        sessions.sort(key=lambda s: s.get("date_time", ""), reverse=True)

        if limit:
            sessions = sessions[:limit]

        return sessions

    def get_sessions_by_date_range(
        self,
        user_id: str,
        start_date: str,
        end_date: str
    ) -> List[Dict[str, Any]]:
        """Get sessions within a date range (YYYY-MM-DD format)"""
        return self.get_user_recitation_sessions(user_id, start_date=start_date, end_date=end_date)

    def get_all_mistakes(self, user_id: str) -> List[Dict[str, Any]]:
        """Get all mistakes from all sessions"""
        sessions = self.get_user_recitation_sessions(user_id)
        all_mistakes = []

        for session in sessions:
            mistakes = session.get("mistakes", [])
            for mistake in mistakes:
                mistake["session_id"] = session.get("id")
                mistake["date_time"] = session.get("date_time")
                mistake["mode"] = session.get("mode")
                all_mistakes.append(mistake)

        return all_mistakes

    # ═══════════════════════════════════════════════════════════════════════════
    # MEMORIZATION ITEM OPERATIONS (ayah-level)
    # ═══════════════════════════════════════════════════════════════════════════

    def _memorization_items_path(self, user_id: str) -> str:
        return os.path.join(self.users_dir, f"{user_id}_memorization_items.json")

    def get_memorization_items(self, user_id: str) -> List[Dict[str, Any]]:
        """Get ayah-level memorization items for user."""
        path = self._memorization_items_path(user_id)
        if not os.path.exists(path):
            return []
        with open(path, 'r', encoding='utf-8') as f:
            data = json.load(f)
            return data if isinstance(data, list) else []

    def save_memorization_items(self, user_id: str, items: List[Dict[str, Any]]) -> None:
        """Persist ayah-level memorization items for user."""
        path = self._memorization_items_path(user_id)
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(items, f, indent=2, ensure_ascii=False)

    def upsert_memorization_item(self, user_id: str, item: Dict[str, Any]) -> None:
        """Insert or update memorization item by (surahNumber, ayahNumber)."""
        items = self.get_memorization_items(user_id)
        surah = int(item.get("surahNumber", 0))
        ayah = int(item.get("ayahNumber", 0))

        updated = False
        for idx, existing in enumerate(items):
            if int(existing.get("surahNumber", 0)) == surah and int(existing.get("ayahNumber", 0)) == ayah:
                items[idx] = item
                updated = True
                break

        if not updated:
            items.append(item)

        self.save_memorization_items(user_id, items)

    def get_memorization_item(self, user_id: str, surah_number: int, ayah_number: int) -> Optional[Dict[str, Any]]:
        """Get a single memorization item by surah/ayah."""
        items = self.get_memorization_items(user_id)
        for item in items:
            if int(item.get("surahNumber", 0)) == int(surah_number) and int(item.get("ayahNumber", 0)) == int(ayah_number):
                return item
        return None


# Global database instance
_db = None


def get_database(base_dir: str = "data") -> Database:
    """Get or create the global database instance"""
    global _db
    if _db is None:
        _db = Database(base_dir)
    return _db

