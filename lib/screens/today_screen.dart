import 'package:flutter/material.dart';
import '../data/tendinite_program.dart';
import '../data/strength_program.dart';
import '../data/semi_program.dart';
import '../models/session.dart';
import '../models/workout.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/runner_animation.dart';
import 'timer_screen.dart';
import 'workout_screen.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});
  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  int _currentDay = 1;
  bool _loading = true;
  bool _completedToday = false;
  bool _kbCompletedToday = false;
  DayWorkout? _todayStrength;
  String _todayDistanceLabel = '';
  int _cardIndex = 0;
  late PageController _pageCtrl;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: 0.968);
    _load();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final day = await StorageService.getCurrentDay();
    final completedToday = await StorageService.wasCompletedToday();

    DayWorkout? todayStrength;
    if (strengthProgram.isNotEmpty) {
      todayStrength = mixedWorkoutForDay(day);
    }

    // Vérifier si le KB a été fait aujourd'hui
    final workoutLogs = await StorageService.getWorkoutLogs();
    final todayDate = DateTime.now();
    final kbDoneToday = workoutLogs.any((l) =>
        l.date.year == todayDate.year &&
        l.date.month == todayDate.month &&
        l.date.day == todayDate.day);

    // Distance de la course faite aujourd'hui, pour l'afficher sur la carte
    final logs = await StorageService.getLogs();
    final todayLogs = logs.where((l) =>
        l.date.year == todayDate.year &&
        l.date.month == todayDate.month &&
        l.date.day == todayDate.day).toList();
    final todayDistance = todayLogs.isNotEmpty ? todayLogs.last.distanceMeters : 0.0;
    final distanceLabel = todayDistance < 1000
        ? '${todayDistance.round()} m'
        : '${(todayDistance / 1000).toStringAsFixed(2)} km';

    setState(() {
      _currentDay = day;
      _completedToday = completedToday;
      _kbCompletedToday = kbDoneToday;
      _todayStrength = todayStrength;
      _todayDistanceLabel = distanceLabel;
      _loading = false;
    });
    NotificationService.refresh();
  }

  Session get _session {
    if (_currentDay <= 40) {
      return tendiniteProgram[(_currentDay - 1).clamp(0, tendiniteProgram.length - 1)];
    } else {
      final idx = (_currentDay - 41).clamp(0, semiProgram.length - 1);
      return semiProgram[idx];
    }
  }

  void _startSession() async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => TimerScreen(session: _session, dayIndex: _currentDay),
    ));
    _load();
  }

  void _startWorkout() {
    if (_todayStrength == null) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => WorkoutScreen(workout: _todayStrength!),
    )).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator(color: AppTheme.accentHighlight)),
      );
    }

    final session = _session;
    final now = DateTime.now();
    const dayNames = ['lun', 'mar', 'mer', 'jeu', 'ven', 'sam', 'dim'];
    // Format Figma « sam 20.09 »
    final dateStr = '${dayNames[now.weekday - 1]} '
        '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}';
    final phase = _currentDay <= 40 ? 1 : 2;
    final totalDays = phase == 1 ? 40 : 84;
    final dayInPhase = phase == 1 ? _currentDay : _currentDay - 40;
    final progress = (dayInPhase - 1) / totalDays;

    final cards = <_CardData>[
      _CardData(
        title: _completedToday ? 'Séance terminée' : session.title,
        subtitle: _completedToday
            ? (_kbCompletedToday ? 'Journée complète 💪 À demain !' : 'Bien joué ! Il reste le KB.')
            : session.subtitle,
        stat1Label: 'durée',
        stat1Value: "${session.totalDurationMinutes}'",
        stat2Label: _completedToday ? 'distance' : (_currentDay <= 40 ? 'semaine' : 'phase'),
        stat2Value: _completedToday
            ? _todayDistanceLabel
            : (_currentDay <= 40 ? 'S${session.weekNumber}' : 'P2 S${session.weekNumber}'),
        ctaLabel: _completedToday ? '✓ Complétée' : 'Démarrer la séance',
        onTap: _completedToday ? null : _startSession,
        done: _completedToday,
        available: true,
        showRunner: !_completedToday,
      ),
      if (_todayStrength != null && _todayStrength!.blocks.isNotEmpty)
        _CardData(
          title: _kbCompletedToday ? 'KB terminé' : _todayStrength!.title,
          subtitle: _kbCompletedToday
              ? (_completedToday ? 'Journée complète 💪 À demain !' : 'Bien joué ! Il reste la course.')
              : _todayStrength!.subtitle,
          stat1Label: 'rounds',
          stat1Value: '${_todayStrength!.blocks.first.rounds}×',
          stat2Label: 'durée',
          stat2Value: "~${_todayStrength!.totalMinutes}'",
          ctaLabel: _kbCompletedToday ? '✓ Complété' : 'Démarrer le KB',
          onTap: _kbCompletedToday ? null : _startWorkout,
          done: _kbCompletedToday,
          available: !_kbCompletedToday,
        ),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── En-tête ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(AppTheme.space20, AppTheme.space24, AppTheme.space20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Pastille de phase
              Container(
                padding: const EdgeInsets.all(AppTheme.space8),
                decoration: BoxDecoration(
                  color: AppTheme.accentHighlight,
                  borderRadius: BorderRadius.circular(AppTheme.radius24),
                ),
                child: Text(
                  'Phase $phase · ${phase == 1 ? 'Tendinite' : 'Semi 21.1km'}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: AppTheme.textOnHighlight),
                ),
              ),
              const SizedBox(height: AppTheme.space4),
              Text(dateStr, style: AppTheme.h1.copyWith(color: AppTheme.textPrimary, height: 1.2)),
              const SizedBox(height: AppTheme.space2),
              Text('Jour $dayInPhase sur $totalDays',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary)),
              const SizedBox(height: AppTheme.space8),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radius3),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppTheme.surfaceRaised,
                  valueColor: const AlwaysStoppedAnimation(AppTheme.accentHighlight),
                  minHeight: 4,
                ),
              ),
            ]),
          ),

          const SizedBox(height: AppTheme.space18),

          // ── Carrousel ─────────────────────────────────────────────────────
          SizedBox(
            height: 400,
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: cards.length,
              onPageChanged: (i) => setState(() => _cardIndex = i),
              itemBuilder: (ctx, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.space8),
                child: _SessionCard(data: cards[i]),
              ),
            ),
          ),

          // ── Pagination ────────────────────────────────────────────────────
          if (cards.length > 1) ...[
            const SizedBox(height: AppTheme.space18),
            Row(mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(cards.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: AppTheme.space4),
                width: i == _cardIndex ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _cardIndex ? AppTheme.accentHighlight : AppTheme.textPrimary,
                  borderRadius: BorderRadius.circular(AppTheme.radius3),
                ),
              )),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Data ─────────────────────────────────────────────────────────────────────

