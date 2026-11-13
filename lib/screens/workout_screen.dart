import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/workout.dart';
import '../models/session.dart';
import '../services/gps_service.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class WorkoutScreen extends StatefulWidget {
  final DayWorkout workout;
  const WorkoutScreen({super.key, required this.workout});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> with WidgetsBindingObserver {
  late FlutterTts _tts;
  final GpsService _gps = GpsService();
  int _blockIndex = 0;
  int _exerciseIndex = 0;
  int _round = 1;
  int _remaining = 0;
  bool _isRest = false;
  bool _started = false;
  bool _paused = false;
  bool _gpsActive = false;
  bool _showingPreview = true;
  Timer? _timer;
  DateTime? _phaseStartTime; // Pour recalculer après verrouillage

  static const Color _cardDark = AppTheme.surfaceCard;
  static const Color _accent   = AppTheme.accentPrimary;
  static const Color _green    = AppTheme.statusSuccess;
  static const Color _yellow   = AppTheme.statusWarning;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.workout.blocks.isNotEmpty) {
      _remaining = _currentExercise.durationSeconds;
    }
    _initTts();
  }

  Future<void> _initTts() async {
    _tts = FlutterTts();
    await _tts.setLanguage('fr-FR');
    await _tts.setSpeechRate(0.45);
    // Catégorie/activation audio gérées uniquement au moment de parler (voir
    // _speak) : activer la session trop tôt avec la catégorie par défaut
    // coupait Spotify au lieu de simplement le "ducker".
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _started && !_paused) {
      _syncWithRealTime();
    }
  }

  void _syncWithRealTime() {
    if (_phaseStartTime == null) return;
    _timer?.cancel();
    final elapsed = DateTime.now().difference(_phaseStartTime!).inSeconds;
    final phaseDuration = _isRest ? _currentExercise.restSeconds : _currentExercise.durationSeconds;
    final newRemaining = phaseDuration - elapsed;
    if (newRemaining <= 0) {
      setState(() => _remaining = 0);
      _advance();
    } else {
      setState(() => _remaining = newRemaining);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  WorkoutBlock get _currentBlock => widget.workout.blocks[_blockIndex];
  Exercise    get _currentExercise => _currentBlock.exercises[_exerciseIndex];
  bool        get _isFinished => _blockIndex >= widget.workout.blocks.length;

  Exercise? get _nextExercise {
    if (_exerciseIndex + 1 < _currentBlock.exercises.length) {
      return _currentBlock.exercises[_exerciseIndex + 1];
    }
    return null;
  }

  void _start() {
    if (!_started) {
      _gps.startRecording().then((_) {
        if (mounted) setState(() => _gpsActive = _gps.isRecording);
      });
    } else {
      _gps.resume();
    }
    setState(() { _started = true; _paused = false; });
    _phaseStartTime = DateTime.now();
    _speak(_isRest ? 'Repos' : _currentExercise.name);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    setState(() => _remaining--);
    if (_remaining == 3 && !_isRest) {
      final next = _nextLabel();
      if (next != null) _speak('Prêt pour $next');
    }
    if (_remaining <= 0) _advance();
  }

  void _advance() {
    _timer?.cancel();
    if (_isRest) {
      setState(() {
        _isRest = false;
        _exerciseIndex++;
        if (_exerciseIndex >= _currentBlock.exercises.length) {
          if (_round < _currentBlock.rounds) {
            _round++;
            _exerciseIndex = 0;
            _remaining = _currentBlock.exercises[0].durationSeconds;
            _speak('Round $_round — ${_currentBlock.exercises[0].name}');
          } else {
            _blockIndex++;
            if (_blockIndex >= widget.workout.blocks.length) { _finish(); return; }
            _exerciseIndex = 0;
            _round = 1;
            _remaining = _currentBlock.exercises[0].durationSeconds;
            _speak(_currentBlock.exercises[0].name);
          }
        } else {
          _remaining = _currentExercise.durationSeconds;
          _speak(_currentExercise.name);
        }
      });
    } else {
      setState(() { _isRest = true; _remaining = _currentExercise.restSeconds; });
      _speak('Repos');
    }
    _phaseStartTime = DateTime.now();
    if (!_isFinished) _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _finish() {
    _gps.stopRecording();
    _speak('Bravo ! Renforcement terminé !');
    double volumeKg = 0;
    for (final block in widget.workout.blocks) {
      for (final ex in block.exercises) {
        final reps = (ex.durationSeconds / 3.0).round().clamp(5, 20);
        volumeKg += reps * block.rounds * 8.0;
      }
    }
    StorageService.saveWorkoutLog(WorkoutLog(
      date: DateTime.now(),
      estimatedVolumeKg: volumeKg,
      durationMinutes: widget.workout.totalMinutes,
      sessionTitle: widget.workout.title,
    ));
    NotificationService.cancelReminder(NotificationService.kbReminderId);
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: _cardDark,
        title: Text('Séance terminée !', style: AppTheme.h4.copyWith(color: AppTheme.textPrimary)),
        content: const Text('Bien joué. Récupère bien.', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [TextButton(
          onPressed: () { Navigator.pop(context); Navigator.pop(context); },
          child: const Text('Fermer', style: TextStyle(color: AppTheme.accentHighlight)),
        )],
      ),
    );
  }

  void _pause() { _timer?.cancel(); _gps.pause(); setState(() => _paused = true); }

  String? _nextLabel() {
    if (_isRest) return null;
    final next = _exerciseIndex + 1;
    if (next < _currentBlock.exercises.length) return _currentBlock.exercises[next].name;
    if (_round < _currentBlock.rounds) return 'Round ${_round + 1}';
    return null;
  }

  Future<void> _speak(String t) async {
    // Active le duck juste avant de parler — ne coupe pas Spotify au démarrage
    await _tts.setIosAudioCategory(
      IosTextToSpeechAudioCategory.playback,
      [
        IosTextToSpeechAudioCategoryOptions.duckOthers,
        IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
      ],
      IosTextToSpeechAudioMode.spokenAudio,
    );
    // Active la session maintenant pour que duckOthers prenne effet ; le plugin la désactive en fin d'énoncé (la musique reprend).
    await _tts.setSharedInstance(true);
    // Pas de stop() ici : ça annule l'énoncé précédent via didCancel et
    // empêche flutter_tts de désactiver la session (donc la musique ne reprend jamais)
    await _tts.speak(t);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _tts.stop();
    super.dispose();
  }

  String get _timeLabel {
    final m = _remaining ~/ 60;
    final s = _remaining % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  // ─── ÉCRAN PREVIEW ─────────────────────────────────────────────────────────
  // Liste TOUS les blocs (pas seulement le premier) pour que l'aperçu
  // corresponde exactement à ce qui est affiché dans la popup Programme.
  Widget _buildPreview() {
    final blocks = widget.workout.blocks;
    final totalExercises = blocks.fold(0, (s, b) => s + b.exercises.length);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.textPrimary.withValues(alpha: 0.06), shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: AppTheme.textSecondary, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(widget.workout.title,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600))),
            ]),
          ),

          if (blocks.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Container(
                decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  _InfoChip(icon: Icons.layers, label: '${blocks.length} blocs'),
                  const SizedBox(width: 16),
                  _InfoChip(icon: Icons.fitness_center, label: '$totalExercises exercices'),
                  const SizedBox(width: 16),
                  _InfoChip(icon: Icons.timer_outlined, label: '~${widget.workout.totalMinutes} min'),
                ]),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: blocks.length,
                itemBuilder: (ctx, bIdx) {
                  final block = blocks[bIdx];
                  final offset = blocks.take(bIdx).fold(0, (s, b) => s + b.exercises.length);
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (bIdx > 0) const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('${block.title} · ${block.rounds} rounds',
                          style: Theme.of(context).textTheme.bodySmall!.copyWith(
                              color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                    ),
                    ...block.exercises.asMap().entries.map((e) =>
                        _ExercisePreviewCard(index: offset + e.key, exercise: e.value)),
                  ]);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: GestureDetector(
                onTap: () => setState(() => _showingPreview = false),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(14)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.play_arrow, color: AppTheme.textPrimary, size: 22),
                    const SizedBox(width: 8),
                    Text('Démarrer le circuit',
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  // ─── ÉCRAN TIMER ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_showingPreview) return _buildPreview();
    if (widget.workout.blocks.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: Center(child: Text(widget.workout.subtitle,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center)),
      );
    }

    final color = _isRest ? AppTheme.statusInfo : AppTheme.accentHighlight;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.textPrimary.withValues(alpha: 0.06), shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: AppTheme.textSecondary, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.workout.title,
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(color: AppTheme.textSecondary)),
                Text('Round $_round/${_currentBlock.rounds}',
                    style: Theme.of(context).textTheme.labelSmall!.copyWith(color: AppTheme.textMuted)),
              ])),
            ]),
          ),

          // GPS
          if (_started)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(children: [
                Container(width: 6, height: 6,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                        color: _gpsActive ? _green : _yellow)),
                const SizedBox(width: 6),
                Text(_gpsActive ? 'GPS actif' : 'GPS en attente…',
                    style: Theme.of(context).textTheme.labelSmall!.copyWith(
                        color: _gpsActive ? _green : _yellow)),
              ]),
            ),

          // Badge + dots
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _started ? (_isRest ? 'REPOS' : 'EXERCICE') : 'PRÊT',
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(color: color,
                      fontWeight: FontWeight.w600, letterSpacing: 1),
                ),
              ),
              Row(children: List.generate(_currentBlock.exercises.length, (i) {
                Color c;
                if (!_started) {
                  c = AppTheme.surfaceRaised;
                } else if (i < _exerciseIndex) c = AppTheme.accentHighlight;
                else if (i == _exerciseIndex) c = AppTheme.textPrimary;
                else c = AppTheme.surfaceRaised;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 16, height: 4,
                  decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
                );
              })),
            ]),
          ),

          // Corps scrollable
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: [
                // Timer cercle
                const SizedBox(height: 8),
                SizedBox(
                  width: 140, height: 140,
                  child: Stack(alignment: Alignment.center, children: [
                    const SizedBox.expand(child: CircularProgressIndicator(
                        value: 1.0, strokeWidth: 8, color: AppTheme.surfaceRaised)),
                    SizedBox.expand(child: CircularProgressIndicator(
                      value: _started ? ((_isRest
                          ? _currentExercise.restSeconds - _remaining
                          : _currentExercise.durationSeconds - _remaining) /
                          (_isRest ? _currentExercise.restSeconds : _currentExercise.durationSeconds)) : 0,
                      strokeWidth: 8, color: color, strokeCap: StrokeCap.round,
                    )),
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_started ? _timeLabel : '--:--',
                          style: Theme.of(context).textTheme.displaySmall!.copyWith(
                              fontWeight: FontWeight.w300, color: AppTheme.textPrimary)),
                      Text(_isRest ? 'repos' : 'travail',
                          style: Theme.of(context).textTheme.labelSmall!.copyWith(color: AppTheme.textMuted)),
                    ]),
                  ]),
                ),
                const SizedBox(height: 14),

                // Carte exercice OU carte repos avec prochain exercice
                if (!_isRest && !_isFinished) ...[
                  _ExerciseTimerCard(index: _exerciseIndex, exercise: _currentExercise, color: color),
                  if (_nextLabel() != null) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(children: [
                        Text('ensuite  ·  ', style: Theme.of(context).textTheme.bodySmall!.copyWith(color: AppTheme.textMuted)),
                        Text(_nextLabel()!,
                            style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w500,
                                color: AppTheme.textSecondary)),
                      ]),
                    ),
                  ],
                ] else if (_isRest) ...[
                  // Repos : affiche le prochain exercice avec son image
                  Container(
                    decoration: BoxDecoration(
                      color: _cardDark, borderRadius: BorderRadius.circular(14)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Label repos
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.statusInfo.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.statusInfo.withValues(alpha: 0.3)),
                            ),
                            child: Text('Récupération',
                                style: Theme.of(context).textTheme.bodySmall!.copyWith(color: AppTheme.statusInfo,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ]),
                      ),

                      // Prochain exercice
                      if (_nextExercise != null) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text('Ensuite :',
                              style: Theme.of(context).textTheme.labelSmall!.copyWith(color: AppTheme.textMuted)),
                        ),
                        const SizedBox(height: 8),

                        // Image du prochain exercice
                        if (_nextExercise!.imagePath != null)
                          ClipRRect(
                            child: AspectRatio(
                              aspectRatio: 2.0,
                              child: Image.asset(
                                _nextExercise!.imagePath!,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),

                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_nextExercise!.name,
                                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                    fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                            const SizedBox(height: 4),
                            Text(_nextExercise!.description,
                                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                                    color: AppTheme.textSecondary, height: 1.4)),
                            if (_nextExercise!.tip != null) ...[
                              const SizedBox(height: 6),
                              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Icon(Icons.lightbulb_outline,
                                    color: AppTheme.statusWarning, size: 13),
                                const SizedBox(width: 4),
                                Expanded(child: Text(_nextExercise!.tip!,
                                    style: Theme.of(context).textTheme.labelSmall!.copyWith(
                                        color: AppTheme.statusWarning, height: 1.3))),
                              ]),
                            ],
                          ]),
                        ),
                      ] else ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                          child: Text(
                            _round < _currentBlock.rounds
                                ? 'Prochain round : ${_currentBlock.exercises[0].name}'
                                : 'Dernier repos — fin du circuit !',
                            style: Theme.of(context).textTheme.bodySmall!.copyWith(
                                color: AppTheme.statusInfo, fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ]),
                  ),
                ],
                const SizedBox(height: 14),
              ]),
            ),
          ),

          // Contrôles
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: !_started
                ? GestureDetector(
                    onTap: _start,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(14)),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.play_arrow, color: AppTheme.textPrimary, size: 24),
                        const SizedBox(width: 8),
                        Text('Démarrer le circuit',
                            style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  )
                : Row(children: [
                    Expanded(child: GestureDetector(
                      onTap: _paused ? _start : _pause,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: _cardDark, borderRadius: BorderRadius.circular(14)),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(_paused ? Icons.play_arrow : Icons.pause,
                              color: AppTheme.textPrimary.withValues(alpha: 0.7), size: 22),
                          const SizedBox(width: 8),
                          Text(_paused ? 'Reprendre' : 'Pause',
                              style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: AppTheme.textPrimary.withValues(alpha: 0.7))),
                        ]),
                      ),
                    )),
                  ]),
          ),
        ]),
      ),
    );
  }
}

