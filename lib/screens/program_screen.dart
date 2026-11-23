import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../data/tendinite_program.dart';
import '../data/semi_program.dart';
import '../data/strength_program.dart';
import '../models/session.dart';
import '../models/workout.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/share_stats_card.dart';

class ProgramScreen extends StatefulWidget {
  const ProgramScreen({super.key});
  @override
  State<ProgramScreen> createState() => _ProgramScreenState();
}

class _ProgramScreenState extends State<ProgramScreen>
    with SingleTickerProviderStateMixin {
  int _currentDay = 1;
  List<SessionLog> _logs = [];
  List<WorkoutLog> _workoutLogs = [];
  bool _loading = true;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final day = await StorageService.getCurrentDay();
    final logs = await StorageService.getLogs();
    final workoutLogs = await StorageService.getWorkoutLogs();
    setState(() {
      _currentDay = day;
      _logs = logs;
      _workoutLogs = workoutLogs;
      _loading = false;
      // Ouvre l'onglet de la phase active
      _tabCtrl.index = _currentDay <= 40 ? 0 : 1;
    });
  }

  bool _done(int d) => _logs.any((l) => l.dayIndex == d && l.completed);

  SessionLog? _logFor(int d) {
    try {
      return _logs.firstWhere((l) => l.dayIndex == d && l.completed);
    } catch (_) {
      return null;
    }
  }

  // Retrouve la séance KB réellement effectuée le même jour calendaire que le log de course.
  WorkoutLog? _workoutLogFor(DateTime date) {
    try {
      return _workoutLogs.firstWhere((l) =>
          l.date.year == date.year && l.date.month == date.month && l.date.day == date.day);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator(color: AppTheme.accentHighlight)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(children: [
          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppTheme.space24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Programme', style: AppTheme.h1.copyWith(color: AppTheme.textPrimary)),
              const SizedBox(height: 12),
              // Tabs
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TabBar(
                  controller: _tabCtrl,
                  indicator: BoxDecoration(
                    color: AppTheme.accentPrimary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: AppTheme.textPrimary,
                  unselectedLabelColor: AppTheme.textSecondary,
                  labelStyle: Theme.of(context).textTheme.bodySmall!.copyWith(fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(text: 'Phase 1 · Tendinite'),
                    Tab(text: 'Phase 2 · Semi 21.1km'),
                  ],
                ),
              ),
            ]),
          ),

          const SizedBox(height: 12),

          // ── Contenu ────────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _PhaseList(
                  sessions: tendiniteProgram,
                  currentDay: _currentDay,
                  doneFn: _done,
                  logFn: _logFor,
                  workoutLogFn: _workoutLogFor,
                  onChanged: _load,
                  phaseLabel: 'Retour après tendinite',
                  totalWeeks: 8,
                  isActive: _currentDay <= 40,
                ),
                _PhaseList(
                  sessions: semiProgram,
                  currentDay: _currentDay,
                  doneFn: _done,
                  logFn: _logFor,
                  workoutLogFn: _workoutLogFor,
                  onChanged: _load,
                  phaseLabel: 'Préparation 21.1 km',
                  totalWeeks: 12,
                  isActive: _currentDay > 40,
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Liste d'une phase ─────────────────────────────────────────────────────────
class _PhaseList extends StatelessWidget {
  final List<Session> sessions;
  final int currentDay;
  final bool Function(int) doneFn;
  final SessionLog? Function(int) logFn;
  final WorkoutLog? Function(DateTime) workoutLogFn;
  final VoidCallback onChanged;
  final String phaseLabel;
  final int totalWeeks;
  final bool isActive;

  const _PhaseList({
    required this.sessions,
    required this.currentDay,
    required this.doneFn,
    required this.logFn,
    required this.workoutLogFn,
    required this.onChanged,
    required this.phaseLabel,
    required this.totalWeeks,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final byWeek = <int, List<Session>>{};
    for (final s in sessions) {
      byWeek.putIfAbsent(s.weekNumber, () => []).add(s);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.space24, AppTheme.space24, AppTheme.space24, AppTheme.space48,
      ),
      itemCount: byWeek.length,
      itemBuilder: (ctx, i) {
        final week = i + 1;
        final weekSessions = byWeek[week] ?? [];
        final isCurrent = weekSessions.any((s) => s.dayIndex == currentDay);
        final weekDone = weekSessions.every((s) => doneFn(s.dayIndex));

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // En-tête semaine
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              Text('Semaine $week',
                  style: Theme.of(ctx).textTheme.bodySmall!.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isCurrent ? AppTheme.textPrimary : AppTheme.textMuted)),
              if (weekDone) ...[
                const SizedBox(width: 8),
                Text('✓', style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: AppTheme.statusSuccess)),
              ] else if (isCurrent) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accentHighlight.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('en cours',
                      style: Theme.of(ctx).textTheme.labelSmall!.copyWith(color: AppTheme.accentHighlight, fontWeight: FontWeight.w600)),
                ),
              ],
            ]),
          ),

          // Carte de la semaine
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: <Widget>[
                ...weekSessions.asMap().entries.map((e) {
                final idx = e.key;
                final s = e.value;
                final done = doneFn(s.dayIndex);
                final current = s.dayIndex == currentDay;
                final future = !isActive || s.dayIndex > currentDay;

                final sessionLog = done ? logFn(s.dayIndex) : null;
                return GestureDetector(
                  onTap: () => _showDayDetailDialog(
                    context,
                    s,
                    sessionLog,
                    sessionLog != null ? workoutLogFn(sessionLog.date) : null,
                    onChanged,
                    canLog: !future,
                  ),
                  child: Container(
                  decoration: BoxDecoration(
                    color: current ? AppTheme.accentHighlight.withValues(alpha: 0.06) : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: current
                        ? const Border(left: BorderSide(color: AppTheme.accentHighlight, width: 3))
                        : null,
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      current ? 13 : 16,
                      idx == 0 ? 12 : 8,
                      16,
                      idx == weekSessions.length - 1 ? 12 : 8,
                    ),
                    child: Row(children: [
                      // Icône type
                      Text(
                        _typeIcon(s.sessionType),
                        style: Theme.of(ctx).textTheme.bodyMedium,
                      ),
                      const SizedBox(width: 8),
                      // Done indicator
                      if (done)
                        Text('✓',
                            style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: AppTheme.statusSuccess, fontWeight: FontWeight.w600))
                      else
                        const SizedBox(width: 12),
                      const SizedBox(width: 6),
                      // Titre + durée
                      Expanded(
                        child: Text(
                          s.title,
                          style: Theme.of(ctx).textTheme.bodySmall!.copyWith(
                            color: future && !current
                                ? AppTheme.textMuted
                                : current ? AppTheme.textPrimary : AppTheme.textPrimary,
                            fontWeight: current ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                      // Durée + PE
                      if (s.sessionType != SessionType.repos)
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text("${s.totalDurationMinutes}'",
                              style: Theme.of(ctx).textTheme.labelSmall!.copyWith(
                                  color: future && !current ? AppTheme.textMuted : AppTheme.textSecondary)),
                          if (s.pe != null)
                            Text('PE ${s.pe}',
                                style: Theme.of(ctx).textTheme.labelSmall!.copyWith(color: AppTheme.textMuted)),
                        ]),
                    ]),
                  ),
                  ),
                );
              }),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ]);
      },
    );
  }

  String _typeIcon(SessionType type) => switch (type) {
    SessionType.repos        => '😴',
    SessionType.endurance    => '🏃',
    SessionType.intervalles  => '⚡',
    SessionType.renforcement => '💪',
    SessionType.croise       => '🚴',
    SessionType.recuperation => '🚶',
    SessionType.competition  => '🏁',
  };
}

