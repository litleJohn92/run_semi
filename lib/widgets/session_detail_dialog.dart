import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/session.dart';
import '../data/tendinite_program.dart';
import '../data/semi_program.dart';
import '../services/pedometer_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

const _painEmojis = ['😊', '😐', '😬', '😰'];

// Durée prévue de la séance du programme (phase 1 ou 2), retrouvée par dayIndex.
int? _programMinutes(int dayIndex) {
  for (final s in [...tendiniteProgram, ...semiProgram]) {
    if (s.dayIndex == dayIndex) return s.totalDurationMinutes;
  }
  return null;
}

String? _paceLabel(SessionLog log) {
  final minutes = _programMinutes(log.dayIndex);
  if (minutes == null || minutes <= 0 || log.distanceMeters <= 0) return null;
  final total = ((minutes * 60) / (log.distanceMeters / 1000)).round();
  return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}/km';
}

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

/// Popup tracé GPS + résumé d'une séance déjà réalisée, réutilisée par
/// l'écran Programme (et potentiellement ailleurs).
/// [onDeleted] est appelé après suppression pour permettre à l'appelant de
/// rafraîchir ses données (la séance peut alors être resaisie).
void showSessionDetailDialog(BuildContext context, SessionLog log, {VoidCallback? onDeleted}) {
  final points = log.route?.map((p) => LatLng(p[0], p[1])).toList() ?? [];

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surfaceCard,
      title: Text('Jour ${log.dayIndex} · ${log.date.day}/${log.date.month}/${log.date.year}',
          style: AppTheme.h4.copyWith(color: AppTheme.textPrimary)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (points.length >= 2)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              // Largeur fixe : AlertDialog mesure sa largeur intrinsèque, que FlutterMap ne supporte pas.
              child: SizedBox(
                width: double.maxFinite,
                height: 180,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: points[points.length ~/ 2],
                    initialZoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.yannick.runsemi',
                    ),
                    PolylineLayer(polylines: [
                      Polyline(points: points, color: AppTheme.accentHighlight, strokeWidth: 4),
                    ]),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('Aucun tracé GPS enregistré pour cette séance.',
                  style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: AppTheme.textSecondary)),
            ),
          const SizedBox(height: 12),
          Text(
            'Distance : ${log.distanceMeters < 1000 ? '${log.distanceMeters.round()} m' : '${(log.distanceMeters / 1000).toStringAsFixed(2)} km'}',
            style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 4),
          if (_programMinutes(log.dayIndex) != null) ...[
            Text(
              'Durée : ${_programMinutes(log.dayIndex)} min',
              style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 4),
          ],
          if (_paceLabel(log) != null) ...[
            Text(
              'Allure moyenne : ${_paceLabel(log)}',
              style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 4),
          ],
          if (log.runPaceSecPerKm != null) ...[
            Text(
              'Allure course : ${PedometerService.formatPace(log.runPaceSecPerKm)}',
              style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            'Douleur : ${log.painLevel == SessionLog.unratedPain ? 'non renseignée' : _painEmojis[log.painLevel.clamp(0, 3)]}',
            style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: AppTheme.textSecondary),
          ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            final confirmed = await _confirmDelete(ctx, 'Cette séance de course sera supprimée. Tu pourras la ressaisir ensuite.');
            if (!confirmed) return;
            await StorageService.deleteLog(log.dayIndex);
            if (ctx.mounted) Navigator.pop(ctx);
            onDeleted?.call();
          },
          child: const Text('🗑 Supprimer', style: TextStyle(color: AppTheme.statusDanger)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Fermer', style: TextStyle(color: AppTheme.accentHighlight)),
        ),
      ],
    ),
  );
}

/// Popup résumé d'une séance kettlebell déjà réalisée — pendant de
/// [showSessionDetailDialog] pour les courbes KB (poids, durée) des Stats.
void showWorkoutLogDetailDialog(BuildContext context, WorkoutLog log, {VoidCallback? onDeleted}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surfaceCard,
      title: Text('${log.sessionTitle} · ${log.date.day}/${log.date.month}/${log.date.year}',
          style: AppTheme.h4.copyWith(color: AppTheme.textPrimary)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Durée : ${log.durationMinutes} min',
            style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: AppTheme.textPrimary)),
        const SizedBox(height: 4),
        Text('Volume estimé : ${log.estimatedVolumeKg.round()} kg',
            style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: AppTheme.textPrimary)),
      ]),
      actions: [
        TextButton(
          onPressed: () async {
            final confirmed = await _confirmDelete(ctx, 'Cette séance kettlebell sera supprimée. Tu pourras la ressaisir ensuite.');
            if (!confirmed) return;
            await StorageService.deleteWorkoutLog(log);
            if (ctx.mounted) Navigator.pop(ctx);
            onDeleted?.call();
          },
          child: const Text('🗑 Supprimer', style: TextStyle(color: AppTheme.statusDanger)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Fermer', style: TextStyle(color: AppTheme.accentHighlight)),
        ),
      ],
    ),
  );
}
