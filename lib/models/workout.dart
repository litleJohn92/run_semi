/// Modèle de données pour les séances KB — avec imagePath pour les illustrations
class Exercise {
  final String name;
  final String description;
  final String? tip;
  final int durationSeconds;
  final int restSeconds;
  final String? imagePath; // 'assets/exercises/goblet_squat.png'

  const Exercise({
    required this.name,
    required this.description,
    this.tip,
    this.durationSeconds = 30,
    this.restSeconds = 30,
    this.imagePath,
  });
}

class WorkoutBlock {
  final String title;
  final int rounds;
  final List<Exercise> exercises;

  const WorkoutBlock({
    required this.title,
    required this.rounds,
    required this.exercises,
  });

  int get totalMinutes {
    final totalSecs = exercises.fold(0, (s, e) =>
        s + e.durationSeconds + e.restSeconds) * rounds;
    return (totalSecs / 60).ceil();
  }
}

class DayWorkout {
  final int weekNumber;
  final int dayOfWeek;
  final String title;
  final String subtitle;
  final List<WorkoutBlock> blocks;

  const DayWorkout({
    required this.weekNumber,
    required this.dayOfWeek,
    required this.title,
    required this.subtitle,
    this.blocks = const [],
  });

  int get totalMinutes =>
      blocks.fold(0, (s, b) => s + b.totalMinutes);
}
