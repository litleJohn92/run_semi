import '../models/workout.dart';

// Raccourci pour les chemins d'images
const _img = 'assets/exercises/';

/// Programme Iron Jo — 7 jours kettlebell (utilisé comme réservoir d'exercices
/// par `mixedWorkoutForDay`, voir plus bas).
final List<DayWorkout> strengthProgram = _ironJoWeek();

/// Mix haut + bas du corps + gainage, déterministe selon le jour du programme
/// de course (`dayIndex`). Seule source utilisée pour choisir le renforcement
/// du jour — à la fois dans l'aperçu de l'onglet Programme et dans la séance
/// réellement lancée depuis Aujourd'hui — pour qu'elles ne divergent jamais.
DayWorkout mixedWorkoutForDay(int dayIndex) {
  if (strengthProgram.length < 4) {
    return const DayWorkout(weekNumber: 1, dayOfWeek: 1, title: 'Renforcement', subtitle: '');
  }
  final lowerBlock = strengthProgram[1].blocks.first;
  final upperBlocks = strengthProgram[3].blocks;
  final upperBlock = upperBlocks.first;
  final coreBlock = upperBlocks.length > 1 ? upperBlocks[1] : null;

  return DayWorkout(
    weekNumber: 1,
    dayOfWeek: 1,
    title: 'Mix Haut + Bas du corps',
    subtitle: 'Renforcement du jour : jambes, haut du corps et gainage.',
    blocks: [
      WorkoutBlock(
        title: lowerBlock.title,
        rounds: lowerBlock.rounds,
        exercises: _rotatedPick(lowerBlock.exercises, dayIndex, 2),
      ),
      WorkoutBlock(
        title: upperBlock.title,
        rounds: upperBlock.rounds,
        exercises: _rotatedPick(upperBlock.exercises, dayIndex, 2),
      ),
      if (coreBlock != null)
        WorkoutBlock(
          title: coreBlock.title,
          rounds: coreBlock.rounds,
          exercises: _rotatedPick(coreBlock.exercises, dayIndex, 2),
        ),
    ],
  );
}

List<Exercise> _rotatedPick(List<Exercise> pool, int offset, int count) {
  if (pool.isEmpty) return const [];
  final n = pool.length;
  return List.generate(count.clamp(0, n), (i) => pool[(offset + i) % n]);
}

