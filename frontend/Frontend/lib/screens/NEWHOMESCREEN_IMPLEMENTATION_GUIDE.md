# NewHomeScreen Implementation Guide

## Quick Start

### 1. Integration Steps

#### Step 1: Import in Main.dart
```dart
import 'package:tajweed_corrector/screens/NewHomeScreen.dart';
```

#### Step 2: Replace Current Home Route
In your `main.dart`, replace the current home screen with:
```dart
home: const NewHomeScreen(),
// OR if using a router/navigator, update the route to point to NewHomeScreen
```

#### Step 3: Verify Dependencies
All required packages are already in `pubspec.yaml`:
- `flutter` (base)
- `firebase_auth` (user data)
- `cloud_firestore` (profile data)
- `provider` (optional state management)

### 2. Running the Screen

```bash
# In the frontend/Frontend directory
flutter pub get
flutter run
```

---

## Code Structure Overview

### Widget Hierarchy
```
NewHomeScreen (StatefulWidget)
├── Scaffold
│   ├── Body: SingleChildScrollView
│   │   └── Column
│   │       ├── _buildHeader()
│   │       ├── _buildHeroCard()
│   │       ├── _buildProgressRow()
│   │       ├── _buildTodayLessonCard()
│   │       ├── _buildQuickActionsGrid()
│   │       └── _buildRecentActivitySection()
│   └── BottomNavigationBar
│       └── 4 Navigation Items
```

### State Variables
```dart
String _userName = 'User'                          // User's name
String? _userAvatar                                // User's avatar URL
int _currentStreak = 0                             // Recitation streak days
int _dailyGoalMinutes = 10                         // Daily goal minutes
double _todayProgress = 0.0                        // Today's progress minutes
double _weekProgress = 75.0                        // Weekly progress percentage
String _nextSurah = 'Al-Baqarah'                   // Next surah to recite
int _nextAyah = 5                                  // Next ayah number
String _todayLessonRule = 'Ghunnah'                // Today's lesson rule
String _todayLessonDescription = '...'             // Lesson description
bool _isDarkMode = false                           // Dark mode toggle
```

---

## Customization Guide

### 1. Change Colors

**Primary Blue Theme**:
```dart
// In _buildHeroCard()
gradient: LinearGradient(
  colors: [
    const Color(0xFF1E4976),    // Change this hex value
    const Color(0xFF2E5F8F),    // Change this hex value
  ],
)
```

**Quick Action Tile Colors**:
```dart
// In _buildQuickActionsGrid(), update the 'color' value:
{
  'label': 'Tajweed\nLessons',
  'icon': Icons.school,
  'color': const Color(0xFF673AB7),  // Change hex color
  'onTap': () { ... }
}
```

### 2. Change Text Content

**Greeting Message**:
```dart
Text(
  'Assalam-o-Alaikum, $_userName 👋',
  // Change emoji or greeting text here
)
```

**Daily Goal Subtitle**:
```dart
Text(
  "Let's recite for $_dailyGoalMinutes minutes today.",
  // Customize this message
)
```

**Section Titles**:
```dart
Text(
  "Continue Where You Left Off",  // Or change to your preferred text
)
```

### 3. Change Button Actions

**Start Recitation Button**:
```dart
onPressed: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const EnhancedReciteScreen(),  // Change target
    ),
  );
}
```

### 4. Change Icon Choices

**Quick Action Icons**:
```dart
// In _buildQuickActionsGrid(), change the 'icon' value:
{
  'label': 'Tajweed\nLessons',
  'icon': Icons.school,  // Change to Icons.book, Icons.lightbulb, etc.
}
```

### 5. Modify Layout Spacing

**Card Padding**:
```dart
padding: const EdgeInsets.all(16),  // Change 16 to desired padding
```

**Section Spacing**:
```dart
const SizedBox(height: 24),  // Change 24 to desired vertical space
```

**Row/Grid Gap**:
```dart
crossAxisSpacing: 12,  // Change gap between columns
mainAxisSpacing: 12,   // Change gap between rows
```

### 6. Dark Mode Customization

**Override Dark Colors**:
```dart
final cardColor = isDark 
  ? const Color(0xFF333333)  // Change this color
  : Colors.white;
```

**Theme Persistence**:
Currently, theme toggle only lasts for the session. To persist:
```dart
import 'package:shared_preferences/shared_preferences.dart';

// In _toggleTheme():
Future<void> _toggleTheme() async {
  final prefs = await SharedPreferences.getInstance();
  setState(() {
    _isDarkMode = !_isDarkMode;
  });
  await prefs.setBool('isDarkMode', _isDarkMode);
}

// In initState():
Future<void> _loadThemePreference() async {
  final prefs = await SharedPreferences.getInstance();
  setState(() {
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
  });
}
```

