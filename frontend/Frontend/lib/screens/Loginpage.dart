// import 'dart:async';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:tajweed_corrector/services/auth_service.dart';
// import 'package:tajweed_corrector/screens/SignUpScreen.dart';
// import 'package:tajweed_corrector/utils/responsive_helper.dart';

// class LoginScreen extends StatefulWidget {
//   const LoginScreen({super.key});

//   @override
//   State<LoginScreen> createState() => _LoginScreenState();
// }

// class _LoginScreenState extends State<LoginScreen> {
//   final AuthService _authService = AuthService();
//   final TextEditingController _emailController = TextEditingController();
//   final TextEditingController _passwordController = TextEditingController();
//   bool _isLoading = false;
//   bool _obscurePassword = true;
//   late StreamSubscription<User?> _authSubscription;

//   final _formKey = GlobalKey<FormState>();

//   @override
//   void initState() {
//     super.initState();
//     // Listen to auth state changes and navigate to home when user is authenticated
//     _authSubscription = FirebaseAuth.instance.authStateChanges().listen((
//       User? user,
//     ) {
//       if (user != null && mounted) {
//         print('✅ Auth state changed - User authenticated: ${user.email}');
//         // Navigate to home screen and remove login screen from stack
//         Navigator.of(
//           context,
//         ).pushNamedAndRemoveUntil('/home', (route) => false);
//       }
//     });
//   }

//   @override
//   void dispose() {
//     _authSubscription.cancel();
//     _emailController.dispose();
//     _passwordController.dispose();
//     super.dispose();
//   }

//   Future<void> _handleLogin() async {
//     if (!_formKey.currentState!.validate()) {
//       return;
//     }

//     setState(() => _isLoading = true);

//     try {
//       print('🔄 Starting login process for: ${_emailController.text.trim()}');

//       User? user = await _authService.login(
//         email: _emailController.text.trim(),
//         password: _passwordController.text,
//       );

//       if (user != null && mounted) {
//         print('✅ Login successful: ${user.email}');
//         // AuthWrapper in main.dart will automatically handle navigation to home screen
//         // Show success message
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Welcome back, ${user.email}!'),
//             backgroundColor: Colors.green,
//             duration: const Duration(seconds: 2),
//           ),
//         );
//       }
//     } catch (e) {
//       print('❌ Login error: $e');
//       if (mounted) {
//         _showErrorDialog(e.toString());
//       }
//     } finally {
//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     }
//   }

//   void _showErrorDialog(String message) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Login Error'),
//         content: Text(message),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('OK'),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _handleGoogleSignIn() async {
//     setState(() => _isLoading = true);

//     try {
//       print('🔄 Starting Google Sign-In from UI');
//       User? user = await _authService.signInWithGoogle();

//       if (user != null && mounted) {
//         print('✅ Google Sign-In successful: ${user.email}');
//         // AuthWrapper in main.dart will automatically handle navigation to home screen
//         // Show success message
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Welcome, ${user.displayName ?? user.email}!'),
//             backgroundColor: Colors.green,
//             duration: const Duration(seconds: 2),
//           ),
//         );
//       }
//     } catch (e) {
//       print('❌ Google Sign-In error: $e');
//       if (mounted) {
//         _showErrorDialog(e.toString());
//       }
//     } finally {
//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     }
//   }

//   String? _validateEmail(String? value) {
//     if (value == null || value.isEmpty) {
//       return 'Please enter your email';
//     }
//     final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
//     if (!emailRegex.hasMatch(value)) {
//       return 'Please enter a valid email address';
//     }
//     return null;
//   }