List<DayWorkout> _ironJoWeek() => [
      // ─── JOUR 1 — Full Body en Douceur ─────────────────────────
      const DayWorkout(
        weekNumber: 1,
        dayOfWeek: 2, // Mardi
        title: 'Full Body en Douceur',
        subtitle: 'Prendre confiance avec la KB et sentir tout le corps travailler.',
        blocks: [
          WorkoutBlock(
            title: 'Full Body · Découverte',
            rounds: 3,
            exercises: [
              Exercise(
                name: 'Goblet Squats',
                description: 'KB contre la poitrine. Descends les fesses sous les genoux, genoux dans l\'axe des pieds.',
                tip: 'Ce sont les jambes qui poussent — pas le dos qui tire.',
                imagePath: '${_img}goblet_squat.png',
              ),
              Exercise(
                name: 'Swings',
                description: 'Pieds écartés, explosion des hanches vers l\'avant. Claque les fessiers en haut.',
                tip: 'C\'est les fessiers qui terminent le mouvement, pas les bras.',
                imagePath: '${_img}swing.png',
              ),
              Exercise(
                name: 'Halos',
                description: 'La KB tourne autour de la tête, lent et contrôlé. Déverrouille les épaules et la nuque.',
                tip: 'Reste bien gainé tout au long du mouvement.',
                imagePath: '${_img}halo.png',
              ),
              Exercise(
                name: 'Romanian Deadlifts',
                description: 'Jambes presque tendues. Tu pousses les fesses en arrière en descendant.',
                tip: 'Sens les ischios s\'étirer à chaque descente.',
                imagePath: '${_img}romanian_deadlift.png',
              ),
            ],
          ),
        ],
      ),

      // ─── JOUR 2 — Jambes & Fessiers ────────────────────────────
      const DayWorkout(
        weekNumber: 1,
        dayOfWeek: 4, // Jeudi
        title: 'Jambes & Fessiers',
        subtitle: 'Brûler les jambes et construire des fessiers solides.',
        blocks: [
          WorkoutBlock(
            title: 'Bas du corps',
            rounds: 4,
            exercises: [
              Exercise(
                name: 'Swings',
                description: 'Laisse la KB descendre bas entre les jambes. Plus tu vas bas, plus tu génères de puissance.',
                tip: 'Pense à claquer les fessiers en haut.',
                imagePath: '${_img}swing.png',
              ),
              Exercise(
                name: 'Goblet Squats',
                description: 'Coudes pointés vers le bas, KB haute contre la poitrine. Cette position t\'empêche de t\'effondrer.',
                tip: 'Garde les talons au sol, pousse les genoux vers l\'extérieur.',
                imagePath: '${_img}goblet_squat.png',
              ),
              Exercise(
                name: 'Fentes Arrière',
                description: 'Genou arrière proche du sol, buste droit. Pousse fort sur le talon avant pour remonter. 8 par jambe.',
                tip: 'Le genou avant ne dépasse pas le bout du pied.',
                imagePath: '${_img}fente_arriere.png',
              ),
              Exercise(
                name: 'Cossack Squats',
                description: 'Descends sur une jambe, l\'autre reste tendue sur le côté. Prends ton temps.',
                tip: 'C\'est autant de la mobilité que de la force.',
                imagePath: '${_img}cossack_squat.png',
              ),
            ],
          ),
        ],
      ),

      // ─── JOUR 3 — Récupération active ──────────────────────────
      const DayWorkout(
        weekNumber: 1,
        dayOfWeek: 3,
        title: 'Repos actif & Mobilité',
        subtitle: 'Récupérer intelligemment pour mieux performer demain.',
        blocks: [
          WorkoutBlock(
            title: 'Routine douce',
            rounds: 1,
            exercises: [
              Exercise(
                name: 'Halos',
                description: 'KB légère ou même sans charge. Déverrouille les épaules et la nuque, lentement.',
                durationSeconds: 40,
                restSeconds: 20,
                imagePath: '${_img}halo.png',
              ),
              Exercise(
                name: 'Rotations des Hanches',
                description: '10 de chaque côté. Dessine de grands cercles avec le bassin pour libérer les hanches.',
                durationSeconds: 40,
                restSeconds: 20,
                imagePath: '${_img}rotation_hanches.png',
              ),
              Exercise(
                name: 'Étirement des Ischios',
                description: '30 secondes par jambe. Penche-toi doucement vers l\'avant, dos long. Sans à-coups.',
                durationSeconds: 60,
                restSeconds: 15,
                imagePath: '${_img}etirement_ischios.png',
              ),
              Exercise(
                name: 'Respiration Profonde',
                description: 'Cohérence cardiaque : inspire 5 secondes, expire 5 secondes. Calme le système nerveux.',
                durationSeconds: 120,
                restSeconds: 0,
                imagePath: '${_img}respiration.png',
              ),
            ],
          ),
        ],
      ),

      // ─── JOUR 4 — Haut du corps ────────────────────────────────
      const DayWorkout(
        weekNumber: 1,
        dayOfWeek: 4,
        title: 'Épaules, Bras & Gainage',
        subtitle: 'Renforcer les épaules, les bras et le gainage en profondeur.',
        blocks: [
          WorkoutBlock(
            title: 'Haut du corps',
            rounds: 4,
            exercises: [
              Exercise(
                name: 'Around the World',
                description: '5 dans chaque sens. Buste droit, hanches fixes. C\'est toi qui contrôles la KB.',
                tip: 'Épaules et gainage allumés en permanence.',
                imagePath: '${_img}around_the_world.png',
              ),
              Exercise(
                name: 'Halos',
                description: '5 dans chaque sens. KB serrée près de la tête, coudes qui guident.',
                tip: 'Mobilité des épaules et de la nuque.',
                imagePath: '${_img}halo.png',
              ),
              Exercise(
                name: 'Curl Biceps',
                description: 'Coudes collés contre le corps, ils ne bougent pas. Monte lentement, redescends encore plus lentement.',
                tip: 'La lenteur sur la descente = deux fois plus de résultats.',
                imagePath: '${_img}curl_biceps.png',
              ),
              Exercise(
                name: 'Extensions Triceps',
                description: 'KB derrière la tête, coudes fixes vers le haut. Les triceps font les deux tiers du bras.',
                tip: 'Garde les coudes pointés vers le plafond.',
                imagePath: '${_img}extension_triceps.png',
              ),
            ],
          ),
          // Circuit abdos/gainage complet (7 exercices), source : sport-equipements.fr/meilleurs-exercices-abdos-kettlebell
          WorkoutBlock(
            title: 'Gainage & Abdos (Kettlebell)',
            rounds: 3,
            exercises: [
              Exercise(
                name: 'Marche du Fermier',
                description: 'KB lourde dans une main, bras le long du corps, torse droit. Marche lentement sans fléchir la colonne du côté chargé, puis change de main.',
                tip: 'Contracte les abdos pour empêcher le buste de s\'incliner vers le poids.',
                durationSeconds: 40,
              ),
              Exercise(
                name: 'Front Rack March',
                description: 'Une KB (ou deux) en position rack contre la poitrine, coudes rentrés. Lève un genou au-dessus de la hanche, marque une pause, repose, puis change de jambe.',
                tip: 'Pointe les orteils du pied levé vers le plafond et garde le buste bien droit.',
                durationSeconds: 40,
              ),
              Exercise(
                name: 'Turkish Get Up',
                description: 'Allongé au sol, KB tendue au-dessus de l\'épaule. Relève-toi progressivement jusqu\'à être debout, en gardant le bras toujours tendu et le regard sur la KB.',
                tip: 'Mouvement lent et contrôlé — c\'est la qualité qui compte, pas la vitesse.',
                durationSeconds: 45,
              ),
              Exercise(
                name: 'Moulin à Vent',
                description: 'KB tendue au-dessus de la tête dans une main, bras opposé tendu sur le côté. Plie-toi aux hanches pour toucher ton pied avec la main libre, bras chargé toujours verrouillé.',
                tip: 'Tempo lent (5 secondes à la descente) et ne quitte jamais la KB des yeux.',
                durationSeconds: 40,
              ),
              Exercise(
                name: 'Plank Through',
                description: 'Position de planche haute, KB posée d\'un côté. Va la chercher de la main opposée pour la faire passer de l\'autre côté, en gainant fort les obliques.',
                tip: 'Garde le corps le plus centré possible pendant le transfert.',
                durationSeconds: 40,
              ),
              Exercise(
                name: 'Kettlebell Dead Bug',
                description: 'Allongé au sol, bas du dos plaqué au sol, KB tendue à deux mains au-dessus de la tête, genoux pliés à 90°. Étends une jambe, puis l\'autre, sans jamais décoller le bas du dos.',
                tip: 'Si le bas du dos se creuse, réduis l\'amplitude de la jambe.',
                durationSeconds: 40,
              ),
              Exercise(
                name: 'Renegade Row',
                description: 'Position de planche, une KB dans chaque main. Tire une KB vers la hanche sans faire basculer le bassin, repose, puis change de côté.',
                tip: 'Écarte les pieds pour plus de stabilité si besoin.',
                durationSeconds: 40,
              ),
            ],
          ),
        ],
      ),

      // ─── JOUR 5 — Cardio & Explosivité ─────────────────────────
      const DayWorkout(
        weekNumber: 1,
        dayOfWeek: 5,
        title: 'Cardio & Explosivité',
        subtitle: 'Exploser le cardio et gagner en explosivité. AMRAP 20 min.',
        blocks: [
          WorkoutBlock(
            title: 'AMRAP 20 min',
            rounds: 5, // Estimation
            exercises: [
              Exercise(
                name: 'Swings',
                description: 'Pense à claquer les fessiers en haut. C\'est eux qui terminent le mouvement.',
                tip: 'Pas les épaules — les fessiers.',
                imagePath: '${_img}swing.png',
              ),
              Exercise(
                name: 'Goblet Thrusters',
                description: 'Descends en squat, puis pousse la KB au-dessus de la tête en remontant, d\'un seul élan.',
                tip: 'Expire fort en haut.',
                imagePath: '${_img}goblet_thruster.png',
              ),
              Exercise(
                name: 'High Knees',
                description: 'Sans KB. Genoux le plus haut possible, bras qui pompent.',
                tip: 'C\'est le finish qui fait la différence. Gère ton souffle.',
                imagePath: '${_img}high_knees.png',
              ),
            ],
          ),
        ],
      ),

      // ─── JOUR 6 — Full Body Challenge ──────────────────────────
      const DayWorkout(
        weekNumber: 1,
        dayOfWeek: 6,
        title: 'Full Body Challenge',
        subtitle: 'Tout travailler avec un seul bras à la fois. 5 rounds.',
        blocks: [
          WorkoutBlock(
            title: 'Unilatéral',
            rounds: 5,
            exercises: [
              Exercise(
                name: 'Swings 1 bras',
                description: 'Laisse la KB balancer naturellement. C\'est le rebond des hanches qui crée la puissance.',
                tip: 'Échange de mains au sommet de l\'arc.',
                imagePath: '${_img}swing_1bras.png',
              ),
              Exercise(
                name: 'Clean & Press',
                description: 'Tu soulèves la KB, tu la reçois à l\'épaule, puis tu presses vers le haut — un seul mouvement fluide.',
                tip: 'La KB doit "flotter" jusqu\'à l\'épaule, pas claquer.',
                imagePath: '${_img}clean_press.png',
              ),
              Exercise(
                name: 'Squats en Rack',
                description: 'KB calée à l\'épaule en position rack. Descends proprement. Genoux dans l\'axe, dos droit.',
                tip: 'Le coude doit rester collé au corps.',
                imagePath: '${_img}squat_rack.png',
              ),
              Exercise(
                name: 'Rowings',
                description: 'Tire la KB vers la hanche. Sens les omoplates se rapprocher en haut du mouvement.',
                tip: 'Dos plat, tête dans l\'axe.',
                imagePath: '${_img}rowing.png',
              ),
            ],
          ),
        ],
      ),

      // ─── JOUR 7 — Le Défi Final ─────────────────────────────────
      const DayWorkout(
        weekNumber: 1,
        dayOfWeek: 7,
        title: 'Le Défi Final',
        subtitle: 'Tout donner et mesurer ta progression. FOR TIME.',
        blocks: [
          WorkoutBlock(
            title: 'For Time',
            rounds: 1,
            exercises: [
              Exercise(
                name: '50 Swings',
                description: 'Claque les fessiers en haut, laisse la KB descendre bas. Garde le rythme, respire.',
                durationSeconds: 90,
                tip: 'Respiration rythmée : expire à chaque montée.',
                imagePath: '${_img}swing.png',
              ),
              Exercise(
                name: '30 Goblet Squats',
                description: 'Descends profond, genoux dans l\'axe. Chaque rep compte.',
                durationSeconds: 60,
                imagePath: '${_img}goblet_squat.png',
              ),
              Exercise(
                name: '20 Push Press',
                description: 'Légère impulsion des jambes pour lancer la KB au-dessus de la tête. Expire fort en haut.',
                tip: 'Les épaules finissent le travail.',
                imagePath: '${_img}push_press.png',
              ),
              Exercise(
                name: 'Rowings 10/bras',
                description: 'Dos plat, tire vers la hanche. C\'est le dos qui travaille, pas les bras.',
                durationSeconds: 45,
                imagePath: '${_img}rowing.png',
              ),
            ],
          ),
        ],
      ),
    ];
