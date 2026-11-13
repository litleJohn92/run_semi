import '../models/session.dart';

Session _intervals({
  required int dayIndex, required int weekNumber, required int sessionInWeek,
  required String title, required String subtitle,
  int? warmupSeconds,
  required int reps, required int runSeconds, required int walkSeconds,
}) {
  final phases = <TimerPhase>[];
  if (warmupSeconds != null) {
    phases.add(TimerPhase(type: PhaseType.walk, durationSeconds: warmupSeconds, label: "Marche d'échauffement"));
  }
  for (int i = 0; i < reps; i++) {
    phases.add(TimerPhase(type: PhaseType.run, durationSeconds: runSeconds, label: 'Course', repNumber: i + 1, totalReps: reps));
    phases.add(TimerPhase(type: PhaseType.walk, durationSeconds: walkSeconds, label: 'Marche'));
  }
  return Session(dayIndex: dayIndex, weekNumber: weekNumber, sessionInWeek: sessionInWeek, title: title, subtitle: subtitle, phases: phases);
}

Session _continuous({required int dayIndex, required int weekNumber, required int sessionInWeek, required int minutes}) {
  return Session(
    dayIndex: dayIndex, weekNumber: weekNumber, sessionInWeek: sessionInWeek,
    title: '$minutes min de course continue',
    subtitle: 'Allure confortable, tu peux parler',
    phases: [TimerPhase(type: PhaseType.run, durationSeconds: minutes * 60, label: 'Course continue')],
  );
}

