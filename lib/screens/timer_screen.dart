import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/session.dart';
import '../services/gps_service.dart';
import 'debrief_screen.dart';
import '../theme/app_theme.dart';

class TimerScreen extends StatefulWidget {
  final Session session;
  final int dayIndex;
  const TimerScreen({super.key, required this.session, required this.dayIndex});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> with WidgetsBindingObserver {
  late FlutterTts _tts;
  final GpsService _gps = GpsService();

  int _phaseIndex = 0;
  int _remaining = 0;
  bool _paused = false;
  bool _started = false;
  bool _gpsActive = false;
  Timer? _timer;
  DateTime? _phaseStartTime; // Pour recalculer après verrouillage

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _remaining = widget.session.phases[0].durationSeconds;
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

  // ── Gestion arrière-plan (iPhone verrouillé) ──────────────────────────────
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
    final phaseDuration = _currentPhase.durationSeconds;
    final newRemaining = phaseDuration - elapsed;

    if (newRemaining <= 0) {
      // Phase terminée pendant le verrouillage
      setState(() => _remaining = 0);
      _advanceFromBackground(-newRemaining);
    } else {
      setState(() => _remaining = newRemaining);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  void _advanceFromBackground(int overflowSeconds) {
    // Avance les phases en tenant compte du temps écoulé en arrière-plan
    if (_phaseIndex < widget.session.phases.length - 1) {
      setState(() => _phaseIndex++);
      _phaseStartTime = DateTime.now().subtract(Duration(seconds: overflowSeconds));
      _remaining = (_currentPhase.durationSeconds - overflowSeconds).clamp(0, _currentPhase.durationSeconds);
      if (_remaining <= 0) {
        _advanceFromBackground(overflowSeconds - _currentPhase.durationSeconds);
      } else {
        _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
        _announce();
      }
    } else {
      _finish();
    }
  }

  // ── Contrôles ─────────────────────────────────────────────────────────────
  void _startOrResume() {
    if (!_started) {
      _gps.startRecording().then((_) {
        if (mounted) setState(() => _gpsActive = _gps.isRecording);
      });
    } else {
      _gps.resume();
    }
    setState(() { _started = true; _paused = false; });
    _phaseStartTime = DateTime.now();
    _announce();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    setState(() => _remaining--);
    if (_remaining == 3 && _phaseIndex < widget.session.phases.length - 1) {
      final next = widget.session.phases[_phaseIndex + 1];
      _speak(next.isRun ? 'Prêt à courir' : 'Prêt à marcher');
    }
    if (_remaining <= 0) {
      _timer?.cancel();
      if (_phaseIndex < widget.session.phases.length - 1) {
        setState(() => _phaseIndex++);
        _remaining = _currentPhase.durationSeconds;
        _phaseStartTime = DateTime.now();
        _startOrResume();
      } else {
        _finish();
      }
    }
  }

  void _pause() {
    _timer?.cancel();
    _gps.pause();
    setState(() => _paused = true);
  }

  void _announce() => _speak(_currentPhase.isRun ? 'Course !' : 'Marche');

  Future<void> _speak(String text) async {
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
    await _tts.speak(text);
  }

  void _finish() {
    _gps.stopRecording();
    _speak('Bravo ! Séance terminée !');
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => DebriefScreen(
        session: widget.session,
        dayIndex: widget.dayIndex,
        routePoints: _gps.points,
        distanceLabel: _gps.distanceLabel,
        distanceMeters: _gps.totalDistanceMeters,
        startTime: _gps.startTime ?? DateTime.now(),
      ),
    ));
  }

