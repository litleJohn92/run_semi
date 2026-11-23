import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import '../models/route_point.dart';

class GpsService {
  // Fixes GPS ambiants au-delà de ce rayon (m), typiques en zone urbaine/couvert
  static const double _maxAcceptableAccuracyMeters = 25;

  final List<RoutePoint> _points = [];
  bool _recording = false;
  bool _paused = false;
  DateTime? _startTime;
  StreamSubscription<Position>? _subscription;

  List<RoutePoint> get points => List.unmodifiable(_points);
  bool get isRecording => _recording;
  DateTime? get startTime => _startTime;

  double get totalDistanceMeters {
    if (_points.length < 2) return 0;
    double total = 0;
    for (int i = 1; i < _points.length; i++) {
      total += _haversine(
        _points[i - 1].lat, _points[i - 1].lng,
        _points[i].lat, _points[i].lng,
      );
    }
    return total;
  }

  String get distanceLabel {
    final d = totalDistanceMeters;
    if (d < 1000) return '${d.round()} m';
    return '${(d / 1000).toStringAsFixed(2)} km';
  }

  Future<void> startRecording() async {
    // Demande explicite des permissions (indispensable en release)
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      return;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    _points.clear();
    _recording = true;
    _paused = false;
    _startTime = DateTime.now();

    _subscription?.cancel();
    _subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((position) {
      if (!_recording || _paused) return;
      if (position.accuracy > _maxAcceptableAccuracyMeters) return;
      _points.add(RoutePoint(
        lat: position.latitude,
        lng: position.longitude,
        altitude: position.altitude,
        timestamp: position.timestamp,
      ));
    });
  }

  /// Répartit la distance entre course et marche : chaque segment GPS est
  /// attribué à la phase en cours à l'horodatage de son point d'arrivée.
  /// [phaseStarts] = (début de phase, est-ce de la course ?), dans l'ordre.
  static ({double run, double walk}) splitDistance(
      List<RoutePoint> points, List<(DateTime, bool)> phaseStarts) {
    var run = 0.0, walk = 0.0;
    if (phaseStarts.isEmpty) return (run: run, walk: walk);
    for (int i = 1; i < points.length; i++) {
      final t = points[i].timestamp;
      final isRun = phaseStarts
          .lastWhere((p) => !p.$1.isAfter(t), orElse: () => phaseStarts.first)
          .$2;
      final d = _haversine(points[i - 1].lat, points[i - 1].lng, points[i].lat, points[i].lng);
      if (isRun) {
        run += d;
      } else {
        walk += d;
      }
    }
    return (run: run, walk: walk);
  }

  // Fige la distance/tracé pendant une pause sans perdre l'historique
  void pause() => _paused = true;
  void resume() => _paused = false;

  void stopRecording() {
    _recording = false;
    _subscription?.cancel();
    _subscription = null;
  }

  static double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _toRad(double deg) => deg * pi / 180;
}
