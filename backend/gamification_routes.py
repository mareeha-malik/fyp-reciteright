# -*- coding: utf-8 -*-
"""
Example Integration of Gamification Endpoints into Flask App
Add these routes to your existing app.py to enable gamification features
"""

from flask import Flask, request, jsonify
from gamification_service import get_gamification_service
from gamification_logic import (
    get_utc_today_date,
    get_week_start_date,
    LEVEL_TITLES,
)
import json
from datetime import datetime


def setup_gamification_routes(app: Flask):
    """Setup all gamification routes on the Flask app"""

    service = get_gamification_service()

    # ════════════════════════════════════════════════════════════════════════════════
    # PRIMARY ENDPOINT: Aggregated home screen metrics
    # ════════════════════════════════════════════════════════════════════════════════

    @app.route("/api/gamification/home-metrics", methods=["GET"])
    def get_home_metrics():
        """
        GET /api/gamification/home-metrics?userId=USER_ID

        Returns aggregated metrics for home screen in single call:
        {
            "isNewUser": bool,
            "daily": {
                "minutes": int,
                "goalMinutes": int,
                "completionRatio": float (0-1),
                "status": str
            },
            "streak": {
                "current": int,
                "longest": int
            },
            "week": {
                "totalMinutes": int,
                "daysActive": int,
                "averagePerDay": float,
                "dailyBreakdown": [{"date": str, "minutes": int}, ...]
            },
            "level": {
                "xp": int,
                "level": int,
                "levelTitle": str,
                "xpIntoLevel": int,
                "xpForNextLevel": int,
                "percentToNext": float (0-100)
            },
            "memorization": {
                "overallPercent": float,
                "topSurahs": [
                    {
                        "surahNumber": int,
                        "surahName": str,
                        "memorizedPercent": float,
                        "ayahCountMemorized": int,
                        "totalAyahs": int
                    },
                    ...
                ]
            },
            "lastSession": {
                "surah": int,
                "surahName": str,
                "startAyah": int,
                "endAyah": int,
                "lastRecitedAt": str (YYYY-MM-DD),
                "accuracyScore": float,
                "durationMinutes": float
            } or null
        }
        """
        try:
            user_id = request.args.get("userId")
            if not user_id:
                return jsonify({"error": "userId required"}), 400

            # Get user profile from database (implement your own)
            user_profile = {
                "daily_goal_minutes": 10,
                "xp": 0,
                "longest_streak": 0,
                "joined_at": datetime.utcnow().isoformat() + "Z",
            }

            today_date = get_utc_today_date(timezone_offset_minutes=0)
            metrics = service.get_home_metrics(user_id, user_profile, today_date)

            return jsonify(metrics.to_dict()), 200

        except Exception as e:
            print(f"❌ Error in get_home_metrics: {e}")
            return jsonify({"error": str(e)}), 500


    # ════════════════════════════════════════════════════════════════════════════════
    # POST SESSION: Record new session after recitation
    # ════════════════════════════════════════════════════════════════════════════════

    @app.route("/api/gamification/session", methods=["POST"])
    def record_session():
        """
        POST /api/gamification/session

        Body:
        {
            "userId": str,
            "surah": int,
            "startAyah": int,
            "endAyah": int,
            "durationMinutes": float,
            "accuracyScore": float (0-100),
            "mode": str ("recitation" | "tajweed_lesson" | "review")
        }

        Returns:
        {
            "success": bool,
            "sessionId": str,
            "xpEarned": int,
            "levelUp": bool,
            "newLevel": int,
            "totalXp": int,
            "message": str
        }
        """
        try:
            data = request.get_json()
            user_id = data.get("userId")

            if not user_id:
                return jsonify({"error": "userId required"}), 400

            # Create session object
            from gamification_models import Session
            import uuid
            from datetime import datetime

            session_id = str(uuid.uuid4())
            today_date = get_utc_today_date(timezone_offset_minutes=0)

            session = Session(
                id=session_id,
                user_id=user_id,
                surah=data.get("surah"),
                start_ayah=data.get("startAyah"),
                end_ayah=data.get("endAyah"),
                duration_minutes=float(data.get("durationMinutes", 0)),
                date=today_date,
                accuracy_score=float(data.get("accuracyScore", 0)),
                mode=data.get("mode", "recitation"),
                created_at=datetime.utcnow().isoformat() + "Z",
            )

            # Add session
            service.add_session(user_id, session.to_dict())

            # Calculate XP
            daily_goal_met = False  # Check this from daily progress
            xp_earned = 0  # Implement XP calculation
            from gamification_logic import calculate_xp_for_session
            xp_earned = calculate_xp_for_session(session, daily_goal_met)

            return jsonify({
                "success": True,
                "sessionId": session_id,
                "xpEarned": xp_earned,
                "levelUp": False,  # Implement level-up logic
                "newLevel": 1,
                "totalXp": xp_earned,
                "message": f"Session recorded! +{xp_earned} XP earned"
            }), 201

        except Exception as e:
            print(f"❌ Error recording session: {e}")
            return jsonify({"error": str(e)}), 500


    # ════════════════════════════════════════════════════════════════════════════════
    # DAILY PROGRESS
    # ════════════════════════════════════════════════════════════════════════════════

    @app.route("/api/gamification/daily-progress", methods=["GET"])
    def get_daily_progress():
        """
        GET /api/gamification/daily-progress?userId=USER_ID&date=YYYY-MM-DD

        Returns daily progress metrics
        """
        try:
            user_id = request.args.get("userId")
            date_str = request.args.get("date")
            daily_goal = int(request.args.get("dailyGoal", 10))

            if not user_id or not date_str:
                return jsonify({"error": "userId and date required"}), 400

            sessions = service.sessions.get(user_id, [])
            from gamification_logic import get_today_progress
            daily = get_today_progress(sessions, date_str, daily_goal)

            return jsonify(daily), 200

        except Exception as e:
            print(f"❌ Error getting daily progress: {e}")
            return jsonify({"error": str(e)}), 500


    # ════════════════════════════════════════════════════════════════════════════════
    # WEEK SUMMARY
    # ════════════════════════════════════════════════════════════════════════════════

    @app.route("/api/gamification/week-summary", methods=["GET"])
    def get_week_summary():
        """
        GET /api/gamification/week-summary?userId=USER_ID&weekStart=YYYY-MM-DD

        Returns weekly progress metrics
        """
        try:
            user_id = request.args.get("userId")
            week_start = request.args.get("weekStart")

            if not user_id or not week_start:
                return jsonify({"error": "userId and weekStart required"}), 400

            sessions = service.sessions.get(user_id, [])
            from gamification_logic import get_week_summary as calc_week
            week = calc_week(sessions, week_start)

            return jsonify(week), 200

        except Exception as e:
            print(f"❌ Error getting week summary: {e}")
            return jsonify({"error": str(e)}), 500


    # ════════════════════════════════════════════════════════════════════════════════
    # STREAK
    # ════════════════════════════════════════════════════════════════════════════════

    @app.route("/api/gamification/streak", methods=["GET"])
    def get_streak():
        """
        GET /api/gamification/streak?userId=USER_ID

        Returns streak information
        """
        try:
            user_id = request.args.get("userId")
            if not user_id:
                return jsonify({"error": "userId required"}), 400

            sessions = service.sessions.get(user_id, [])
            today_date = get_utc_today_date()
            from gamification_logic import get_current_streak
            streak_info = get_current_streak(sessions, today_date)

            return jsonify(streak_info.to_dict()), 200

        except Exception as e:
            print(f"❌ Error getting streak: {e}")
            return jsonify({"error": str(e)}), 500


    # ════════════════════════════════════════════════════════════════════════════════
    # LEVEL INFO
    # ════════════════════════════════════════════════════════════════════════════════

    @app.route("/api/gamification/level", methods=["GET"])
    def get_level():
        """
        GET /api/gamification/level?userId=USER_ID

        Returns level and XP information
        """
        try:
            user_id = request.args.get("userId")
            if not user_id:
                return jsonify({"error": "userId required"}), 400

            # Get XP from user profile (implement your own)
            total_xp = 0  # Fetch from DB

            from gamification_logic import get_level_from_xp
            level_info = get_level_from_xp(total_xp)

            return jsonify({
                **level_info.to_dict(),
                "levelTitle": LEVEL_TITLES.get(level_info.level_number, "Scholar")
            }), 200

        except Exception as e:
            print(f"❌ Error getting level: {e}")
            return jsonify({"error": str(e)}), 500


    # ════════════════════════════════════════════════════════════════════════════════
    # MEMORIZATION PROGRESS
    # ════════════════════════════════════════════════════════════════════════════════

    @app.route("/api/gamification/memorization", methods=["GET"])
    def get_memorization():
        """
        GET /api/gamification/memorization?userId=USER_ID

        Returns memorization progress
        """
        try:
            user_id = request.args.get("userId")
            if not user_id:
                return jsonify({"error": "userId required"}), 400

            memo_progress = service.memorization_progress.get(user_id, {})
            from gamification_logic import (
                get_overall_memorization_percent,
                get_top_surahs
            )

            overall = get_overall_memorization_percent(memo_progress)
            top_surahs = get_top_surahs(memo_progress)

            return jsonify({
                "overallPercent": overall,
                "topSurahs": top_surahs
            }), 200

        except Exception as e:
            print(f"❌ Error getting memorization: {e}")
            return jsonify({"error": str(e)}), 500


    # ════════════════════════════════════════════════════════════════════════════════
    # UPDATE DAILY GOAL
    # ════════════════════════════════════════════════════════════════════════════════

    @app.route("/api/gamification/daily-goal", methods=["PUT"])
    def update_daily_goal():
        """
        PUT /api/gamification/daily-goal

        Body:
        {
            "userId": str,
            "dailyGoalMinutes": int
        }
        """
        try:
            data = request.get_json()
            user_id = data.get("userId")
            new_goal = data.get("dailyGoalMinutes", 10)

            if not user_id:
                return jsonify({"error": "userId required"}), 400

            # Update in database (implement your own)
            return jsonify({
                "success": True,
                "dailyGoalMinutes": new_goal
            }), 200

        except Exception as e:
            print(f"❌ Error updating daily goal: {e}")
            return jsonify({"error": str(e)}), 500


# ════════════════════════════════════════════════════════════════════════════════
# INTEGRATION EXAMPLE
# ════════════════════════════════════════════════════════════════════════════════
#
# In your main app.py after creating Flask app:
#
#   app = Flask(__name__)
#   CORS(app)
#
#   # ... existing routes ...
#
#   # Setup gamification routes
#   from gamification_routes import setup_gamification_routes
#   setup_gamification_routes(app)
#
#   if __name__ == "__main__":
#       app.run(debug=True, port=8000, host="0.0.0.0")
#
# ════════════════════════════════════════════════════════════════════════════════

