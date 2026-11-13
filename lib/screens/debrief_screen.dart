import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../data/tendinite_program.dart';
import '../data/semi_program.dart';
import '../models/session.dart';
import '../models/route_point.dart';
import '../services/storage_service.dart';
import '../services/health_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class DebriefScreen extends StatefulWidget {
  final Session session;
  final int dayIndex;
  final List<RoutePoint> routePoints;
  final String distanceLabel;
  final double distanceMeters;
  final DateTime startTime;

  const DebriefScreen({
    super.key,
    required this.session,
    required this.dayIndex,
    required this.routePoints,
    required this.distanceLabel,
    required this.distanceMeters,
    required this.startTime,
  });

  @override
  State<DebriefScreen> createState() => _DebriefScreenState();
}

class _DebriefScreenState extends State<DebriefScreen> {
  int? _pain;
  bool _saving = false;
  bool _saving2Health = false;
  bool _savedToHealth = false;
  bool _kbPending = false;

  @override
  void initState() {
    super.initState();
    _autoSaveProgress();
    _checkKbStatus();
  }

  // Détermine si une séance KB reste à faire aujourd'hui (phase 1 uniquement)
  Future<void> _checkKbStatus() async {
    if (widget.dayIndex > 40) return;
    final workoutLogs = await StorageService.getWorkoutLogs();
    final today = DateTime.now();
    final doneToday = workoutLogs.any((l) =>
        l.date.year == today.year && l.date.month == today.month && l.date.day == today.day);
    if (mounted) setState(() => _kbPending = !doneToday);
  }

  // Capture distance + complétion tout de suite, même si l'écran est quitté sans valider
  Future<void> _autoSaveProgress() async {
    await StorageService.saveLog(SessionLog(
      dayIndex: widget.dayIndex,
      date: DateTime.now(),
      completed: true,
      painLevel: SessionLog.unratedPain,
      distanceMeters: widget.distanceMeters,
      route: _routeForLog,
    ));
    await StorageService.saveCompletion(widget.dayIndex);
  }

  final _options = [
    {
      'emoji': '😊',
      'label': 'Aucune douleur',
      'sub': 'Tout va bien',
      'color': 0xFF27A862
    },
    {
      'emoji': '😐',
      'label': 'Légère gêne',
      'sub': 'Disparaît vite',
      'color': 0xFFEF9F27
    },
    {
      'emoji': '😬',
      'label': 'Douleur modérée',
      'sub': 'Persistante',
      'color': 0xFFD85A30
    },
    {
      'emoji': '😰',
      'label': 'Douleur forte',
      'sub': 'Ça fait vraiment mal',
      'color': 0xFFE24B4A
    },
  ];

  final _recos = [
    {
      'label': '✓ Progression confirmée',
      'text': 'Super ! Tu passes à la séance suivante demain.',
      'hex': 0xFF27A862
    },
    {
      'label': '⚠ Légère gêne notée',
      'text': 'On répète la même séance demain.',
      'hex': 0xFFEF9F27
    },
    {
      'label': '⚠ Douleur modérée',
      'text': 'On revient à la séance précédente. Repose-toi bien.',
      'hex': 0xFFD85A30
    },
    {
      'label': '🛑 Arrêt recommandé',
      'text': 'Repos 2 jours minimum. Consulte si ça persiste.',
      'hex': 0xFFE24B4A
    },
  ];

  bool get _hasRoute => widget.routePoints.length >= 2;

  List<LatLng> get _latLngs =>
      widget.routePoints.map((p) => LatLng(p.lat, p.lng)).toList();

  List<List<double>>? get _routeForLog => _hasRoute
      ? widget.routePoints.map((p) => [p.lat, p.lng]).toList()
      : null;

  Future<void> _saveToHealth() async {
    setState(() => _saving2Health = true);
    final result = await HealthService.saveRun(
      startTime: widget.startTime,
      endTime: DateTime.now(),
      distanceMeters: widget.distanceMeters,
    );
    setState(() {
      _saving2Health = false;
      _savedToHealth = result == HealthSaveResult.success;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(switch (result) {
        HealthSaveResult.success => 'Séance enregistrée dans Santé !',
        HealthSaveResult.denied =>
          'Autorise RunSemi dans Réglages → Santé.',
        HealthSaveResult.error => 'Erreur lors de l\'enregistrement.',
      }),
    ));
  }

