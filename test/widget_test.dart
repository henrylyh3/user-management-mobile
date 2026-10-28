import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_management_mobile/app/app.dart';
import 'package:user_management_mobile/core/config.dart';
import 'package:user_management_mobile/core/services.dart';

void main() {
  testWidgets(
    'Missing API configuration shows setup without initializing storage',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            configProvider.overrideWithValue(const AppConfig(apiUrl: '')),
          ],
          child: const UserManagementApp(),
        ),
      );
      expect(find.text('Setup required'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
    },
  );
}
