import 'package:flutter_test/flutter_test.dart';
import 'package:run_semi/data/tendinite_program.dart';
import 'package:run_semi/models/session.dart';
import 'package:run_semi/widgets/share_stats_card.dart';

void main() {
  test('buildShareStats cumule km, temps de course et garde la dernière allure / douleur', () {
    final s = tendiniteProgram.firstWhere((s) => s.phases.any((p) => p.isRun));
    final run = s.phases.where((p) => p.isRun).fold(0, (a, p) => a + p.durationSeconds);
    final logs = [
      SessionLog(dayIndex: s.dayIndex, date: DateTime(2026, 1, 2), completed: true, painLevel: 2,
          distanceMeters: 3000, runMeters: run / 360 * 1000), // course à 6:00/km
      SessionLog(dayIndex: s.dayIndex, date: DateTime(2026, 1, 1), completed: true, painLevel: 0,
          distanceMeters: 2000, runMeters: run / 300 * 1000), // plus ancienne, 5:00/km
      SessionLog(dayIndex: s.dayIndex, date: DateTime(2026, 1, 3), completed: false, painLevel: 3,
          distanceMeters: 9000), // non terminée : ignorée
    ];

    final v = {for (final st in buildShareStats(logs)) st.label: st.value};
    final runMinutes = (2 * run / 60).round();

    expect(v['Distance totale'], '5.0 km');
    expect(v['Dernière allure course'], '6:00/km');
    expect(v['Temps de course'], '${runMinutes ~/ 60} h ${(runMinutes % 60).toString().padLeft(2, '0')}');
    expect(v['Douleur au tendon'], '😬 Modérée');
    expect({for (final st in buildShareStats([])) st.label: st.value}['Allure moyenne'], '–');
  });

  test("l'allure accéléromètre prime sur l'allure GPS", () {
    final s = tendiniteProgram.firstWhere((s) => s.phases.any((p) => p.isRun));
    final logs = [
      SessionLog(dayIndex: s.dayIndex, date: DateTime(2026, 1, 1), completed: true, painLevel: 0,
          distanceMeters: 3000, runMeters: 2000, runPaceSecPerKm: 332),
    ];
    final v = {for (final st in buildShareStats(logs)) st.label: st.value};
    expect(v['Dernière allure course'], '5:32/km');
    final log = SessionLog.fromJson(logs.first.toJson());
    expect(log.runPaceSecPerKm, 332);
  });
}