// ─── PREVIEW CARD ──────────────────────────────────────────────────────────────
class _ExercisePreviewCard extends StatelessWidget {
  final int index;
  final Exercise exercise;
  const _ExercisePreviewCard({required this.index, required this.exercise});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard, borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: AppTheme.accentHighlight.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: Text('${index + 1}',
                style: Theme.of(context).textTheme.bodySmall!.copyWith(color: AppTheme.accentHighlight,
                    fontWeight: FontWeight.w600))),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(exercise.name,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Text(exercise.description,
                style: Theme.of(context).textTheme.bodySmall!.copyWith(color: AppTheme.textSecondary, height: 1.4)),
            if (exercise.tip != null) ...[
              const SizedBox(height: 6),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.lightbulb_outline, color: AppTheme.statusWarning, size: 13),
                const SizedBox(width: 4),
                Expanded(child: Text(exercise.tip!,
                    style: Theme.of(context).textTheme.labelSmall!.copyWith(color: AppTheme.statusWarning, height: 1.3))),
              ]),
            ],
            const SizedBox(height: 6),
            Text('${exercise.durationSeconds}s travail · ${exercise.restSeconds}s repos',
                style: Theme.of(context).textTheme.labelSmall!.copyWith(color: AppTheme.textMuted)),
          ])),
        ]),
      ),
    );
  }
}

