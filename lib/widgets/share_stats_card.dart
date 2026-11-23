import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../data/semi_program.dart';
import '../data/tendinite_program.dart';
import '../models/session.dart';
import '../services/pedometer_service.dart';
import '../theme/app_theme.dart';
import 'app_background.dart';

typedef ShareStat = ({String label, String value, Color color});

/// Chiffres de la carte « Partager mes stats » : km cumulés, dernière allure en
/// course, allure moyenne globale, temps total de course, dernière douleur.
List<ShareStat> buildShareStats(List<SessionLog> logs) {
  const minPaceMeters = 50.0; // en dessous, l'allure GPS n'est pas fiable
  const painLabels = ['😊 Aucune', '😐 Légère', '😬 Modérée', '😰 Forte'];
  const painColors = [AppTheme.statusSuccess, AppTheme.statusWarning, AppTheme.statusPainModerate, AppTheme.statusDanger];
  String pace(int seconds, double meters) {
    final s = (seconds / (meters / 1000)).round();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}/km';
  }
  Session? program(int dayIndex) {
    for (final s in [...tendiniteProgram, ...semiProgram]) {
      if (s.dayIndex == dayIndex) return s;
    }
    return null;
  }

  final done = logs.where((l) => l.completed).toList()..sort((a, b) => a.date.compareTo(b.date));
  var totalMeters = 0.0, pacedMeters = 0.0;
  var pacedSeconds = 0, runSeconds = 0;
  String? lastRunPace;
  int? lastPain;
  for (final log in done) {
    totalMeters += log.distanceMeters;
    if (log.painLevel != SessionLog.unratedPain) lastPain = log.painLevel.clamp(0, 3);
    final session = program(log.dayIndex);
    if (session == null) continue;
    final run = session.phases.where((p) => p.isRun).fold(0, (s, p) => s + p.durationSeconds);
    runSeconds += run;
    if (log.distanceMeters >= minPaceMeters) {
      pacedSeconds += session.totalDurationSeconds;
      pacedMeters += log.distanceMeters;
    }
    final runMeters = log.runMeters;
    final measured = log.runPaceSecPerKm;
    if (measured != null) {
      lastRunPace = pace(measured.round(), 1000);
    } else if (run > 0 && runMeters != null && runMeters >= minPaceMeters) {
      lastRunPace = pace(run, runMeters);
    }
  }

  final runMinutes = (runSeconds / 60).round();
  return [
    (label: 'Distance totale', value: '${(totalMeters / 1000).toStringAsFixed(1)} km', color: AppTheme.statusSuccess),
    (label: 'Dernière allure course', value: lastRunPace ?? '–', color: AppTheme.accentHighlight),
    (label: 'Allure moyenne', value: pacedMeters > 0 ? pace(pacedSeconds, pacedMeters) : '–', color: AppTheme.textPrimary),
    (label: 'Temps de course', value: '${runMinutes ~/ 60} h ${(runMinutes % 60).toString().padLeft(2, '0')}', color: AppTheme.statusInfo),
    (
      label: 'Douleur au tendon',
      value: lastPain == null ? 'Non renseignée' : painLabels[lastPain],
      color: lastPain == null ? AppTheme.textSecondary : painColors[lastPain],
    ),
  ];
}

/// Chiffres de la carte de partage d'un jour du programme : résultats si la
/// séance est faite, sinon son contenu prévu. Ni renfo ni douleur.
List<ShareStat> buildDayShareStats(Session s, SessionLog? log) {
  String minutes(int seconds) => "${(seconds / 60).round()} min";
  final run = s.phases.where((p) => p.isRun).fold(0, (a, p) => a + p.durationSeconds);
  final walk = s.phases.where((p) => p.isWalk).fold(0, (a, p) => a + p.durationSeconds);
  final stats = <ShareStat>[
    if (s.phases.isNotEmpty)
      (label: 'Durée', value: minutes(s.totalDurationSeconds), color: AppTheme.textPrimary),
    if (run > 0) (label: 'Temps de course', value: minutes(run), color: AppTheme.statusInfo),
  ];
  if (log == null) {
    return [
      ...stats,
      if (walk > 0) (label: 'Temps de marche', value: minutes(walk), color: AppTheme.textPrimary),
      if (s.runCount > 1) (label: 'Répétitions', value: '${s.runCount}', color: AppTheme.textPrimary),
      if (s.pe != null) (label: "Perception d'effort", value: '${s.pe}/10', color: AppTheme.accentHighlight),
    ];
  }
  final d = log.distanceMeters;
  final runMeters = log.runMeters;
  final pace = log.runPaceSecPerKm ??
      (run > 0 && runMeters != null && runMeters >= 50 ? run / (runMeters / 1000) : null);
  return [
    if (d > 0)
      (
        label: 'Distance',
        value: d < 1000 ? '${d.round()} m' : '${(d / 1000).toStringAsFixed(2)} km',
        color: AppTheme.statusSuccess,
      ),
    if (pace != null)
      (label: 'Allure course', value: PedometerService.formatPace(pace), color: AppTheme.accentHighlight),
    ...stats,
  ];
}

/// Aperçu de la carte aux couleurs de l'app, puis partage en PNG.
Future<void> showShareStatsDialog(BuildContext context, List<SessionLog> logs) {
  final today = DateTime.now();
  return showShareCardDialog(context,
      title: 'Mes stats',
      subtitle: 'Run Semi · ${today.day}/${today.month}/${today.year}',
      stats: buildShareStats(logs));
}

Future<void> showShareCardDialog(BuildContext context,
    {required String title, required String subtitle, required List<ShareStat> stats}) {
  final cardKey = GlobalKey();

  Future<void> share(BuildContext ctx) async {
    try {
      final boundary = cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('${(await getTemporaryDirectory()).path}/runsemi_stats.png');
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      if (!ctx.mounted) return;
      final box = ctx.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
      );
    } catch (e) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text('Partage impossible : $e'),
        backgroundColor: AppTheme.statusDanger,
      ));
    }
  }

  return showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppTheme.space24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        RepaintBoundary(
          key: cardKey,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radius24),
            child: Stack(children: [
              const Positioned.fill(child: AppBackground()),
              Padding(
                padding: const EdgeInsets.all(AppTheme.space20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(title, style: AppTheme.h2.copyWith(color: AppTheme.textPrimary)),
                  const SizedBox(height: AppTheme.space4),
                  Text(subtitle,
                      style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: AppTheme.textSecondary)),
                  const SizedBox(height: AppTheme.space16),
                  for (final s in stats) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space14, vertical: AppTheme.space12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceCard,
                        borderRadius: BorderRadius.circular(AppTheme.radius14),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Text(s.label,
                              style: Theme.of(ctx).textTheme.bodyLarge!.copyWith(color: AppTheme.textPrimary)),
                        ),
                        Text(s.value, style: AppTheme.h4.copyWith(color: s.color)),
                      ]),
                    ),
                    const SizedBox(height: AppTheme.space8),
                  ],
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: AppTheme.space16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          const SizedBox(width: AppTheme.space8),
          Builder(
            builder: (btnCtx) => FilledButton.icon(
              onPressed: () => share(btnCtx),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accentHighlight,
                foregroundColor: AppTheme.textOnHighlight,
              ),
              icon: const Icon(Icons.ios_share, size: 18),
              label: const Text('Partager', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ]),
    ),
  );
}
