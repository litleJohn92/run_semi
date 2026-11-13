import '../models/session.dart';

// ─── HELPERS ────────────────────────────────────────────────────────────────

// Échauffement ou retour au calme Z1
TimerPhase _w(int minutes, String label) => TimerPhase(
  type: PhaseType.walk,
  durationSeconds: minutes * 60,
  label: label,
  zone: Zone.z1,
);

// Course à une zone donnée
TimerPhase _r(int seconds, Zone zone, {int? rep, int? total}) => TimerPhase(
  type: PhaseType.run,
  durationSeconds: seconds,
  label: rep != null ? 'Intervalle $rep/$total — ${zone.label}' : 'Course ${zone.label}',
  zone: zone,
  repNumber: rep,
  totalReps: total,
);

// Repos entre intervalles
TimerPhase _rest(int seconds) => TimerPhase(
  type: PhaseType.walk,
  durationSeconds: seconds,
  label: 'Repos actif',
  zone: Zone.z1,
);

// Série d'intervalles identiques
List<TimerPhase> _intervals(int count, int workSec, Zone zone, int restSec) {
  final phases = <TimerPhase>[];
  for (int i = 1; i <= count; i++) {
    phases.add(_r(workSec, zone, rep: i, total: count));
    if (i < count) phases.add(_rest(restSec));
  }
  return phases;
}

// Séance repos
Session _repos(int day, int week) => Session(
  dayIndex: day, weekNumber: week, sessionInWeek: day % 7,
  title: 'Repos', subtitle: 'Récupération passive. Ton corps se reconstruit plus fort.',
  sessionType: SessionType.repos, phases: [], pe: 1,
);

// Séance croisé
Session _croise(int day, int week, int minutes) => Session(
  dayIndex: day, weekNumber: week, sessionInWeek: day % 7,
  title: 'Croisé',
  subtitle: 'Vélo, natation, ski de fond, yoga… Activité au choix, sans impacts.',
  sessionType: SessionType.croise, pe: 2, rcLabel: '50-70%',
  phases: [_w(minutes, '$minutes\' activité croisée')],
);

// Séance récupération
Session _recup(int day, int week, int minutes) => Session(
  dayIndex: day, weekNumber: week, sessionInWeek: day % 7,
  title: 'Récupération',
  subtitle: 'Sortie courte et facile. Relance la circulation entre les séances dures.',
  sessionType: SessionType.recuperation, pe: 2, rcLabel: '50-70%',
  phases: [_r(minutes * 60, Zone.z1)],
);

// Séance renforcement
Session _renfo(int day, int week, int warmupMin, bool allExercises) => Session(
  dayIndex: day, weekNumber: week, sessionInWeek: day % 7,
  title: 'Renforcement',
  subtitle: 'Exercices au poids du corps pour prévenir les blessures.',
  sessionType: SessionType.renforcement, pe: 3, rcLabel: '50-70%',
  phases: [
    _w(warmupMin, 'Échauffement Z1'),
    const TimerPhase(type: PhaseType.walk, durationSeconds: 30, label: '💪 Chaise au mur — 30s', zone: Zone.z1),
    _rest(30),
    const TimerPhase(type: PhaseType.walk, durationSeconds: 30, label: '💪 Jumping Jacks — 30s', zone: Zone.z1),
    _rest(30),
    const TimerPhase(type: PhaseType.walk, durationSeconds: 30, label: '💪 Mountain Climber — 30s', zone: Zone.z1),
    _rest(30),
    const TimerPhase(type: PhaseType.walk, durationSeconds: 30, label: '💪 Planche sur les coudes — 30s', zone: Zone.z1),
    _rest(30),
    _w(5, 'Transition Z1'),
    const TimerPhase(type: PhaseType.walk, durationSeconds: 30, label: '💪 Squats — 30s', zone: Zone.z1),
    _rest(30),
    const TimerPhase(type: PhaseType.walk, durationSeconds: 30, label: '💪 Burpees — 30s', zone: Zone.z1),
    _rest(30),
    const TimerPhase(type: PhaseType.walk, durationSeconds: 30, label: '💪 Fentes — 30s', zone: Zone.z1),
    _rest(30),
    const TimerPhase(type: PhaseType.walk, durationSeconds: 30, label: '💪 Sauts dynamiques — 30s', zone: Zone.z1),
    _w(5, 'Retour au calme Z1'),
  ],
);