//   String? _validatePassword(String? value) {
//     if (value == null || value.isEmpty) {
//       return 'Please enter your password';
//     }
//     if (value.length < 6) {
//       return 'Password must be at least 6 characters';
//     }
//     return null;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return ResponsiveBuilder(
//       builder: (context, screenType) {
//         final size = MediaQuery.of(context).size;
//         final horizontalPadding =
//             ResponsiveHelper.getResponsiveHorizontalPadding(context);
//         final containerWidth = ResponsiveHelper.getResponsiveContainerWidth(
//           context,
//         );
//         final logoWidth = ResponsiveHelper.getResponsiveImageWidth(context);
//         final buttonHeight = ResponsiveHelper.getResponsiveButtonHeight(
//           context,
//         );
//         final titleFontSize = ResponsiveHelper.getResponsiveFontSize(
//           context,
//           mobileSize: 20,
//           tabletSize: 24,
//           desktopSize: 28,
//         );
//         final fieldFontSize = ResponsiveHelper.getResponsiveFontSize(
//           context,
//           mobileSize: 14,
//           tabletSize: 16,
//           desktopSize: 18,
//         );
//         final spacing = ResponsiveHelper.getResponsiveSpacing(context);
//         final borderRadius = ResponsiveHelper.getResponsiveBorderRadius(
//           context,
//         );

//         return Scaffold(
//           body: Container(
//             width: double.infinity,
//             height: double.infinity,
//             decoration: const BoxDecoration(
//               gradient: LinearGradient(
//                 begin: Alignment.topCenter,
//                 end: Alignment.bottomCenter,
//                 colors: [Color(0xFFE8F5E9), Color(0xFFA5D6A7)],
//               ),
//             ),
//             child: Stack(
//               children: [
//                 // 🌿 Background image
//                 Positioned(
//                   top: 0,
//                   left: 0,
//                   right: 0,
//                   child: Opacity(
//                     opacity: 0.4,
//                     child: Image.asset(
//                       "assets/g4.png",
//                       fit: BoxFit.fitWidth,
//                       width: size.width,
//                       alignment: Alignment.topCenter,
//                     ),
//                   ),
//                 ),

//                 // 🌿 Main content
//                 Center(
//                   child: SingleChildScrollView(
//                     padding: EdgeInsets.symmetric(
//                       horizontal: horizontalPadding,
//                       vertical: size.height * 0.05,
//                     ),
//                     child: SizedBox(
//                       width: containerWidth,
//                       child: Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           // Logo
//                           Image.asset("assets/g6.png", width: logoWidth),
//                           SizedBox(
//                             height: ResponsiveHelper.getResponsiveSpacing(
//                               context,
//                               mobileSpacing: 16,
//                               tabletSpacing: 20,
//                               desktopSpacing: 24,
//                             ),
//                           ),

//                           // Title
//                           Text(
//                             "Let's begin your journey!",
//                             style: TextStyle(
//                               color: const Color(0xFF8B5E3C),
//                               fontSize: titleFontSize,
//                               fontWeight: FontWeight.w600,
//                             ),
//                             textAlign: TextAlign.center,
//                           ),

//                           SizedBox(
//                             height: ResponsiveHelper.getResponsiveSpacing(
//                               context,
//                               mobileSpacing: 20,
//                               tabletSpacing: 28,
//                               desktopSpacing: 32,
//                             ),
//                           ),