  void _confirmStop() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surfaceCard,
      title: Text('Arrêter la séance ?', style: AppTheme.h4.copyWith(color: AppTheme.textPrimary)),
      content: const Text('Ta progression ne sera pas sauvegardée.',
          style: TextStyle(color: AppTheme.textSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Continuer', style: TextStyle(color: AppTheme.accentHighlight))),
        TextButton(
          onPressed: () {
            _gps.stopRecording();
            Navigator.pop(ctx);
            Navigator.pop(context);
          },
          child: const Text('Arrêter', style: TextStyle(color: AppTheme.textSecondary)),
        ),
      ],
    ));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _tts.stop();
    super.dispose();
  }

  // ── Getters ───────────────────────────────────────────────────────────────
  TimerPhase get _currentPhase => widget.session.phases[_phaseIndex];
  List<TimerPhase> get _runPhases =>
      widget.session.phases.where((p) => p.isRun).toList();

  int get _currentRunIndex {
    int n = 0;
    for (int i = 0; i <= _phaseIndex; i++) {
      if (widget.session.phases[i].isRun) n++;
    }
    return n - 1;
  }

  String get _timeLabel {
    final m = _remaining ~/ 60;
    final s = _remaining % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isRun = _currentPhase.isRun;
    final phaseColor = isRun ? AppTheme.accentHighlight : AppTheme.statusInfo;
    final runs = _runPhases;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              GestureDetector(
                onTap: _confirmStop,
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.textPrimary.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: AppTheme.textSecondary, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(widget.session.title,
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(color: AppTheme.textSecondary),
                  overflow: TextOverflow.ellipsis)),
            ]),
          ),

          // GPS
          if (_started)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(children: [
                Container(width: 8, height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _gpsActive ? AppTheme.statusSuccess : AppTheme.statusWarning,
                    )),
                const SizedBox(width: 6),
                Text(_gpsActive ? 'GPS actif' : 'GPS en attente…',
                    style: Theme.of(context).textTheme.labelSmall!.copyWith(
                        color: _gpsActive ? AppTheme.statusSuccess : AppTheme.statusWarning)),
                const Spacer(),
                if (_gpsActive)
                  Text(_gps.distanceLabel,
                      style: Theme.of(context).textTheme.labelSmall!.copyWith(color: AppTheme.textSecondary)),
              ]),
            ),

          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Divider(color: AppTheme.surfaceRaised, thickness: 1, height: 1),
          ),

          // Badge phase
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: phaseColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: phaseColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _started ? (isRun ? '🏃  COURSE' : '🚶  MARCHE') : '⏱  PRÊT',
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(color: phaseColor,
                      fontWeight: FontWeight.w600, letterSpacing: 1),
                ),
              ),
            ]),
          ),

          // Timer géant
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_started ? _timeLabel : '--:--',
                      style: AppTheme.timerDisplay.copyWith(color: AppTheme.textPrimary)),
                  Text('restantes', style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ),

          const Divider(color: AppTheme.surfaceRaised, thickness: 1, height: 1),

          // Rep + phase
          IntrinsicHeight(
            child: Row(children: [
              Expanded(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('rep.', style: Theme.of(context).textTheme.labelSmall!.copyWith(color: AppTheme.textSecondary)),
                  Text(
                    // Toujours au format "X / Y" pour rester cohérent avant/pendant la séance
                    '${_started ? (_currentRunIndex + 1).clamp(0, runs.length) : 0} / ${runs.length}',
                    style: Theme.of(context).textTheme.displaySmall!.copyWith(
                        color: AppTheme.textPrimary, height: 1.1),
                  ),
                ]),
              )),
              const VerticalDivider(color: AppTheme.surfaceRaised, thickness: 1, width: 1),
              Expanded(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('phase', style: Theme.of(context).textTheme.labelSmall!.copyWith(color: AppTheme.textSecondary)),
                  Text(_started ? (isRun ? 'COURSE' : 'MARCHE') : '--',
                      style: Theme.of(context).textTheme.displaySmall!.copyWith(
                          color: AppTheme.textPrimary, height: 1.2)),
                ]),
              )),
            ]),
          ),

          // Ensuite
          if (_phaseIndex < widget.session.phases.length - 1) ...[
            const Divider(color: AppTheme.surfaceRaised, thickness: 1, height: 1),
            Container(
              color: AppTheme.surfaceSunken,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(children: [
                Text('ensuite  ·  ', style: Theme.of(context).textTheme.bodySmall!.copyWith(color: AppTheme.textMuted)),
                Text(
                  widget.session.phases[_phaseIndex + 1].isRun
                      ? 'course' : 'marche · récupération',
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary),
                ),
              ]),
            ),
          ],

          // Contrôles
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: !_started
                ? GestureDetector(
                    onTap: _startOrResume,
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppTheme.accentPrimary,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Center(child: Text('DÉMARRER',
                          style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600, letterSpacing: 1))),
                    ),
                  )
                : Row(children: [
                    Expanded(child: GestureDetector(
                      onTap: _paused ? _startOrResume : _pause,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceRaised,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Center(child: Text(
                          _paused ? 'REPRENDRE' : 'PAUSE',
                          style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500),
                        )),
                      ),
                    )),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _confirmStop,
                      child: Container(
                        width: 56, height: 56,
                        decoration: const BoxDecoration(
                          color: AppTheme.surfaceRaised,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.stop, color: AppTheme.statusDanger, size: 22),
                      ),
                    ),
                  ]),
          ),
        ]),
      ),
    );
  }
}
