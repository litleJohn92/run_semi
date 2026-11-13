import 'package:flutter_test/flutter_test.dart';

import 'package:run_semi/data/semi_program.dart';
import 'package:run_semi/data/strength_program.dart';
import 'package:run_semi/data/tendinite_program.dart';
import 'package:run_semi/models/session.dart';

void main() {
  group('Programmes', () {
    test('le programme tendinite couvre la phase 1 (jours 1 à 40)', () {
      expect(tendiniteProgram, isNotEmpty);
      for (final s in tendiniteProgram) {
        expect(s.phase, 1, reason: 'jour ${s.dayIndex}');
      }
    });

    test('le programme semi couvre la phase 2 (jours 41 à 124)', () {
      expect(semiProgram, isNotEmpty);
      for (final s in semiProgram) {
        expect(s.dayIndex, inInclusiveRange(41, 124), reason: s.title);
      }
    });

    test('les jours sont uniques et croissants', () {
      final days = [...tendiniteProgram, ...semiProgram].map((s) => s.dayIndex).toList();
      expect(days.toSet().length, days.length, reason: 'jour en double');
      for (var i = 1; i < days.length; i++) {
        expect(days[i], greaterThan(days[i - 1]));
      }
    });

    test('chaque séance de course a des phases de durée positive', () {
      for (final s in [...tendiniteProgram, ...semiProgram].where((s) => s.isRunnable)) {
        expect(s.phases, isNotEmpty, reason: 'jour ${s.dayIndex}');
        for (final p in s.phases) {
          expect(p.durationSeconds, greaterThan(0), reason: 'jour ${s.dayIndex}');
        }
      }
    });

    test('le programme de renforcement est défini', () {
      expect(strengthProgram, isNotEmpty);
    });
  });

  group('SessionLog', () {
    test('survit à un aller-retour JSON, tracé GPS compris', () {
      final log = SessionLog(
        dayIndex: 5,
        date: DateTime(2026, 10, 5, 8, 41),
        completed: true,
        painLevel: 2,
        distanceMeters: 1782.5,
        route: const [
          [1.0, 2.0],
          [1.5, 2.5],
        ],
      );
      final copy = SessionLog.fromJson(log.toJson());
      expect(copy.dayIndex, log.dayIndex);
      expect(copy.date, log.date);
      expect(copy.completed, isTrue);
      expect(copy.painLevel, 2);
      expect(copy.distanceMeters, 1782.5);
      expect(copy.route, log.route);
    });

    test('accepte un log ancien sans distance ni tracé', () {
      final log = SessionLog.fromJson({
        'dayIndex': 1,
        'date': '2026-10-01T00:00:00.000',
        'completed': true,
        'painLevel': 0,
      });
      expect(log.distanceMeters, 0);
      expect(log.route, isNull);
    });
  });
}