// Dialog unique : détail course (log si fait, sinon phases) + kettlebell,
// pour ne jamais séparer le renforcement musculaire de la séance du jour.
// Si une séance KB a réellement été journalisée ce jour-là, on affiche ses
// vrais exercices ; sinon on retombe sur un aperçu généré.
Future<bool> _confirmDelete(BuildContext context, String message) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surfaceCard,
      title: Text('Supprimer ?', style: AppTheme.h4.copyWith(color: AppTheme.textPrimary)),
      content: Text(message, style: Theme.of(ctx).textTheme.bodyMedium!.copyWith(color: AppTheme.textSecondary)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Annuler', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Supprimer', style: TextStyle(color: AppTheme.statusDanger, fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

Future<void> _showDayDetailDialog(
    BuildContext context, Session s, SessionLog? log, WorkoutLog? workoutLog, VoidCallback onChanged,
    {required bool canLog}) async {
  final mix = _kbForDay(s.dayIndex, workoutLog);
  if (!context.mounted) return;

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surfaceCard,
      title: Row(children: [
        Expanded(child: Text(s.title, style: AppTheme.h4.copyWith(color: AppTheme.textPrimary))),
        IconButton(
          icon: const Icon(Icons.ios_share, color: AppTheme.textSecondary),
          tooltip: 'Partager',
          onPressed: () => showShareCardDialog(ctx,
              title: s.title,
              subtitle: 'Run Semi · Jour ${s.dayIndex} · Semaine ${s.weekNumber}'
                  '${log != null ? ' · ${log.date.day}/${log.date.month}/${log.date.year}' : ''}',
              stats: buildDayShareStats(s, log)),
        ),
      ]),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Course ──
          Text(s.subtitle, style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          if (log != null) ...[
            if (_routePoints(log).length >= 2)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 180,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: _routePoints(log)[_routePoints(log).length ~/ 2],
                      initialZoom: 15,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.yannick.runsemi',
                      ),
                      PolylineLayer(polylines: [
                        Polyline(points: _routePoints(log), color: AppTheme.accentHighlight, strokeWidth: 4),
                      ]),
                    ],
                  ),
                ),
              )
            else
              Text('Aucun tracé GPS enregistré pour cette séance.',
                  style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            Text(
                'Réalisée le : ${log.date.day}/${log.date.month}/${log.date.year}',
                style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: AppTheme.textPrimary)),
            Text(
                'Distance : ${log.distanceMeters < 1000 ? '${log.distanceMeters.round()} m' : '${(log.distanceMeters / 1000).toStringAsFixed(2)} km'}',
                style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: AppTheme.textPrimary)),
            if (log.painLevel != SessionLog.unratedPain)
              Text('Douleur ressentie : ${log.painLevel}/3',
                  style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: AppTheme.textPrimary)),
          ] else if (s.phases.isNotEmpty) ...[
            Text('Durée : ${s.totalDurationMinutes} min', style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: AppTheme.textPrimary)),
            if (s.pe != null)
              Text('Perception d\'effort : ${s.pe}/10', style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: AppTheme.textPrimary)),
            if (s.rcLabel != null)
              Text('Réserve cardiaque : ${s.rcLabel}', style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            ...s.phases.map((p) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('${p.isRun ? '🏃' : '🚶'} ${p.label} — ${p.durationLabel}',
                  style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: AppTheme.textPrimary)),
            )),
          ],
          // ── Kettlebell / renforcement musculaire ──
          if (mix.exercises.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: AppTheme.surfaceRaised),
            const SizedBox(height: 8),
            Text('💪 Renforcement — ${mix.title}',
                style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ...mix.exercises.map((ex) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('• ${ex.name}',
                  style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: AppTheme.textPrimary)),
            )),
          ],
        ]),
      ),
      actions: [
        if (log == null && canLog)
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showLogSessionDialog(context, s, onChanged);
            },
            child: const Text('➕ Marquer comme faite', style: TextStyle(color: AppTheme.accentHighlight, fontWeight: FontWeight.w600)),
          ),
        if (workoutLog == null)
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showAddKbOnlyDialog(context, s, log, onChanged);
            },
            child: const Text('➕ Ajouter le KB', style: TextStyle(color: AppTheme.accentHighlight, fontWeight: FontWeight.w600)),
          ),
        if (log != null)
          TextButton(
            onPressed: () async {
              final confirmed = await _confirmDelete(ctx, 'Cette séance de course sera supprimée. Tu pourras la ressaisir ensuite.');
              if (!confirmed) return;
              await StorageService.deleteLog(log.dayIndex);
              if (ctx.mounted) Navigator.pop(ctx);
              onChanged();
            },
            child: const Text('🗑 Supprimer la course', style: TextStyle(color: AppTheme.statusDanger)),
          ),
        if (workoutLog != null)
          TextButton(
            onPressed: () async {
              final confirmed = await _confirmDelete(ctx, 'Cette séance kettlebell sera supprimée. Tu pourras la ressaisir ensuite.');
              if (!confirmed) return;
              await StorageService.deleteWorkoutLog(workoutLog);
              if (ctx.mounted) Navigator.pop(ctx);
              onChanged();
            },
            child: const Text('🗑 Supprimer le KB', style: TextStyle(color: AppTheme.statusDanger)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Fermer', style: TextStyle(color: AppTheme.textSecondary)),
        ),
      ],
    ),
  );
}