class _CardData {
  final String title;
  final String subtitle;
  final String stat1Label;
  final String stat1Value;
  final String stat2Label;
  final String stat2Value;
  final String ctaLabel;
  final VoidCallback? onTap;
  final bool done;
  final bool available;
  final bool showRunner;

  const _CardData({
    required this.title,
    required this.subtitle,
    required this.stat1Label,
    required this.stat1Value,
    required this.stat2Label,
    required this.stat2Value,
    required this.ctaLabel,
    required this.onTap,
    required this.done,
    required this.available,
    this.showRunner = false,
  });
}

// ── Carte de séance (Figma "accueil (base)", node 18065:8297) ────────────────

class _SessionCard extends StatelessWidget {
  final _CardData data;
  const _SessionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCardHero,
        borderRadius: BorderRadius.circular(AppTheme.radius20),
        // Figma : liseré jaune 1 px sur les séances à faire, vert 40 % une fois terminée
        border: data.done
            ? Border.all(color: AppTheme.statusSuccess.withValues(alpha: 0.4), width: 1.5)
            : Border.all(color: AppTheme.accentHighlight),
      ),
      padding: const EdgeInsets.fromLTRB(
          AppTheme.space20, AppTheme.space20, AppTheme.space20, AppTheme.space12),
      child: Column(children: [
        // Titre + sous-titre
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: double.infinity,
            child: Text(data.title,
                style: AppTheme.heading18.copyWith(color: AppTheme.textPrimary),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: AppTheme.space8),
          Text(data.subtitle,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ]),

        // Animation coureur (carte course uniquement), centrée dans l'espace libre
        Expanded(
          child: Center(
            child: data.showRunner ? const RunnerAnimation(height: 120) : null,
          ),
        ),

        // Stats
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _Stat(label: data.stat1Label, value: data.stat1Value),
          const SizedBox(width: AppTheme.space24),
          _Stat(label: data.stat2Label, value: data.stat2Value),
        ]),
        const SizedBox(height: AppTheme.space24),

        // CTA pilule
        GestureDetector(
          onTap: data.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space24, vertical: AppTheme.space16),
            decoration: BoxDecoration(
              color: data.done
                  ? AppTheme.statusSuccess.withValues(alpha: 0.12)
                  : data.available
                      ? AppTheme.accentPrimary
                      : AppTheme.textPrimary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            ),
            child: Text(data.ctaLabel,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: data.done
                      ? AppTheme.statusSuccess
                      : data.available
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                )),
          ),
        ),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelSmall!.copyWith(
          color: AppTheme.textSecondary, fontWeight: FontWeight.w400)),
      const SizedBox(height: AppTheme.space2),
      Text(value, style: AppTheme.h2.copyWith(color: AppTheme.textPrimary)),
    ],
  );
}
