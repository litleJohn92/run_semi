import 'package:flutter_test/flutter_test.dart';
import 'package:run_semi/services/pedometer_service.dart';

void main() {
  test('formatPace', () {
    expect(PedometerService.formatPace(332), "5'32\"/km");
    expect(PedometerService.formatPace(359.6), "6'00\"/km");
    expect(PedometerService.formatPace(null), "--'--\"");
    expect(PedometerService.formatPace(5000), "--'--\"");
  });

  test('averagePace = moyenne des vitesses', () {
    expect(PedometerService.averagePace([]), isNull);
    expect(PedometerService.averagePace([300, 300]), 300);
    // 1 min à 4'/km + 1 min à 6'/km = 0.25 + 0.1667 km en 2 min → 4'48"/km
    expect(PedometerService.averagePace([240, 360])!.round(), 288);
  });
}