//                           // Login Card
//                           Container(
//                             width: double.infinity,
//                             padding: EdgeInsets.symmetric(
//                               horizontal: horizontalPadding * 0.8,
//                               vertical: ResponsiveHelper.getResponsiveSpacing(
//                                 context,
//                                 mobileSpacing: 20,
//                                 tabletSpacing: 28,
//                                 desktopSpacing: 32,
//                               ),
//                             ),
//                             decoration: BoxDecoration(
//                               color: Colors.white.withOpacity(0.95),
//                               borderRadius: BorderRadius.circular(
//                                 borderRadius + 10,
//                               ),
//                               boxShadow: [
//                                 BoxShadow(
//                                   color: Colors.black26.withOpacity(0.1),
//                                   blurRadius: 10,
//                                   offset: const Offset(0, 4),
//                                 ),
//                               ],
//                             ),
//                             child: Form(
//                               key: _formKey,
//                               child: Column(
//                                 children: [
//                                   // Email Field
//                                   TextFormField(
//                                     controller: _emailController,
//                                     keyboardType: TextInputType.emailAddress,
//                                     enabled: !_isLoading,
//                                     validator: _validateEmail,
//                                     decoration: InputDecoration(
//                                       labelText: "E-mail address",
//                                       hintText: "Enter email here",
//                                       labelStyle: TextStyle(
//                                         color: const Color(0xFF8B5E3C),
//                                         fontSize: fieldFontSize,
//                                       ),
//                                       focusedBorder: OutlineInputBorder(
//                                         borderSide: const BorderSide(
//                                           color: Color(0xFF8B5E3C),
//                                           width: 1.5,
//                                         ),
//                                         borderRadius: BorderRadius.circular(
//                                           borderRadius,
//                                         ),
//                                       ),
//                                       enabledBorder: OutlineInputBorder(
//                                         borderSide: const BorderSide(
//                                           color: Color(0xFF8B5E3C),
//                                           width: 1.0,
//                                         ),
//                                         borderRadius: BorderRadius.circular(
//                                           borderRadius,
//                                         ),
//                                       ),
//                                       errorBorder: OutlineInputBorder(
//                                         borderSide: const BorderSide(
//                                           color: Colors.red,
//                                           width: 1.0,
//                                         ),
//                                         borderRadius: BorderRadius.circular(
//                                           borderRadius,
//                                         ),
//                                       ),
//                                       focusedErrorBorder: OutlineInputBorder(
//                                         borderSide: const BorderSide(
//                                           color: Colors.red,
//                                           width: 1.5,
//                                         ),
//                                         borderRadius: BorderRadius.circular(
//                                           borderRadius,
//                                         ),
//                                       ),
//                                     ),
//                                   ),
//                                   SizedBox(height: spacing * 2),

//                                   // Password Field
//                                   TextFormField(
//                                     controller: _passwordController,
//                                     obscureText: _obscurePassword,
//                                     enabled: !_isLoading,
//                                     validator: _validatePassword,
//                                     decoration: InputDecoration(
//                                       labelText: "Password",
//                                       hintText: "Enter Password here",
//                                       labelStyle: TextStyle(
//                                         color: const Color(0xFF8B5E3C),
//                                         fontSize: fieldFontSize,
//                                       ),
//                                       suffixIcon: IconButton(
//                                         icon: Icon(
//                                           _obscurePassword
//                                               ? Icons.visibility_off
//                                               : Icons.visibility,
//                                           color: const Color(0xFF8B5E3C),
//                                         ),
//                                         onPressed: () {
//                                           setState(
//                                             () => _obscurePassword =
//                                                 !_obscurePassword,
//                                           );
//                                         },
//                                       ),
//                                       focusedBorder: OutlineInputBorder(
//                                         borderSide: const BorderSide(
//                                           color: Color(0xFF8B5E3C),
//                                           width: 1.5,
//                                         ),
//                                         borderRadius: BorderRadius.circular(
//                                           borderRadius,
//                                         ),
//                                       ),
//                                       enabledBorder: OutlineInputBorder(
//                                         borderSide: const BorderSide(
//                                           color: Color(0xFF8B5E3C),
//                                           width: 1.0,
//                                         ),
//                                         borderRadius: BorderRadius.circular(
//                                           borderRadius,
//                                         ),
//                                       ),
//                                       errorBorder: OutlineInputBorder(
//                                         borderSide: const BorderSide(
//                                           color: Colors.red,
//                                           width: 1.0,
//                                         ),
//                                         borderRadius: BorderRadius.circular(
//                                           borderRadius,
//                                         ),
//                                       ),
//                                       focusedErrorBorder: OutlineInputBorder(
//                                         borderSide: const BorderSide(
//                                           color: Colors.red,
//                                           width: 1.5,
//                                         ),
//                                         borderRadius: BorderRadius.circular(
//                                           borderRadius,
//                                         ),
//                                       ),
//                                     ),
//                                   ),
//                                   SizedBox(height: spacing),

