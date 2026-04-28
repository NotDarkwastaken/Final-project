import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:final_yr_project/main.dart';

void main() {
  testWidgets('SafeCircle Modern UI load test', (WidgetTester tester) async {
    // 1. Build our app and trigger a frame.
    await tester.pumpWidget(const SafeCircleApp());

    // 2. Check for the Search Bar text instead of the old AppBar title
    expect(find.text('Search places or people...'), findsOneWidget);

    // 3. Verify the SOS button still exists
    expect(find.text('SOS'), findsOneWidget);

    // 4. Verify that circle member names are showing in the bottom tray
    expect(find.text('Mom'), findsOneWidget);
    expect(find.text('Active Circle'), findsOneWidget);
  });
}
