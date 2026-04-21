import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tajweed_corrector/main.dart';

void main() {
  testWidgets('AuthWrapper shows loading state without Firebase init', (
    WidgetTester tester,
  ) async {
    final authController = StreamController<User?>();

    await tester.pumpWidget(
      MyApp(authStateChangesStream: authController.stream),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await authController.close();
  });
}
