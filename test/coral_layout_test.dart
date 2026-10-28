import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_management_mobile/app/coral_theme.dart';
import 'package:user_management_mobile/core/api_client.dart';
import 'package:user_management_mobile/core/config.dart';
import 'package:user_management_mobile/core/services.dart';
import 'package:user_management_mobile/features/auth/auth_page.dart';
import 'package:user_management_mobile/features/auth/coral_sign_in.dart';
import 'package:user_management_mobile/features/auth/session_controller.dart';
import 'package:user_management_mobile/features/auth/token_store.dart';

Future<void> pumpAuth(
  WidgetTester tester, {
  double width = 390,
  double height = 900,
  double textScale = 1.3,
  double keyboardInset = 0,
  AuthMode mode = AuthMode.signIn,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final fonts = FontLoader(Coral.font);
  for (final weight in [400, 500, 600]) {
    fonts.addFont(rootBundle.load('assets/fonts/GeneralSans-$weight.ttf'));
  }
  await tester.runAsync(fonts.load);
  final icons = FontLoader('MaterialIcons');
  icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await tester.runAsync(icons.load);
  final api = ApiClient('https://example.test');
  final session = SessionController(api, SecureTokenStore());
  addTearDown(session.dispose);
  addTearDown(() => api.dio.close());
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: coralTheme(),
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, height),
          textScaler: TextScaler.linear(textScale),
          viewInsets: EdgeInsets.only(bottom: keyboardInset),
        ),
        child: AuthPage(
          services: AppServices(
            const AppConfig(apiUrl: 'https://example.test'),
            api,
            session,
          ),
          mode: mode,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [320.0, 390.0, 768.0, 1280.0]) {
    testWidgets('Coral sign-in fits width $width with enlarged text', (
      tester,
    ) async {
      await pumpAuth(tester, width: width);
      expect(find.byType(CoralSignIn), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.byType(OutlinedButton), findsNWidgets(3));
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_CORAL')) {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('/tmp/coral-mobile-sign-in-${width.toInt()}.png'),
        );
      }
    });
  }

  testWidgets('Sign-in stays scrollable with keyboard and 200% text', (
    tester,
  ) async {
    await pumpAuth(
      tester,
      width: 320,
      height: 640,
      textScale: 2,
      keyboardInset: 280,
    );
    final resend = find.widgetWithText(
      OutlinedButton,
      'Resend verification email',
    );
    await tester.ensureVisible(resend);
    await tester.pumpAndSettle();
    expect(resend.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sign-in keeps existing required-field validation', (
    tester,
  ) async {
    await pumpAuth(tester);
    final submit = find.byType(FilledButton);
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    final states = tester.stateList<FormFieldState<String>>(
      find.byType(TextFormField),
    );
    expect(states.every((state) => state.hasError), isTrue);
    expect(find.byType(CoralSignIn), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Other authentication modes retain the shared screen', (
    tester,
  ) async {
    await pumpAuth(tester, mode: AuthMode.signUp);
    expect(find.byType(CoralSignIn), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(5));
    expect(find.widgetWithText(TextButton, 'Back to sign in'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