//                                   // SignUp Text
//                                   Wrap(
//                                     alignment: WrapAlignment.center,
//                                     children: [
//                                       const Text(
//                                         "Don't have an account? ",
//                                         style: TextStyle(
//                                           color: Colors.grey,
//                                           fontSize: 13,
//                                         ),
//                                       ),
//                                       GestureDetector(
//                                         onTap: _isLoading
//                                             ? null
//                                             : () {
//                                                 Navigator.push(
//                                                   context,
//                                                   MaterialPageRoute(
//                                                     builder: (context) =>
//                                                         const SignUpScreen(),
//                                                   ),
//                                                 );
//                                               },
//                                         child: Text(
//                                           "Sign Up",
//                                           style: TextStyle(
//                                             color: _isLoading
//                                                 ? Colors.grey
//                                                 : const Color(0xFF388E3C),
//                                             fontWeight: FontWeight.bold,
//                                           ),
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                   SizedBox(height: spacing * 2.5),

//                                   // Log In Button
//                                   SizedBox(
//                                     width: double.infinity,
//                                     height: buttonHeight,
//                                     child: ElevatedButton(
//                                       style: ElevatedButton.styleFrom(
//                                         backgroundColor: const Color(
//                                           0xFF388E3C,
//                                         ),
//                                         shape: RoundedRectangleBorder(
//                                           borderRadius: BorderRadius.circular(
//                                             borderRadius,
//                                           ),
//                                         ),
//                                       ),
//                                       onPressed: _isLoading
//                                           ? null
//                                           : _handleLogin,
//                                       child: _isLoading
//                                           ? const SizedBox(
//                                               height: 20,
//                                               width: 20,
//                                               child: CircularProgressIndicator(
//                                                 valueColor:
//                                                     AlwaysStoppedAnimation<
//                                                       Color
//                                                     >(Colors.white),
//                                               ),
//                                             )
//                                           : Text(
//                                               "Log In",
//                                               style: TextStyle(
//                                                 color: Colors.white,
//                                                 fontSize: fieldFontSize,
//                                               ),
//                                             ),
//                                     ),
//                                   ),
//                                   SizedBox(height: spacing * 2),

//                                   // Divider
//                                   Row(
//                                     children: [
//                                       const Expanded(
//                                         child: Divider(thickness: 1),
//                                       ),
//                                       Padding(
//                                         padding: EdgeInsets.symmetric(
//                                           horizontal: spacing,
//                                         ),
//                                         child: const Text("OR"),
//                                       ),
//                                       const Expanded(
//                                         child: Divider(thickness: 1),
//                                       ),
//                                     ],
//                                   ),
//                                   SizedBox(height: spacing * 2),

//                                   // Google Sign-in Button
//                                   GestureDetector(
//                                     onTap: _isLoading
//                                         ? null
//                                         : _handleGoogleSignIn,
//                                     child: Container(
//                                       padding: EdgeInsets.symmetric(
//                                         horizontal: spacing,
//                                         vertical: spacing * 0.8,
//                                       ),
//                                       decoration: BoxDecoration(
//                                         border: Border.all(color: Colors.grey),
//                                         borderRadius: BorderRadius.circular(
//                                           borderRadius,
//                                         ),
//                                       ),
//                                       child: Row(
//                                         mainAxisAlignment:
//                                             MainAxisAlignment.center,
//                                         children: [
//                                           Image.network(
//                                             'https://cdn-icons-png.flaticon.com/512/281/281764.png',
//                                             width:
//                                                 ResponsiveHelper.getResponsiveIconSize(
//                                                   context,
//                                                 ),
//                                             height:
//                                                 ResponsiveHelper.getResponsiveIconSize(
//                                                   context,
//                                                 ),
//                                           ),
//                                           SizedBox(width: spacing),
//                                           Flexible(
//                                             child: Text(
//                                               _isLoading
//                                                   ? "Signing in..."
//                                                   : "Continue with Google",
//                                               style: TextStyle(
//                                                 fontSize: fieldFontSize,
//                                               ),
//                                               overflow: TextOverflow.ellipsis,
//                                             ),
//                                           ),
//                                         ],
//                                       ),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                           SizedBox(
//                             height: ResponsiveHelper.getResponsiveSpacing(
//                               context,
//                               mobileSpacing: 20,
//                               tabletSpacing: 28,
//                               desktopSpacing: 32,
//                             ),
//                           ),