// Saisie manuelle d'une séance depuis le popup Programme : course (obligatoire,
// pré-remplie sur ce jour) + renforcement KB optionnel, en une seule sauvegarde.
Future<void> _showLogSessionDialog(BuildContext context, Session s, VoidCallback onChanged) async {
  final distanceController = TextEditingController();
  final kbTitleController = TextEditingController(text: mixedWorkoutForDay(s.dayIndex).title);
  final kbDurationController = TextEditingController(text: '30');
  final kbVolumeController = TextEditingController();
  DateTime selectedDate = DateTime.now();
  int selectedPain = 0;
  bool alsoKb = false;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        title: Text(s.title, style: AppTheme.h4.copyWith(color: AppTheme.textPrimary)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Date', style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: AppTheme.textSecondary)),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setDialogState(() => selectedDate = picked);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                    style: const TextStyle(color: AppTheme.textPrimary)),
              ),
            ),
            const SizedBox(height: 8),
            Text('Douleur au tendon', style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: List.generate(4, (i) {
              const labels = ['😊 Aucune', '😐 Légère', '😬 Modérée', '😰 Forte'];
              final selected = selectedPain == i;
              return ChoiceChip(
                label: Text(labels[i],
                    style: Theme.of(ctx).textTheme.labelSmall!.copyWith(color: selected ? AppTheme.textPrimary : AppTheme.textSecondary)),
                selected: selected,
                selectedColor: AppTheme.accentPrimary,
                backgroundColor: AppTheme.surfaceRaised,
                onSelected: (_) => setDialogState(() => selectedPain = i),
              );
            })),
            const SizedBox(height: 12),
            Text('Distance (km)', style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: AppTheme.textSecondary)),
            TextField(
              controller: distanceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(hintText: '0', hintStyle: TextStyle(color: AppTheme.textMuted)),
            ),
            const SizedBox(height: 16),
            const Divider(color: AppTheme.surfaceRaised),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('💪 Renforcement effectué aussi',
                  style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
              Switch(
                value: alsoKb,
                activeThumbColor: AppTheme.accentPrimary,
                onChanged: (v) => setDialogState(() => alsoKb = v),
              ),
            ]),
            if (alsoKb) ...[
              const SizedBox(height: 8),
              Text('Titre de la séance', style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: AppTheme.textSecondary)),
              TextField(
                controller: kbTitleController,
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 12),
              Text('Durée (min)', style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: AppTheme.textSecondary)),
              TextField(
                controller: kbDurationController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 12),
              Text('Volume estimé (kg)', style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: AppTheme.textSecondary)),
              TextField(
                controller: kbVolumeController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(hintText: '0', hintStyle: TextStyle(color: AppTheme.textMuted)),
              ),
            ],
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              final km = double.tryParse(distanceController.text.replaceAll(',', '.')) ?? 0;
              await StorageService.saveLog(SessionLog(
                dayIndex: s.dayIndex,
                date: selectedDate,
                completed: true,
                painLevel: selectedPain,
                distanceMeters: km * 1000,
              ));
              if (alsoKb) {
                final duration = int.tryParse(kbDurationController.text) ?? 0;
                final volume = double.tryParse(kbVolumeController.text.replaceAll(',', '.')) ?? 0;
                await StorageService.saveWorkoutLog(WorkoutLog(
                  date: selectedDate,
                  estimatedVolumeKg: volume,
                  durationMinutes: duration,
                  sessionTitle: kbTitleController.text.trim().isEmpty ? 'Renforcement' : kbTitleController.text.trim(),
                ));
              }
              if (ctx.mounted) Navigator.pop(ctx);
              onChanged();
            },
            child: const Text('Ajouter', style: TextStyle(color: AppTheme.accentHighlight, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    ),
  );
}