  Future<void> _validate() async {
    if (_pain == null) return;
    setState(() => _saving = true);

    await StorageService.saveLog(SessionLog(
      dayIndex: widget.dayIndex,
      date: DateTime.now(),
      completed: true,
      painLevel: _pain!,
      distanceMeters: widget.distanceMeters,
      route: _routeForLog,
    ));
    await StorageService.saveCompletion(widget.dayIndex);

    // Bornes sur tout le programme (phase 1 + phase 2), pas seulement la phase 1
    final totalDays = tendiniteProgram.length + semiProgram.length;
    int next = widget.dayIndex;
    if (_pain == 0) next = widget.dayIndex + 1;
    if (_pain == 2) next = (widget.dayIndex - 1).clamp(1, totalDays);
    await StorageService.setCurrentDay(next.clamp(1, totalDays));
    await NotificationService.cancelReminder(NotificationService.runReminderId);

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            const SizedBox(height: 16),

            // Check
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.statusSuccess.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppTheme.statusSuccess.withValues(alpha: 0.35),
                    width: 1.5),
              ),
              child:
                  const Icon(Icons.check, color: AppTheme.statusSuccess, size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              _kbPending ? 'Séance terminée ! KB disponible' : 'Bien joué, à demain !',
              style: AppTheme.h1.copyWith(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              widget.distanceLabel,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Stats
            Row(children: [
              Expanded(
                  child: _Stat(
                      value: "${widget.session.totalDurationMinutes}'",
                      label: 'Durée')),
              const SizedBox(width: 8),
              Expanded(
                  child: _Stat(
                      value: '${widget.session.runCount}',
                      label: 'Répétitions')),
              const SizedBox(width: 8),
              Expanded(
                  child: _Stat(
                      value: widget.distanceLabel, label: 'Distance')),
            ]),
            const SizedBox(height: 16),

            // Carte GPS (seulement si tracé disponible)
            if (_hasRoute) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 200,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: _latLngs[_latLngs.length ~/ 2],
                      initialZoom: 15,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.yannick.runsemi',
                      ),
                      PolylineLayer(polylines: [
                        Polyline(
                          points: _latLngs,
                          color: AppTheme.accentHighlight,
                          strokeWidth: 4,
                        ),
                      ]),
                      MarkerLayer(markers: [
                        Marker(
                          point: _latLngs.first,
                          child: const Icon(Icons.circle,
                              color: AppTheme.statusSuccess, size: 14),
                        ),
                        Marker(
                          point: _latLngs.last,
                          child: const Icon(Icons.circle,
                              color: AppTheme.accentHighlight, size: 14),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Bouton Apple Health — toujours visible
              _savedToHealth
                  ? Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceSunken,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: const Row(children: [
                        Icon(Icons.favorite,
                            color: AppTheme.statusSuccess, size: 20),
                        SizedBox(width: 10),
                        Text('Enregistrée dans Apple Santé',
                            style: TextStyle(
                                color: AppTheme.statusSuccess,
                                fontWeight: FontWeight.w500)),
                      ]),
                    )
                  : GestureDetector(
                      onTap: _saving2Health ? null : _saveToHealth,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppTheme.brandAppleHealth.withValues(alpha: 0.4)),
                        ),
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                        child: Row(children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppTheme.brandAppleHealth,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.favorite,
                                color: AppTheme.textPrimary, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text('Enregistrer dans Apple Santé',
                                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w500)),
                          ),
                          if (_saving2Health)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.brandAppleHealth),
                            )
                          else
                            const Icon(Icons.chevron_right,
                                color: AppTheme.textMuted),
                        ]),
                      ),
                    ),
            const SizedBox(height: 16),

            // Tendon
            Align(
              alignment: Alignment.centerLeft,
              child: Text("Ton tendon d'Achille ?",
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                  'Réponds honnêtement — ça ajuste ta prochaine séance.',
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(color: AppTheme.textSecondary)),
            ),
            const SizedBox(height: 12),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.6,
              children: List.generate(_options.length, (i) {
                final opt = _options[i];
                final color = Color(opt['color'] as int);
                final sel = _pain == i;
                return GestureDetector(
                  onTap: () => setState(() => _pain = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: sel
                          ? color.withValues(alpha: 0.1)
                          : AppTheme.surfaceCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: sel ? color : Colors.transparent,
                          width: 1.5),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(opt['emoji'] as String,
                            style: Theme.of(context).textTheme.headlineMedium!),
                        const SizedBox(height: 4),
                        Text(opt['label'] as String,
                            style: Theme.of(context).textTheme.labelSmall!.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center),
                        Text(opt['sub'] as String,
                            style: Theme.of(context).textTheme.labelSmall!.copyWith(
                                color: AppTheme.textMuted),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                );
              }),
            ),

            if (_pain != null) ...[
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color:
                      Color(_recos[_pain!]['hex'] as int).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border(
                      left: BorderSide(
                          color: Color(_recos[_pain!]['hex'] as int),
                          width: 3)),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_recos[_pain!]['label'] as String,
                        style: Theme.of(context).textTheme.labelSmall!.copyWith(
                            color: Color(_recos[_pain!]['hex'] as int),
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(_recos[_pain!]['text'] as String,
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                            color: AppTheme.textPrimary,
                            height: 1.4)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            GestureDetector(
              onTap: _pain != null && !_saving ? _validate : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 52,
                decoration: BoxDecoration(
                  color: _pain != null
                      ? AppTheme.accentPrimary
                      : AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: _saving
                      ? const CircularProgressIndicator(
                          color: AppTheme.textPrimary, strokeWidth: 2)
                      : Text('Valider →',
                          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                              color: _pain != null
                                  ? AppTheme.textPrimary
                                  : AppTheme.textMuted,
                              fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(AppTheme.radius10)),
      child: Column(children: [
        Text(value,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary)),
        const SizedBox(height: 2),
        Text(label,
            style: Theme.of(context).textTheme.labelSmall!.copyWith(color: AppTheme.textSecondary)),
      ]),
    );
  }
}
