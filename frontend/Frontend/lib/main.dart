import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:tajweed_corrector/screens/Splash_Screen.dart';
import 'package:tajweed_corrector/services/sample_data_initializer.dart';
import 'package:tajweed_corrector/services/theme_service.dart';
import 'screens/Loginpage.dart';
import 'screens/NewHomeScreen_Gamified.dart'; // ← NEW GAMIFIED HOME SCREEN

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: "AIzaSyD8TjLoRt1PkX3qII-D_WQ3LlOLyvJjD38",
        authDomain: "tajweed-corrector.firebaseapp.com",
        projectId: "tajweed-corrector",
        storageBucket: "tajweed-corrector.firebasestorage.app",
        messagingSenderId: "974030449466",
        appId: "1:974030449466:web:014219569cef8db821be03",
      ),
    );
  } catch (e) {
    // Firebase already initialized (platform-side auto-init)
    print("Firebase already initialized: $e");
  }

  // Check if Firebase is working
  await checkFirebase();

  // Don't initialize lessons here - do it after user logs in
  // await SampleDataInitializer.initializeSampleLessons();

  runApp(const MyApp());
}

// Method to check if Firebase is working
Future<void> checkFirebase() async {
  try {
    // Just try to get the app instance
    FirebaseApp app = Firebase.app();
    print("✅ Firebase is working: ${app.name}");
  } catch (e) {
    print("❌ Firebase is NOT working: $e");
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppThemes.getLightTheme(),
            darkTheme: AppThemes.getDarkTheme(),
            themeMode: themeService.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If user is logged in, go to home
        if (snapshot.hasData && snapshot.data != null) {
          print('✅ User authenticated: ${snapshot.data!.email}');
          return const NewHomeScreen(); // ← NEW GAMIFIED HOME SCREEN
        }

        // If user is not logged in, go to login
        print('❌ User not authenticated');
        return const SplashScreen();
      },
    );
  }
}