// Permet d'ajouter le KB seul pour ce jour, sans toucher/refaire la course déjà loggée.
Future<void> _showAddKbOnlyDialog(BuildContext context, Session s, SessionLog? log, VoidCallback onChanged) async {
  final kbTitleController = TextEditingController(text: mixedWorkoutForDay(s.dayIndex).title);
  final kbDurationController = TextEditingController(text: '30');
  final kbVolumeController = TextEditingController();
  DateTime selectedDate = log?.date ?? DateTime.now();

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        title: Text('Ajouter le renforcement', style: AppTheme.h4.copyWith(color: AppTheme.textPrimary)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Date', style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: AppTheme.textSecondary)),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setDialogState(() => selectedDate = picked);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                    style: const TextStyle(color: AppTheme.textPrimary)),
              ),
            ),
            const SizedBox(height: 12),
            Text('Titre de la séance', style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: AppTheme.textSecondary)),
            TextField(
              controller: kbTitleController,
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            Text('Durée (min)', style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: AppTheme.textSecondary)),
            TextField(
              controller: kbDurationController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            Text('Volume estimé (kg)', style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: AppTheme.textSecondary)),
            TextField(
              controller: kbVolumeController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(hintText: '0', hintStyle: TextStyle(color: AppTheme.textMuted)),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              final duration = int.tryParse(kbDurationController.text) ?? 0;
              final volume = double.tryParse(kbVolumeController.text.replaceAll(',', '.')) ?? 0;
              await StorageService.saveWorkoutLog(WorkoutLog(
                date: selectedDate,
                estimatedVolumeKg: volume,
                durationMinutes: duration,
                sessionTitle: kbTitleController.text.trim().isEmpty ? 'Renforcement' : kbTitleController.text.trim(),
              ));
              if (ctx.mounted) Navigator.pop(ctx);
              onChanged();
            },
            child: const Text('Ajouter', style: TextStyle(color: AppTheme.accentHighlight, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    ),
  );
}

List<LatLng> _routePoints(SessionLog log) =>
    log.route?.map((p) => LatLng(p[0], p[1])).toList() ?? [];

// Si une séance a réellement été effectuée (WorkoutLog), on affiche ses vrais
// exercices (retrouvés dans strengthProgram via son titre). Sinon on affiche
// le mix déterministe du jour (même source que l'écran Aujourd'hui) pour ne
// jamais afficher un aperçu différent de ce qui est réellement proposé.
({String title, List<Exercise> exercises}) _kbForDay(int dayIndex, WorkoutLog? workoutLog) {
  if (workoutLog != null) {
    final workout = strengthProgram.where((w) => w.title == workoutLog.sessionTitle).firstOrNull;
    if (workout != null) {
      return (
        title: workout.title,
        exercises: workout.blocks.expand((b) => b.exercises).toList(),
      );
    }
  }
  final workout = mixedWorkoutForDay(dayIndex);
  return (
    title: workout.title,
    exercises: workout.blocks.expand((b) => b.exercises).toList(),
  );
}
