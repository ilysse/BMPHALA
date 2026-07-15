import 'package:bmp_frontend/core/constants/colors.dart';
import 'package:bmp_frontend/core/network/api_service.dart';
import 'package:bmp_frontend/providers/auth_provider.dart';
import 'package:bmp_frontend/providers/language_provider.dart';
import 'package:bmp_frontend/views/auth/login_view.dart';
import 'package:bmp_frontend/views/auth/onboarding_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Halawat app starts on the production login screen', (
    WidgetTester tester,
  ) async {
    final apiService = ApiService()..mockMode = true;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ChangeNotifierProvider(
            create: (_) => AuthProvider(apiService: apiService),
          ),
        ],
        child: MaterialApp(theme: AppTheme.lightTheme, home: const LoginView()),
      ),
    );
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(TextFormField), findsAtLeastNWidgets(2));
    expect(find.byIcon(Icons.email_outlined), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byIcon(Icons.language), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(find.byType(TextButton), findsOneWidget);
  });

  testWidgets('Retailer registration is available in Arabic', (
    WidgetTester tester,
  ) async {
    final apiService = ApiService()..mockMode = true;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ChangeNotifierProvider(
            create: (_) => AuthProvider(apiService: apiService),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const OnboardingView(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('تسجيل تاجر جديد'), findsOneWidget);
    expect(find.text('انضم إلى شبكة حلوات'), findsOneWidget);
    expect(find.text('اسم المتجر'), findsOneWidget);
  });
}
