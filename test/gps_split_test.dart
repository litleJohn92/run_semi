import 'package:flutter_test/flutter_test.dart';

import 'package:run_semi/models/route_point.dart';
import 'package:run_semi/services/gps_service.dart';

void main() {
  test('chaque segment GPS va à la phase en cours à son point d\'arrivée', () {
    final t0 = DateTime(2026, 11, 16, 8);
    RoutePoint at(int s, double lat) =>
        RoutePoint(lat: lat, lng: 2.35, altitude: 0, timestamp: t0.add(Duration(seconds: s)));
    // ~111 m par millième de degré de latitude
    final points = [at(0, 48.000), at(30, 48.002), at(90, 48.003)];
    final phases = [(t0, true), (t0.add(const Duration(seconds: 60)), false)];

    final split = GpsService.splitDistance(points, phases);

    expect(split.run, closeTo(222, 2));
    expect(split.walk, closeTo(111, 1));
    expect(GpsService.splitDistance(points, const []).run, 0);
  });
}
