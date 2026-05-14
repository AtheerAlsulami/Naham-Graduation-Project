import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naham_app/main.dart';

void main() {
  testWidgets('NahamApp loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const NahamApp());

    // Verify that the app loaded (e.g. looking for the splash screen content or role selector)
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
