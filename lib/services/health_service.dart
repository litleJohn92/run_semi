import 'package:health/health.dart';

class HealthService {
  static final _health = Health();

  static Future<bool> requestPermissions() async {
    try {
      return await _health.requestAuthorization(
        [HealthDataType.WORKOUT],
        permissions: [HealthDataAccess.WRITE],
      );
    } catch (_) {
      return false;
    }
  }

  static Future<HealthSaveResult> saveRun({
    required DateTime startTime,
    required DateTime endTime,
    required double distanceMeters,
  }) async {
    try {
      final authorized = await requestPermissions();
      if (!authorized) return HealthSaveResult.denied;

      final distanceKm = distanceMeters / 1000;
      final calories = (distanceKm * 60).roundToDouble();

      final success = await _health.writeWorkoutData(
        activityType: HealthWorkoutActivityType.RUNNING,
        start: startTime,
        end: endTime,
        totalDistance: distanceMeters.round(),        // 👈 .round() pour int
        totalDistanceUnit: HealthDataUnit.METER,
        totalEnergyBurned: calories.round(),          // 👈 .round() pour int
        totalEnergyBurnedUnit: HealthDataUnit.KILOCALORIE,
      );
      return success ? HealthSaveResult.success : HealthSaveResult.error;
    } catch (_) {
      return HealthSaveResult.error;
    }
  }
}

enum HealthSaveResult { success, denied, error }