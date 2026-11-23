import 'package:flutter/services.dart';

/// Allure estimée par l'accéléromètre (CMPedometer iOS), indépendante du GPS.
class PedometerService {
  static const _channel = EventChannel('run_semi/pedometer');

  /// Allure courante en secondes/km ; null quand l'iPhone ne détecte pas de course.
  static Stream<double?> paceStream() => _channel
      .receiveBroadcastStream()
      .map((secPerMeter) => secPerMeter == null ? null : (secPerMeter as num) * 1000);

  /// Allure moyenne (s/km) d'échantillons pris à intervalle régulier : moyenne
  /// des vitesses, pas des allures (sinon les passages lents pèsent trop).
  static double? averagePace(List<double> secPerKmSamples) {
    final valid = secPerKmSamples.where((p) => p > 0).toList();
    if (valid.isEmpty) return null;
    final meanSpeed = valid.fold(0.0, (s, p) => s + 1 / p) / valid.length;
    return 1 / meanSpeed;
  }

  static String formatPace(double? secPerKm) {
    if (secPerKm == null || secPerKm <= 0 || secPerKm > 1200) return "--'--\"";
    final s = secPerKm.round();
    return "${s ~/ 60}'${(s % 60).toString().padLeft(2, '0')}\"/km";
  }
}