---

## Data Integration

### 1. Load Real User Data

**Current Implementation**:
```dart
Future<void> _loadUserData() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _userName = 'Guest');
      return;
    }

    final profile = await _userService.getUserProfile();
    String fullName = profile?['fullName'] ?? user.displayName ?? 'User';
    String? avatarUrl = profile?['avatarUrl'];

    setState(() {
      _userName = fullName;
      _userAvatar = avatarUrl;
    });
  } catch (e) {
    print('Error loading user data: $e');
  }
}
```

**To Add Additional Data**:
```dart
// Add more fields to Firestore profile
await FirebaseFirestore.instance
    .collection('users')
    .doc(user.uid)
    .set({
      'fullName': fullName,
      'avatarUrl': avatarUrl,
      'streak': 5,              // Add this
      'dailyGoalMinutes': 10,   // Add this
      'todayMinutes': 3,        // Add this
    });

// Then load in _loadUserData():
setState(() {
  _currentStreak = profile?['streak'] ?? 0;
  _dailyGoalMinutes = profile?['dailyGoalMinutes'] ?? 10;
});
```

### 2. Connect to Backend API

**Get Today's Lesson Recommendation**:
```dart
Future<void> _loadTodayLesson() async {
  try {
    final response = await http.get(
      Uri.parse('http://your-backend:8000/api/daily-lesson'),
      headers: {'Authorization': 'Bearer $token'},
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _todayLessonRule = data['rule_name'];
        _todayLessonDescription = data['description'];
      });
    }
  } catch (e) {
    print('Error loading today\'s lesson: $e');
  }
}
```

### 3. Fetch Progress Statistics

**Current**: Using StatsService (already integrated)

**To Customize**:
```dart
Future<void> _loadProgressData() async {
  try {
    final stats = await _statsService.getUserStats();
    setState(() {
      _currentStreak = stats['streak'] ?? 0;
      _todayProgress = (stats['todayMinutes'] ?? 0).toDouble();
      _weekProgress = (stats['weekProgress'] ?? 75.0).toDouble();
    });
  } catch (e) {
    print('Error loading progress data: $e');
  }
}
```

---

## Testing Scenarios

### 1. Test Data Setup

**Scenario A: New User**
```dart
// Override initial state for testing:
_userName = 'Ahmed';
_currentStreak = 0;
_todayProgress = 0.0;
```

**Scenario B: Active User**
```dart
_userName = 'Eman';
_currentStreak = 7;
_todayProgress = 8.5;
_weekProgress = 95.0;
```

**Scenario C: Streaking User**
```dart
_userName = 'Karim';
_currentStreak = 21;
_todayProgress = 12.0;
_weekProgress = 100.0;
```

### 2. Test Dark Mode

```dart
// In debugPrint, add to test dark mode:
// 1. Tap theme toggle button (top-right)
// 2. Verify all text colors invert
// 3. Verify card backgrounds darken
// 4. Verify icons remain visible
// 5. Verify button text contrast is maintained
```

### 3. Test Responsive Layouts

```
Device Sizes to Test:
- Pixel 4a: 360×800 (small Android)
- Pixel 6: 412×915 (standard Android)
- Galaxy Note: 360×800 (older Android)
- iPad: 1024×1366 (tablet, if supported)
```

### 4. Test Navigation

```
Navigation Flows to Verify:
1. Hero CTA → EnhancedReciteScreen
2. Change Surah → SurahListScreen
3. Progress cards → EnhancedProgressScreen
4. Lesson card → TajweedLessonsScreen
5. Quick action tiles → Respective screens
6. Recent activity items → Resume session
7. Bottom nav items → Each destination
8. Profile avatar → ProfileScreen
```

---

## Performance Optimization

### 1. Lazy Load Data
```dart
@override
void initState() {
  super.initState();
  // Load critical data immediately
  _loadUserData();
  
  // Defer non-critical data
  Future.delayed(const Duration(milliseconds: 500), _loadProgressData);
}
```

### 2. Cache User Data
```dart
// Add caching to _loadUserData():
final cachedName = await _getUserFromCache();
if (cachedName != null) {
  setState(() => _userName = cachedName);
}
// Then refresh from Firestore in background
```

### 3. Reduce Rebuilds
```dart
// Use const where possible:
const Text('Start Recitation')  // Not rebuilt on state change
```

### 4. Image Optimization
```dart
// For avatar images, use caching:
Image.network(
  _userAvatar!,
  fit: BoxFit.cover,
  cacheHeight: 40,  // Cache at small size
  cacheWidth: 40,
)
```

