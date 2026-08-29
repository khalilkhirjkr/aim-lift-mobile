// Basic smoke test for the AIM-Lift app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aim_lift_app/main.dart';

void main() {
  testWidgets('AimLiftApp builds without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const AimLiftApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