// ─── TIMER CARD ────────────────────────────────────────────────────────────────
class _ExerciseTimerCard extends StatelessWidget {
  final int index;
  final Exercise exercise;
  final Color color;
  const _ExerciseTimerCard({required this.index, required this.exercise, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(children: [
        if (exercise.imagePath != null)
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14), topRight: Radius.circular(14)),
            child: AspectRatio(
              aspectRatio: 2.0,
              child: Image.asset(exercise.imagePath!, fit: BoxFit.contain),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: Center(child: Text('${index + 1}',
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: color, fontWeight: FontWeight.w600))),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(exercise.name,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              const SizedBox(height: 6),
              Text(exercise.description,
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(color: AppTheme.textSecondary, height: 1.4)),
              if (exercise.tip != null) ...[
                const SizedBox(height: 8),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.lightbulb_outline, color: AppTheme.statusWarning, size: 14),
                  const SizedBox(width: 6),
                  Expanded(child: Text(exercise.tip!,
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(color: AppTheme.statusWarning, height: 1.3))),
                ]),
              ],
            ])),
          ]),
        ),
      ]),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: AppTheme.textSecondary),
      const SizedBox(width: 4),
      Text(label, style: Theme.of(context).textTheme.bodySmall!.copyWith(color: AppTheme.textSecondary)),
    ]);
  }
}
