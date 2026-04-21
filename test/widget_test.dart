import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:splitwise/app/app.dart';

void main() {
  testWidgets('First launch shows profile setup and proceeds to shell', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(const SplitwiseApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Splitwise'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'Alex');
    await tester.enterText(find.byType(TextField).at(1), 'INR');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Expenses'), findsWidgets);
    expect(find.text('Create a group from Manage to begin.'), findsOneWidget);
  });
}