// ─── PROGRAMME SEMI-MARATHON 12 SEMAINES ────────────────────────────────────
// Day index = 41 à 124 (phase 1 = 1-40)

final List<Session> semiProgram = [

  // ══ SEMAINE 1 — Introduction ══════════════════════════════════════════════
  _repos(41, 1),

  Session(
    dayIndex: 42, weekNumber: 1, sessionInWeek: 2,
    title: 'Endurance 30\'', subtitle: 'Allure facile et conversationnelle. Prends tes repères.',
    sessionType: SessionType.endurance, pe: 2, rcLabel: '50-70%',
    phases: [_r(30 * 60, Zone.z1)],
  ),

  _renfo(43, 1, 5, false),

  Session(
    dayIndex: 44, weekNumber: 1, sessionInWeek: 4,
    title: 'Endurance 35\'', subtitle: '5 minutes de plus qu\'hier. Garde l\'allure facile.',
    sessionType: SessionType.endurance, pe: 2, rcLabel: '50-70%',
    phases: [_r(35 * 60, Zone.z1)],
  ),

  _repos(45, 1),
  _croise(46, 1, 60),

  Session(
    dayIndex: 47, weekNumber: 1, sessionInWeek: 7,
    title: 'Endurance 45\'', subtitle: 'Sortie longue de la semaine. Reste en Z1 tout du long.',
    sessionType: SessionType.endurance, pe: 3, rcLabel: '50-70%',
    phases: [_r(45 * 60, Zone.z1)],
  ),

  // ══ SEMAINE 2 — Première vitesse ══════════════════════════════════════════
  _repos(48, 2),

  Session(
    dayIndex: 49, weekNumber: 2, sessionInWeek: 2,
    title: 'Intervalles 4×30\'\'', subtitle: '4 accélérations de 30s à allure rapide (Z4). Récup 1\'.',
    sessionType: SessionType.intervalles, pe: 6, rcLabel: '50-95%',
    phases: [
      _w(15, 'Échauffement Z1'),
      ..._intervals(4, 30, Zone.z4, 60),
      _w(15, 'Retour au calme Z1'),
    ],
  ),

  _renfo(50, 2, 5, false),

  Session(
    dayIndex: 51, weekNumber: 2, sessionInWeek: 4,
    title: 'Endurance 40\'', subtitle: 'Allure Z1 — récupération active après les intervalles.',
    sessionType: SessionType.endurance, pe: 3, rcLabel: '50-70%',
    phases: [_r(40 * 60, Zone.z1)],
  ),

  _repos(52, 2),
  _croise(53, 2, 60),

  Session(
    dayIndex: 54, weekNumber: 2, sessionInWeek: 7,
    title: 'Endurance 50\'', subtitle: 'Nouvelle sortie longue — 5 minutes de progression.',
    sessionType: SessionType.endurance, pe: 3, rcLabel: '50-70%',
    phases: [_r(50 * 60, Zone.z1)],
  ),

  // ══ SEMAINE 3 — Montée en volume ══════════════════════════════════════════
  Session(
    dayIndex: 55, weekNumber: 3, sessionInWeek: 1,
    title: 'Intervalles 6×45\'\'', subtitle: '6 accélérations de 45s à allure rapide (Z4). Récup 1\'.',
    sessionType: SessionType.intervalles, pe: 6, rcLabel: '50-95%',
    phases: [
      _w(15, 'Échauffement Z1'),
      ..._intervals(6, 45, Zone.z4, 60),
      _w(10, 'Retour au calme Z1'),
    ],
  ),

  _repos(56, 3),
  _renfo(57, 3, 10, false),

  Session(
    dayIndex: 58, weekNumber: 3, sessionInWeek: 4,
    title: 'Endurance 40\'', subtitle: 'Allure Z1 facile.',
    sessionType: SessionType.endurance, pe: 3, rcLabel: '50-70%',
    phases: [_r(40 * 60, Zone.z1)],
  ),

  _repos(59, 3),
  _croise(60, 3, 60),

  Session(
    dayIndex: 61, weekNumber: 3, sessionInWeek: 7,
    title: 'Endurance mixte 45\'', subtitle: '20\' facile + 10\' à allure modérée + 15\' facile.',
    sessionType: SessionType.endurance, pe: 4, rcLabel: '50-80%',
    phases: [
      _r(20 * 60, Zone.z1),
      _r(10 * 60, Zone.z2),
      _r(15 * 60, Zone.z1),
    ],
  ),

  // ══ SEMAINE 4 — Premiers blocs longs ══════════════════════════════════════
  _repos(62, 4),

  Session(
    dayIndex: 63, weekNumber: 4, sessionInWeek: 2,
    title: 'Intervalles 2×5\'', subtitle: '2 blocs de 5 min à allure soutenue (Z3). Récup 3\'.',
    sessionType: SessionType.intervalles, pe: 6, rcLabel: '50-90%',
    phases: [
      _w(10, 'Échauffement Z1'),
      ..._intervals(2, 5 * 60, Zone.z3, 3 * 60),
      _w(10, 'Retour au calme Z1'),
    ],
  ),

  Session(
    dayIndex: 64, weekNumber: 4, sessionInWeek: 3,
    title: 'Endurance 50\'', subtitle: 'Longue sortie Z1 — profite du paysage.',
    sessionType: SessionType.endurance, pe: 3, rcLabel: '50-70%',
    phases: [_r(50 * 60, Zone.z1)],
  ),

  _repos(65, 4),
  _renfo(66, 4, 10, false),

  Session(
    dayIndex: 67, weekNumber: 4, sessionInWeek: 6,
    title: 'Endurance mixte 1h', subtitle: '30\' facile + 15\' modéré + 15\' facile.',
    sessionType: SessionType.endurance, pe: 4, rcLabel: '50-80%',
    phases: [
      _r(30 * 60, Zone.z1),
      _r(15 * 60, Zone.z2),
      _r(15 * 60, Zone.z1),
    ],
  ),

  _croise(68, 4, 60),

  // ══ SEMAINE 5 — Intensité montante ════════════════════════════════════════
  _repos(69, 5),

  Session(
    dayIndex: 70, weekNumber: 5, sessionInWeek: 2,
    title: 'Endurance 50\'', subtitle: 'Allure Z1 — sortie longue en milieu de semaine.',
    sessionType: SessionType.endurance, pe: 3, rcLabel: '50-70%',
    phases: [_r(50 * 60, Zone.z1)],
  ),

  Session(
    dayIndex: 71, weekNumber: 5, sessionInWeek: 3,
    title: 'Intervalles 2×8\'', subtitle: '2 blocs de 8 min à allure soutenue (Z3). Récup 3\'.',
    sessionType: SessionType.intervalles, pe: 7, rcLabel: '50-90%',
    phases: [
      _w(15, 'Échauffement Z1'),
      ..._intervals(2, 8 * 60, Zone.z3, 3 * 60),
      _w(10, 'Retour au calme Z1'),
    ],
  ),

  _renfo(72, 5, 10, false),
  _repos(73, 5),
  _croise(74, 5, 75),

  Session(
    dayIndex: 75, weekNumber: 5, sessionInWeek: 7,
    title: 'Endurance mixte 1h10', subtitle: '30\' facile + 20\' modéré + 20\' facile.',
    sessionType: SessionType.endurance, pe: 5, rcLabel: '50-80%',
    phases: [
      _r(30 * 60, Zone.z1),
      _r(20 * 60, Zone.z2),
      _r(20 * 60, Zone.z1),
    ],
  ),

  // ══ SEMAINE 6 — Consolidation ═════════════════════════════════════════════
  _repos(76, 6),

  Session(
    dayIndex: 77, weekNumber: 6, sessionInWeek: 2,
    title: 'Intervalles 3×6\'', subtitle: '3 blocs de 6 min à allure soutenue (Z3). Récup 3\'.',
    sessionType: SessionType.intervalles, pe: 7, rcLabel: '50-80%',
    phases: [
      _w(15, 'Échauffement Z1'),
      ..._intervals(3, 6 * 60, Zone.z3, 3 * 60),
      _w(10, 'Retour au calme Z1'),
    ],
  ),

  _renfo(78, 6, 10, true),

  Session(
    dayIndex: 79, weekNumber: 6, sessionInWeek: 4,
    title: 'Endurance 50\'', subtitle: 'Récupération active après les intervalles d\'hier.',
    sessionType: SessionType.endurance, pe: 2, rcLabel: '50-70%',
    phases: [_r(50 * 60, Zone.z1)],
  ),

  _repos(80, 6),
  _croise(81, 6, 75),

  Session(
    dayIndex: 82, weekNumber: 6, sessionInWeek: 7,
    title: 'Endurance mixte 1h15', subtitle: '35\' facile + 25\' modéré + 15\' facile.',
    sessionType: SessionType.endurance, pe: 5, rcLabel: '50-80%',
    phases: [
      _r(35 * 60, Zone.z1),
      _r(25 * 60, Zone.z2),
      _r(15 * 60, Zone.z1),
    ],
  ),

  // ══ SEMAINE 7 — Vitesse et endurance ══════════════════════════════════════
  Session(
    dayIndex: 83, weekNumber: 7, sessionInWeek: 1,
    title: 'Intervalles mixtes 45\'', subtitle: '3×2\' @Z3 puis 2×2\' @Z4 — alternance d\'allures.',
    sessionType: SessionType.intervalles, pe: 6, rcLabel: '50-95%',
    phases: [
      _w(15, 'Échauffement Z1'),
      ..._intervals(3, 2 * 60, Zone.z3, 2 * 60),
      ..._intervals(2, 2 * 60, Zone.z4, 2 * 60),
      _w(10, 'Retour au calme Z1'),
    ],
  ),

  _repos(84, 7),
  _renfo(85, 7, 10, true),

  Session(
    dayIndex: 86, weekNumber: 7, sessionInWeek: 4,
    title: 'Endurance 50\'', subtitle: 'Allure Z1 stable.',
    sessionType: SessionType.endurance, pe: 3, rcLabel: '50-70%',
    phases: [_r(50 * 60, Zone.z1)],
  ),

  _croise(87, 7, 75),
  _repos(88, 7),

  Session(
    dayIndex: 89, weekNumber: 7, sessionInWeek: 7,
    title: 'Endurance mixte 1h25', subtitle: '25\' + 15\' Z2 + 10\' Z1 + 15\' Z2 + 20\' Z1.',
    sessionType: SessionType.endurance, pe: 6, rcLabel: '50-80%',
    phases: [
      _r(25 * 60, Zone.z1),
      _r(15 * 60, Zone.z2),
      _r(10 * 60, Zone.z1),
      _r(15 * 60, Zone.z2),
      _r(20 * 60, Zone.z1),
    ],
  ),

  // ══ SEMAINE 8 — Point culminant volume ════════════════════════════════════
  Session(
    dayIndex: 90, weekNumber: 8, sessionInWeek: 1,
    title: 'Endurance 50\'', subtitle: 'Allure Z1 — début de semaine chargée.',
    sessionType: SessionType.endurance, pe: 2, rcLabel: '50-70%',
    phases: [_r(50 * 60, Zone.z1)],
  ),

  Session(
    dayIndex: 91, weekNumber: 8, sessionInWeek: 2,
    title: 'Intervalles vitesse', subtitle: '3\' @Z4 + 2\' @Z4 + 1\' @Z5 — progression d\'intensité.',
    sessionType: SessionType.intervalles, pe: 6, rcLabel: '50-100%',
    phases: [
      _w(15, 'Échauffement Z1'),
      _r(3 * 60, Zone.z4, rep: 1, total: 3),
      _rest(2 * 60),
      _r(2 * 60, Zone.z4, rep: 2, total: 3),
      _rest(2 * 60),
      _r(1 * 60, Zone.z5, rep: 3, total: 3),
      _w(15, 'Retour au calme Z1'),
    ],
  ),

  _renfo(92, 8, 10, true),
  _recup(93, 8, 25),
  _repos(94, 8),
  _croise(95, 8, 75),

  Session(
    dayIndex: 96, weekNumber: 8, sessionInWeek: 7,
    title: 'Endurance mixte 1h30', subtitle: '30\' + 30\' @Z2 + 30\' Z1 — la plus longue sortie.',
    sessionType: SessionType.endurance, pe: 6, rcLabel: '50-80%',
    phases: [
      _r(30 * 60, Zone.z1),
      _r(30 * 60, Zone.z2),
      _r(30 * 60, Zone.z1),
    ],
  ),

  // ══ SEMAINE 9 — Spécificité ═══════════════════════════════════════════════
  Session(
    dayIndex: 97, weekNumber: 9, sessionInWeek: 1,
    title: 'Intervalles 3×8\' @Z2', subtitle: '3 longs blocs à allure modérée. Récup 3\'.',
    sessionType: SessionType.intervalles, pe: 6, rcLabel: '50-80%',
    phases: [
      _w(10, 'Échauffement Z1'),
      ..._intervals(3, 8 * 60, Zone.z2, 3 * 60),
      _w(10, 'Retour au calme Z1'),
    ],
  ),

  _recup(98, 9, 25),
  _renfo(99, 9, 10, true),

  Session(
    dayIndex: 100, weekNumber: 9, sessionInWeek: 4,
    title: 'Endurance 50\'', subtitle: 'Allure Z1.',
    sessionType: SessionType.endurance, pe: 3, rcLabel: '50-70%',
    phases: [_r(50 * 60, Zone.z1)],
  ),

  _repos(101, 9),
  _croise(102, 9, 75),

  Session(
    dayIndex: 103, weekNumber: 9, sessionInWeek: 7,
    title: 'Endurance mixte 1h40', subtitle: '30\' + 20\' Z2 + 10\' + 20\' Z2 + 20\' — préparation finale.',
    sessionType: SessionType.endurance, pe: 6, rcLabel: '50-80%',
    phases: [
      _r(30 * 60, Zone.z1),
      _r(20 * 60, Zone.z2),
      _r(10 * 60, Zone.z1),
      _r(20 * 60, Zone.z2),
      _r(20 * 60, Zone.z1),
    ],
  ),

  // ══ SEMAINE 10 — Affûtage ═════════════════════════════════════════════════
  _recup(104, 10, 25),

  Session(
    dayIndex: 105, weekNumber: 10, sessionInWeek: 2,
    title: 'Intervalles 3×10\' @Z2', subtitle: '3 blocs longs à allure de course. Récup 3\'.',
    sessionType: SessionType.intervalles, pe: 7, rcLabel: '50-80%',
    phases: [
      _w(10, 'Échauffement Z1'),
      ..._intervals(3, 10 * 60, Zone.z2, 3 * 60),
      _w(10, 'Retour au calme Z1'),
    ],
  ),

  _renfo(106, 10, 10, true),
  _repos(107, 10),

  Session(
    dayIndex: 108, weekNumber: 10, sessionInWeek: 5,
    title: 'Endurance 50\'', subtitle: 'Dernière longue sortie avant l\'affûtage final.',
    sessionType: SessionType.endurance, pe: 3, rcLabel: '50-70%',
    phases: [_r(50 * 60, Zone.z1)],
  ),

  _croise(109, 10, 75),

  Session(
    dayIndex: 110, weekNumber: 10, sessionInWeek: 7,
    title: 'Endurance mixte 1h45', subtitle: '40\' + 40\' @Z2 + 25\' — le sommet du programme.',
    sessionType: SessionType.endurance, pe: 6, rcLabel: '50-80%',
    phases: [
      _r(40 * 60, Zone.z1),
      _r(40 * 60, Zone.z2),
      _r(25 * 60, Zone.z1),
    ],
  ),

  // ══ SEMAINE 11 — Affûtage final ═══════════════════════════════════════════
  _repos(111, 11),

  Session(
    dayIndex: 112, weekNumber: 11, sessionInWeek: 2,
    title: 'Intervalles vitesse 30\'', subtitle: '3\' + 2\' + 1\' @Z4/Z5 — sharpener avant la course.',
    sessionType: SessionType.intervalles, pe: 7, rcLabel: '50-100%',
    phases: [
      _w(10, 'Échauffement Z1'),
      _r(3 * 60, Zone.z4, rep: 1, total: 3),
      _rest(2 * 60),
      _r(2 * 60, Zone.z4, rep: 2, total: 3),
      _rest(2 * 60),
      _r(1 * 60, Zone.z5, rep: 3, total: 3),
      _w(10, 'Retour au calme Z1'),
    ],
  ),

  _renfo(113, 11, 10, true),

  Session(
    dayIndex: 114, weekNumber: 11, sessionInWeek: 4,
    title: 'Endurance 30\'', subtitle: 'Sortie courte et facile. Tu préserves ton énergie.',
    sessionType: SessionType.endurance, pe: 2, rcLabel: '50-70%',
    phases: [_r(30 * 60, Zone.z1)],
  ),

  _repos(115, 11),
  _recup(116, 11, 25),

  Session(
    dayIndex: 117, weekNumber: 11, sessionInWeek: 7,
    title: 'Endurance mixte 50\'', subtitle: '15\' + 20\' @Z2 + 15\' — maintien de la forme.',
    sessionType: SessionType.endurance, pe: 4, rcLabel: '50-80%',
    phases: [
      _r(15 * 60, Zone.z1),
      _r(20 * 60, Zone.z2),
      _r(15 * 60, Zone.z1),
    ],
  ),

  // ══ SEMAINE 12 — Race week ════════════════════════════════════════════════
  _repos(118, 12),

  Session(
    dayIndex: 119, weekNumber: 12, sessionInWeek: 2,
    title: 'Activation 28\'', subtitle: '3×2\' + 2×1\' vites — réveille les jambes avant la course.',
    sessionType: SessionType.intervalles, pe: 7, rcLabel: '50-100%',
    phases: [
      _w(5, 'Échauffement Z1'),
      ..._intervals(3, 2 * 60, Zone.z4, 2 * 60),
      ..._intervals(2, 60, Zone.z5, 2 * 60),
      _w(5, 'Retour au calme Z1'),
    ],
  ),

  _repos(120, 12),
  _recup(121, 12, 20),
  _repos(122, 12),
  _recup(123, 12, 15),

  Session(
    dayIndex: 124, weekNumber: 12, sessionInWeek: 7,
    title: '🏁 Semi-Marathon 21.1 km', subtitle: 'Le jour J. Tout le travail des 12 semaines pour ça.',
    sessionType: SessionType.competition, pe: 10, rcLabel: '50-100%',
    phases: [
      _r(21 * 60 + 6 * 60, Zone.z3), // ~1h45-2h pour un semi, estimation
    ],
  ),
];