final List<Session> tendiniteProgram = [
  // SEMAINE 1 — 1'/1'
  _intervals(dayIndex: 1, weekNumber: 1, sessionInWeek: 1, title: "5' marche + 3×(1' course / 1' marche)", subtitle: 'Début en douceur', warmupSeconds: 300, reps: 3, runSeconds: 60, walkSeconds: 60),
  _intervals(dayIndex: 2, weekNumber: 1, sessionInWeek: 2, title: "4×(1' course / 1' marche)", subtitle: 'Semaine 1 · Jour 2', reps: 4, runSeconds: 60, walkSeconds: 60),
  _intervals(dayIndex: 3, weekNumber: 1, sessionInWeek: 3, title: "5×(1' course / 1' marche)", subtitle: 'Semaine 1 · Jour 3', reps: 5, runSeconds: 60, walkSeconds: 60),
  _intervals(dayIndex: 4, weekNumber: 1, sessionInWeek: 4, title: "6×(1' course / 1' marche)", subtitle: 'Semaine 1 · Jour 4', reps: 6, runSeconds: 60, walkSeconds: 60),
  _intervals(dayIndex: 5, weekNumber: 1, sessionInWeek: 5, title: "7×(1' course / 1' marche)", subtitle: 'Semaine 1 · Jour 5', reps: 7, runSeconds: 60, walkSeconds: 60),
  // SEMAINE 2
  _intervals(dayIndex: 6, weekNumber: 2, sessionInWeek: 1, title: "8×(1' course / 1' marche)", subtitle: 'Semaine 2 · Jour 1', reps: 8, runSeconds: 60, walkSeconds: 60),
  _intervals(dayIndex: 7, weekNumber: 2, sessionInWeek: 2, title: "9×(1' course / 1' marche)", subtitle: 'Semaine 2 · Jour 2', reps: 9, runSeconds: 60, walkSeconds: 60),
  _intervals(dayIndex: 8, weekNumber: 2, sessionInWeek: 3, title: "10×(1' course / 1' marche)", subtitle: 'Semaine 2 · Jour 3', reps: 10, runSeconds: 60, walkSeconds: 60),
  _intervals(dayIndex: 9, weekNumber: 2, sessionInWeek: 4, title: "11×(1' course / 1' marche)", subtitle: 'Semaine 2 · Jour 4', reps: 11, runSeconds: 60, walkSeconds: 60),
  _intervals(dayIndex: 10, weekNumber: 2, sessionInWeek: 5, title: "12×(1' course / 1' marche)", subtitle: 'Semaine 2 · Jour 5', reps: 12, runSeconds: 60, walkSeconds: 60),
  // SEMAINE 3
  _intervals(dayIndex: 11, weekNumber: 3, sessionInWeek: 1, title: "13×(1' course / 1' marche)", subtitle: 'Semaine 3 · Jour 1', reps: 13, runSeconds: 60, walkSeconds: 60),
  _intervals(dayIndex: 12, weekNumber: 3, sessionInWeek: 2, title: "14×(1' course / 1' marche)", subtitle: 'Semaine 3 · Jour 2', reps: 14, runSeconds: 60, walkSeconds: 60),
  _intervals(dayIndex: 13, weekNumber: 3, sessionInWeek: 3, title: "15×(1' course / 1' marche)", subtitle: 'Semaine 3 · Jour 3', reps: 15, runSeconds: 60, walkSeconds: 60),
  _intervals(dayIndex: 14, weekNumber: 3, sessionInWeek: 4, title: "3×(2' course / 1' marche)", subtitle: 'On passe à 2 minutes de course !', reps: 3, runSeconds: 120, walkSeconds: 60),
  _intervals(dayIndex: 15, weekNumber: 3, sessionInWeek: 5, title: "4×(2' course / 1' marche)", subtitle: 'Semaine 3 · Jour 5', reps: 4, runSeconds: 120, walkSeconds: 60),
  // SEMAINE 4
  _intervals(dayIndex: 16, weekNumber: 4, sessionInWeek: 1, title: "5×(2' course / 1' marche)", subtitle: 'Semaine 4 · Jour 1', reps: 5, runSeconds: 120, walkSeconds: 60),
  _intervals(dayIndex: 17, weekNumber: 4, sessionInWeek: 2, title: "6×(2' course / 1' marche)", subtitle: 'Semaine 4 · Jour 2', reps: 6, runSeconds: 120, walkSeconds: 60),
  _intervals(dayIndex: 18, weekNumber: 4, sessionInWeek: 3, title: "7×(2' course / 1' marche)", subtitle: 'Semaine 4 · Jour 3', reps: 7, runSeconds: 120, walkSeconds: 60),
  _intervals(dayIndex: 19, weekNumber: 4, sessionInWeek: 4, title: "8×(2' course / 1' marche)", subtitle: 'Semaine 4 · Jour 4', reps: 8, runSeconds: 120, walkSeconds: 60),
  _intervals(dayIndex: 20, weekNumber: 4, sessionInWeek: 5, title: "9×(2' course / 1' marche)", subtitle: 'Semaine 4 · Jour 5', reps: 9, runSeconds: 120, walkSeconds: 60),
  // SEMAINE 5
  _intervals(dayIndex: 21, weekNumber: 5, sessionInWeek: 1, title: "10×(2' course / 1' marche)", subtitle: 'Semaine 5 · Jour 1', reps: 10, runSeconds: 120, walkSeconds: 60),
  _intervals(dayIndex: 22, weekNumber: 5, sessionInWeek: 2, title: "3×(3' course / 1' marche)", subtitle: 'On passe à 3 minutes !', reps: 3, runSeconds: 180, walkSeconds: 60),
  _intervals(dayIndex: 23, weekNumber: 5, sessionInWeek: 3, title: "4×(3' course / 1' marche)", subtitle: 'Semaine 5 · Jour 3', reps: 4, runSeconds: 180, walkSeconds: 60),
  _intervals(dayIndex: 24, weekNumber: 5, sessionInWeek: 4, title: "5×(3' course / 1' marche)", subtitle: 'Semaine 5 · Jour 4', reps: 5, runSeconds: 180, walkSeconds: 60),
  _intervals(dayIndex: 25, weekNumber: 5, sessionInWeek: 5, title: "6×(3' course / 1' marche)", subtitle: 'Semaine 5 · Jour 5', reps: 6, runSeconds: 180, walkSeconds: 60),
  // SEMAINE 6
  _intervals(dayIndex: 26, weekNumber: 6, sessionInWeek: 1, title: "7×(3' course / 1' marche)", subtitle: 'Semaine 6 · Jour 1', reps: 7, runSeconds: 180, walkSeconds: 60),
  _intervals(dayIndex: 27, weekNumber: 6, sessionInWeek: 2, title: "8×(3' course / 1' marche)", subtitle: 'Semaine 6 · Jour 2', reps: 8, runSeconds: 180, walkSeconds: 60),
  _intervals(dayIndex: 28, weekNumber: 6, sessionInWeek: 3, title: "2×(4' course / 1' marche)", subtitle: 'On passe à 4 minutes !', reps: 2, runSeconds: 240, walkSeconds: 60),
  _intervals(dayIndex: 29, weekNumber: 6, sessionInWeek: 4, title: "3×(4' course / 1' marche)", subtitle: 'Semaine 6 · Jour 4', reps: 3, runSeconds: 240, walkSeconds: 60),
  _intervals(dayIndex: 30, weekNumber: 6, sessionInWeek: 5, title: "4×(4' course / 1' marche)", subtitle: 'Semaine 6 · Jour 5', reps: 4, runSeconds: 240, walkSeconds: 60),
  // SEMAINE 7
  _intervals(dayIndex: 31, weekNumber: 7, sessionInWeek: 1, title: "5×(4' course / 1' marche)", subtitle: 'Semaine 7 · Jour 1', reps: 5, runSeconds: 240, walkSeconds: 60),
  _intervals(dayIndex: 32, weekNumber: 7, sessionInWeek: 2, title: "6×(4' course / 1' marche)", subtitle: 'Semaine 7 · Jour 2', reps: 6, runSeconds: 240, walkSeconds: 60),
  _intervals(dayIndex: 33, weekNumber: 7, sessionInWeek: 3, title: "1×(9' course / 1' marche)", subtitle: 'Première fois à 9 minutes !', reps: 1, runSeconds: 540, walkSeconds: 60),
  _intervals(dayIndex: 34, weekNumber: 7, sessionInWeek: 4, title: "2×(9' course / 1' marche)", subtitle: 'Semaine 7 · Jour 4', reps: 2, runSeconds: 540, walkSeconds: 60),
  _intervals(dayIndex: 35, weekNumber: 7, sessionInWeek: 5, title: "3×(9' course / 1' marche)", subtitle: 'Semaine 7 · Jour 5', reps: 3, runSeconds: 540, walkSeconds: 60),
  // SEMAINE 8
  _intervals(dayIndex: 36, weekNumber: 8, sessionInWeek: 1, title: "1×(14' course / 1' marche)", subtitle: 'Presque de la course continue !', reps: 1, runSeconds: 840, walkSeconds: 60),
  _intervals(dayIndex: 37, weekNumber: 8, sessionInWeek: 2, title: "2×(14' course / 1' marche)", subtitle: 'Semaine 8 · Jour 2', reps: 2, runSeconds: 840, walkSeconds: 60),
  _continuous(dayIndex: 38, weekNumber: 8, sessionInWeek: 3, minutes: 20),
  _continuous(dayIndex: 39, weekNumber: 8, sessionInWeek: 4, minutes: 25),
  _continuous(dayIndex: 40, weekNumber: 8, sessionInWeek: 5, minutes: 30),
];