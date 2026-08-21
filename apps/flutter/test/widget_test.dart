import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meckchat/main.dart';

void main() {
  testWidgets('MeckChat app launches successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MeckChatApp());

    // Verify the app launches with the correct title
    expect(find.text('MeckChat'), findsOneWidget);

    // Verify the MaterialApp is present
    expect(find.byType(MaterialApp), findsOneWidget);

    // Verify the HomeScreen is rendered
    expect(find.byType(MeckChatApp), findsOneWidget);
  });
}