---

## Troubleshooting

### Issue: Avatar not loading

**Solution**:
```dart
// Check if URL is valid
if (_userAvatar != null && _userAvatar!.isNotEmpty) {
  // Try to load
} else {
  // Show default avatar
}

// Add error handler:
Image.network(
  _userAvatar!,
  fit: BoxFit.cover,
  errorBuilder: (context, error, stackTrace) {
    return const Icon(Icons.person);  // Fallback
  },
)
```

### Issue: Theme doesn't persist after restart

**Solution**:
Implement theme persistence using SharedPreferences (see code above).

### Issue: Streak badge not showing

**Solution**:
```dart
// Check condition:
if (_currentStreak > 0)  // Only show if streak exists
  Container(...)
```

### Issue: Layout overflow on small devices

**Solution**:
```dart
// Use SingleChildScrollView (already implemented)
// Reduce padding on small screens:
double horizontalPadding = MediaQuery.of(context).size.width < 360 ? 12 : 16;
```

---

## Adding New Features

### 1. Add a New Quick Action Tile

```dart
// In _buildQuickActionsGrid(), add to quickActions list:
{
  'label': 'My New\nFeature',
  'icon': Icons.star,
  'color': const Color(0xFFFF5722),
  'onTap': () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MyNewScreen()),
    );
  },
}
```

### 2. Add Recent Activity Item

```dart
// Modify _buildRecentActivitySection():
final recentActivities = [
  { 'title': 'Activity 1', 'subtitle': 'Time', 'icon': Icons.icon1 },
  { 'title': 'Activity 2', 'subtitle': 'Time', 'icon': Icons.icon2 },
  { 'title': 'Activity 3', 'subtitle': 'Time', 'icon': Icons.icon3 },
  // Add more...
];
```

### 3. Add New Card Section

```dart
// Add new widget builder:
Widget _buildMyNewCard() {
  return Container(
    decoration: BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(12),
    ),
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        // Your content
      ],
    ),
  );
}

// Add to Column in build():
const SizedBox(height: 24),
_buildMyNewCard(),
```

---

## Best Practices

### 1. Color Accessibility
- Always test with WCAG contrast checker
- Avoid pure red/green combinations for colorblind users
- Use icons + text, never color alone

### 2. Typography
- Keep font sizes consistent (use design scale)
- Limit to 2-3 font sizes per screen
- Ensure minimum 12px for body text

### 3. Spacing
- Use 8px, 12px, 16px, 20px, 24px increments
- Maintain consistent padding across cards
- Use SizedBox for explicit spacing (not margins)

### 4. Naming Conventions
```dart
// Widget builders: _build[ComponentName]()
Widget _buildHeroCard() { }

// Helper methods: _[action][What]()
Future<void> _loadUserData() { }

// State variables: _[descriptiveName]
String _userName = 'User';
```

### 5. Error Handling
```dart
// Always wrap Firestore calls:
try {
  final data = await _userService.getUserProfile();
} catch (e) {
  print('Error: $e');
  // Show user-friendly error or use default value
}
```

---

## Deployment Checklist

- [ ] All imports are correctly resolved
- [ ] No console errors or warnings
- [ ] Dark mode tested and working
- [ ] Responsive on target devices (360px minimum)
- [ ] All navigation routes working
- [ ] User data loads correctly
- [ ] Progress data updates
- [ ] Theme toggle persists (if implemented)
- [ ] No layout overflow on small screens
- [ ] Tap targets are 48px minimum
- [ ] Images load with error fallbacks
- [ ] Strings are externalized (i18n ready)
- [ ] Performance acceptable (< 1s load time)
- [ ] Accessibility tested (colors, text size)
- [ ] Bottom navigation works on all screens

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Apr 2026 | Initial design & implementation |
| 2.0 | TBD | Dark mode persistence, caching |
| 3.0 | TBD | Personalized lessons, animations |

---

## Support & Resources

### Related Files
- Design Doc: `NEW_HOME_SCREEN_DESIGN.md`
- Implementation: `lib/screens/NewHomeScreen.dart`
- Services: `lib/services/user_service.dart`, `lib/services/stats_service.dart`

### Flutter Docs
- [StatefulWidget](https://api.flutter.dev/flutter/widgets/StatefulWidget-class.html)
- [Bottom Navigation](https://api.flutter.dev/flutter/material/BottomNavigationBar-class.html)
- [GridView](https://api.flutter.dev/flutter/widgets/GridView-class.html)
- [Material Design](https://material.io/design)

### Contact
For questions or bugs, reach out to the development team.

---

Last Updated: April 2026

