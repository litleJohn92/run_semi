import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:run_semi/models/session.dart';
import 'package:run_semi/widgets/progression_chart.dart';

void main() {
  final today = DateTime.now();
  final logs = [
    for (var i = 0; i < 20; i++)
      SessionLog(
        dayIndex: 41 + i,
        date: today.subtract(Duration(days: i * 2)),
        completed: true,
        painLevel: i % 3,
        distanceMeters: 3000 + i * 150.0,
      ),
  ];

  Future<void> pumpChart(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ProgressionChart(logs: logs, workoutLogs: const [], onChanged: () {}),
        ),
      ),
    ));
  }

  Future<void> pinch(WidgetTester tester, Finder target) async {
    final center = tester.getCenter(target);
    final f1 = await tester.startGesture(center - const Offset(20, 0));
    final f2 = await tester.startGesture(center + const Offset(20, 0));
    for (var i = 0; i < 10; i++) {
      await f1.moveBy(const Offset(-10, 0));
      await f2.moveBy(const Offset(10, 0));
      await tester.pump();
    }
    await f1.up();
    await f2.up();
    await tester.pumpAndSettle();
  }

  testWidgets('pas de zoom en vue Semaine', (tester) async {
    await pumpChart(tester);
    expect(find.text('Pincez une courbe pour zoomer'), findsNothing);
  });

  testWidgets('pincer une courbe zoome en vue Mois, puis Réinitialiser', (tester) async {
    await pumpChart(tester);
    await tester.tap(find.text('Mois'));
    await tester.pumpAndSettle();
    expect(find.text('Pincez une courbe pour zoomer'), findsOneWidget);

    await pinch(tester, find.byType(LineChart).first);
    expect(find.textContaining('Zoom ×'), findsOneWidget);

    await tester.tap(find.text('Réinitialiser'));
    await tester.pumpAndSettle();
    expect(find.text('Pincez une courbe pour zoomer'), findsOneWidget);
  });

  testWidgets('changer de période remet le zoom à zéro', (tester) async {
    await pumpChart(tester);
    await tester.tap(find.text('Trimestre'));
    await tester.pumpAndSettle();
    await pinch(tester, find.byType(LineChart).first);
    expect(find.textContaining('Zoom ×'), findsOneWidget);

    await tester.tap(find.text('Mois'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Zoom ×'), findsNothing);
  });
}