//                           // Bottom icon
//                           Icon(
//                             Icons.graphic_eq_rounded,
//                             color: Colors.green.shade700,
//                             size: ResponsiveHelper.getResponsiveIconSize(
//                               context,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
// }

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tajweed_corrector/services/auth_service.dart';
import 'package:tajweed_corrector/screens/SignUpScreen.dart';
import 'package:tajweed_corrector/utils/responsive_helper.dart';
import 'package:tajweed_corrector/screens/NewHomeScreen_Gamified.dart';
import 'package:tajweed_corrector/widgets/index.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  late StreamSubscription<User?> _authSubscription;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    /// Move to home if already logged in
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((
      User? user,
    ) {
      if (user != null && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const NewHomeScreen()),
          (route) => false,
        );
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      User? user = await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (user != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome back, ${user.email}!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) _showErrorDialog('Login Error', e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      User? user = await _authService.signInWithGoogle();
      if (user != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome, ${user.displayName ?? user.email}!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(
          'Google Sign-In Error',
          '${e.toString()}\n\nUse Email/Password login instead, or try again later.',
          showDemoButton: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String title, String message, {bool showDemoButton = false}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          if (showDemoButton)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _handleDemoLogin();
              },
              child: const Text('Try Demo', style: TextStyle(color: Colors.green)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDemoLogin() async {
    setState(() => _isLoading = true);
    
    try {
      // Try to login first, if that fails, sign up
      User? user;
      try {
        user = await _authService.login(
          email: 'demo@tajweed.test',
          password: 'DemoPassword123!@#',
        );
      } catch (loginError) {
        // If login fails, try to sign up
        print('Demo login failed, attempting signup: $loginError');
        user = await _authService.signUp(
          email: 'demo@tajweed.test',
          password: 'DemoPassword123!@#',
          fullName: 'Demo User',
        );
        
        // After signup, we need to login since signup signs out
        if (user != null) {
          user = await _authService.login(
            email: 'demo@tajweed.test',
            password: 'DemoPassword123!@#',
          );
        }
      }
      
      if (user != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Welcome to Demo Mode!'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(
          'Demo Login Error',
          'Failed to enter demo mode: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your email';
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(value))
      return 'Please enter a valid email address';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your password';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = ResponsiveHelper.isTablet(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E4976), Color(0xFF2E5F8F), Color(0xFF0F2940)],
          ),
        ),
        child: Stack(
          children: [
            // Background decorative circles
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -50,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),

            // Background pattern
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Opacity(
                opacity: 0.25,
                child: Image.asset("assets/g4.png", fit: BoxFit.fitWidth),
              ),
            ),

            // Main Content
            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile
                      ? 16
                      : isTablet
                      ? 32
                      : 48,
                  vertical: isMobile ? 16 : 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(height: isMobile ? 16 : 24),

                        // Logo with circular background
                        Container(
                          width: isMobile ? 100 : 120,
                          height: isMobile ? 100 : 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.3),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                              width: 2,
                            ),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Image.asset(
                            "assets/g6.png",
                            fit: BoxFit.contain,
                          ),
                        ),

                        SizedBox(height: isMobile ? 20 : 28),

                        // Heading
                        Text(
                          "Let's begin your journey!",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isMobile ? 20 : 24,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFB8860B),
                            letterSpacing: 0.3,
                          ),
                        ),

                        SizedBox(height: isMobile ? 24 : 32),

                        // Main Card Container
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.all(isMobile ? 20 : 28),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Email Field
                                CustomTextField(
                                  label: "Email address",
                                  hintText: "Enter email here",
                                  controller: _emailController,
                                  validator: _validateEmail,
                                  keyboardType: TextInputType.emailAddress,
                                  enabled: !_isLoading,
                                  prefixIcon: const Icon(Icons.email_outlined),
                                ),

                                const SizedBox(height: 16),

                                // Password Field
                                CustomTextField(
                                  label: "Password",
                                  hintText: "Enter Password here",
                                  controller: _passwordController,
                                  validator: _validatePassword,
                                  obscureText: true,
                                  enabled: !_isLoading,
                                  prefixIcon: const Icon(Icons.lock_outline),
                                ),

                                const SizedBox(height: 20),

                                // Login Button
                                CustomButton(
                                  label: "Log In",
                                  onPressed: _handleLogin,
                                  isLoading: _isLoading,
                                  isEnabled: !_isLoading,
                                  height: isMobile ? 48 : 52,
                                  backgroundColor: const Color(0xFF1E4976),
                                ),

                                SizedBox(height: isMobile ? 16 : 20),

                                // Divider with OR
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Divider(
                                        thickness: 1,
                                        color: Color(0xFFDECDB8),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Text(
                                        "OR",
                                        style: TextStyle(
                                          fontSize: isMobile ? 12 : 13,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const Expanded(
                                      child: Divider(
                                        thickness: 1,
                                        color: Color(0xFFDECDB8),
                                      ),
                                    ),
                                  ],
                                ),

                                SizedBox(height: isMobile ? 16 : 20),

                                // Google Sign In Button
                                SizedBox(
                                  width: double.infinity,
                                  height: isMobile ? 48 : 52,
                                  child: OutlinedButton.icon(
                                    onPressed: _isLoading
                                        ? null
                                        : _handleGoogleSignIn,
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: Color(0xFFB8860B),
                                        width: 1.5,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: Image.network(
                                      'https://www.google.com/favicon.ico',
                                      width: 20,
                                      height: 20,
                                      errorBuilder: (_, __, ___) => Image.network(
                                        'https://cdn-icons-png.flaticon.com/512/281/281764.png',
                                        width: 20,
                                        height: 20,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                              Icons.mail,
                                              color: Color(0xFFB8860B),
                                            ),
                                      ),
                                    ),
                                    label: Text(
                                      _isLoading
                                          ? "Signing in..."
                                          : "Continue with Google",
                                      style: TextStyle(
                                        color: Colors.black87,
                                        fontSize: isMobile ? 13 : 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),

                                SizedBox(height: isMobile ? 16 : 20),

                                // Sign Up Link
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Don't have an account? ",
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: isMobile ? 12 : 13,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: _isLoading
                                          ? null
                                          : () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      const SignUpScreen(),
                                                ),
                                              );
                                            },
                                      child: Text(
                                        "Sign Up",
                                        style: TextStyle(
                                          color: const Color(0xFF2E7D32),
                                          fontSize: isMobile ? 12 : 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: isMobile ? 24 : 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required String hintText,
    required TextEditingController controller,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
    required bool isLoading,
    required bool isMobile,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isMobile ? 12 : 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFB8860B),
          ),
        ),
        SizedBox(height: isMobile ? 6 : 8),
        TextFormField(
          controller: controller,
          enabled: !isLoading,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(fontSize: isMobile ? 13 : 14, color: Colors.black87),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: isMobile ? 13 : 14,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: isMobile ? 12 : 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFB8860B),
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFB8860B),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFB8860B), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordFormField({
    required String label,
    required String hintText,
    required TextEditingController controller,
    required String? Function(String?) validator,
    required bool obscure,
    required VoidCallback onToggle,
    required bool isLoading,
    required bool isMobile,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isMobile ? 12 : 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFB8860B),
          ),
        ),
        SizedBox(height: isMobile ? 6 : 8),
        TextFormField(
          controller: controller,
          enabled: !isLoading,
          obscureText: obscure,
          validator: validator,
          style: TextStyle(fontSize: isMobile ? 13 : 14, color: Colors.black87),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: isMobile ? 13 : 14,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off : Icons.visibility,
                color: const Color(0xFFB8860B),
                size: 20,
              ),
              onPressed: onToggle,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: isMobile ? 12 : 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFB8860B),
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFB8860B),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFB8860B), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
