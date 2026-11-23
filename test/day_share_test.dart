import 'package:flutter_test/flutter_test.dart';
import 'package:run_semi/data/tendinite_program.dart';
import 'package:run_semi/models/session.dart';
import 'package:run_semi/widgets/share_stats_card.dart';

void main() {
  final s = tendiniteProgram.firstWhere((s) => s.phases.any((p) => p.isRun));

  test('jour à venir : contenu prévu, sans douleur', () {
    final v = {for (final st in buildDayShareStats(s, null)) st.label: st.value};
    expect(v['Durée'], '${s.totalDurationMinutes} min');
    expect(v.containsKey('Distance'), isFalse);
    expect(v.keys.any((k) => k.contains('Douleur')), isFalse);
  });

  test('jour fait : distance + allure accéléromètre, sans douleur', () {
    final log = SessionLog(dayIndex: s.dayIndex, date: DateTime(2026, 11, 20), completed: true,
        painLevel: 2, distanceMeters: 3250, runPaceSecPerKm: 332);
    final v = {for (final st in buildDayShareStats(s, log)) st.label: st.value};
    expect(v['Distance'], '3.25 km');
    expect(v['Allure course'], "5'32\"/km");
    expect(v.keys.any((k) => k.contains('Douleur')), isFalse);
  });
}
