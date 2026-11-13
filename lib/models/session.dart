// ── Types de séances ────────────────────────────────────────────────────────
enum SessionType {
  repos,
  endurance,
  intervalles,
  renforcement,
  croise,
  recuperation,
  competition,
}

// ── Zones d'effort ──────────────────────────────────────────────────────────
enum Zone { z1, z2, z3, z4, z5 }

extension ZoneLabel on Zone {
  String get label => ['Z1', 'Z2', 'Z3', 'Z4', 'Z5'][index];
  String get description => [
    'Allure facile — conversation possible',
    'Allure modérée — phrases courtes',
    'Allure soutenue — effort difficile',
    'Allure rapide — effort très difficile',
    'Allure maximale — tout donner',
  ][index];
}

// ── Phase de timer ──────────────────────────────────────────────────────────
enum PhaseType { walk, run }

class TimerPhase {
  final PhaseType type;
  final int durationSeconds;
  final String label;
  final Zone zone;
  final int? repNumber;
  final int? totalReps;

  const TimerPhase({
    required this.type,
    required this.durationSeconds,
    required this.label,
    this.zone = Zone.z1,
    this.repNumber,
    this.totalReps,
  });

  bool get isRun  => type == PhaseType.run;
  bool get isWalk => type == PhaseType.walk;

  String get durationLabel {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    if (m == 0) return '${s}s';
    if (s == 0) return '${m}min';
    return '${m}min${s}s';
  }
}

// ── Séance ──────────────────────────────────────────────────────────────────
class Session {
  final int dayIndex;      // 1-40 = phase 1, 41-124 = phase 2
  final int weekNumber;
  final int sessionInWeek;
  final String title;
  final String subtitle;
  final List<TimerPhase> phases;
  final SessionType sessionType;
  final int? pe;             // Perception d'effort (1-10)
  final String? rcLabel;     // RC : 50-70% etc.

  const Session({
    required this.dayIndex,
    required this.weekNumber,
    required this.sessionInWeek,
    required this.title,
    required this.subtitle,
    required this.phases,
    this.sessionType = SessionType.endurance,
    this.pe,
    this.rcLabel,
  });

  int get totalDurationSeconds =>
      phases.fold(0, (s, p) => s + p.durationSeconds);
  int get totalDurationMinutes => (totalDurationSeconds / 60).round();
  int get runCount => phases.where((p) => p.isRun).length;

  bool get isRunnable =>
      sessionType != SessionType.repos &&
      sessionType != SessionType.croise &&
      sessionType != SessionType.renforcement &&
      sessionType != SessionType.competition;

  // Phase dans laquelle on est (1 ou 2)
  int get phase => dayIndex <= 40 ? 1 : 2;
}

// ── Log de séance ────────────────────────────────────────────────────────────
class SessionLog {
  final int dayIndex;
  final DateTime date;
  final bool completed;
  final int painLevel;
  final double distanceMeters;
  final List<List<double>>? route; // [[lat, lng], ...] — null si pas de tracé GPS

  // Séance auto-sauvegardée avant que l'utilisateur n'ait choisi une douleur
  static const int unratedPain = -1;

  const SessionLog({
    required this.dayIndex,
    required this.date,
    required this.completed,
    required this.painLevel,
    this.distanceMeters = 0,
    this.route,
  });

  Map<String, dynamic> toJson() => {
    'dayIndex': dayIndex,
    'date': date.toIso8601String(),
    'completed': completed,
    'painLevel': painLevel,
    'distanceMeters': distanceMeters,
    if (route != null) 'route': route,
  };

  factory SessionLog.fromJson(Map<String, dynamic> json) => SessionLog(
    dayIndex: json['dayIndex'] as int,
    date: DateTime.parse(json['date'] as String),
    completed: json['completed'] as bool,
    painLevel: json['painLevel'] as int,
    distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0,
    route: (json['route'] as List?)
        ?.map((p) => (p as List).map((v) => (v as num).toDouble()).toList())
        .toList(),
  );
}

// ── Log séance KB ────────────────────────────────────────────────────────────
class WorkoutLog {
  final DateTime date;
  final double estimatedVolumeKg;
  final int durationMinutes;
  final String sessionTitle;

  const WorkoutLog({
    required this.date,
    required this.estimatedVolumeKg,
    required this.durationMinutes,
    required this.sessionTitle,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'estimatedVolumeKg': estimatedVolumeKg,
    'durationMinutes': durationMinutes,
    'sessionTitle': sessionTitle,
  };

  factory WorkoutLog.fromJson(Map<String, dynamic> json) => WorkoutLog(
    date: DateTime.parse(json['date'] as String),
    estimatedVolumeKg: (json['estimatedVolumeKg'] as num).toDouble(),
    durationMinutes: json['durationMinutes'] as int,
    sessionTitle: json['sessionTitle'] as String,
  );
}
