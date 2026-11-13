import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../models/session.dart';
import '../data/tendinite_program.dart';
import '../theme/app_theme.dart';
import '../widgets/progression_chart.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  List<SessionLog> _logs = [];
  List<WorkoutLog> _workoutLogs = [];
  int _currentDay = 1;
  bool _remindersEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 18, minute: 0);
  bool _loading = true;
  String _versionLabel = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final logs = await StorageService.getLogs();
    final workoutLogs = await StorageService.getWorkoutLogs();
    final currentDay = await StorageService.getCurrentDay();
    final remindersEnabled = await StorageService.getRemindersEnabled();
    final reminderHour = await StorageService.getReminderHour();
    final reminderMinute = await StorageService.getReminderMinute();
    setState(() {
      _logs = logs;
      _workoutLogs = workoutLogs;
      _currentDay = currentDay;
      _remindersEnabled = remindersEnabled;
      _reminderTime = TimeOfDay(hour: reminderHour, minute: reminderMinute);
      _loading = false;
    });
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _versionLabel = 'v${info.version} (build ${info.buildNumber})');
  }

  Future<void> _toggleReminders(bool value) async {
    await StorageService.setRemindersEnabled(value);
    setState(() => _remindersEnabled = value);
    await NotificationService.refresh();
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(context: context, initialTime: _reminderTime);
    if (picked == null) return;
    await StorageService.setReminderTime(picked.hour, picked.minute);
    setState(() => _reminderTime = picked);
    await NotificationService.refresh();
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

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
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppTheme.accentHighlight,
          backgroundColor: AppTheme.surfaceCard,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppTheme.space24,
              AppTheme.space24,
              AppTheme.space24,
              AppTheme.space24 + AppTheme.space48,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Titre ────────────────────────────────────────
                Text('Statistiques', style: AppTheme.h1.copyWith(color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: _showEditCurrentDayDialog,
                  child: Row(children: [
                    Text('Phase 1 · Tendinite — Jour $_currentDay / ${tendiniteProgram.length}',
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(color: AppTheme.textSecondary)),
                    const SizedBox(width: 6),
                    const Icon(Icons.edit, size: 12, color: AppTheme.textMuted),
                  ]),
                ),
                const SizedBox(height: 16),

                // ── Progression (courbe distance, façon Santé) ────
                ProgressionChart(logs: _logs, workoutLogs: _workoutLogs, onChanged: _load),
                const SizedBox(height: 14),

                // ── Rappels ─────────────────────────────
                Container(
                  decoration: BoxDecoration(color: AppTheme.surfaceCard, borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Rappel quotidien',
                          style: Theme.of(context).textTheme.bodySmall!.copyWith(fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                      Switch(
                        value: _remindersEnabled,
                        activeThumbColor: AppTheme.accentPrimary,
                        onChanged: _toggleReminders,
                      ),
                    ]),
                    if (_remindersEnabled) ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: _pickReminderTime,
                        child: Row(children: [
                          const Icon(Icons.access_time, size: 14, color: AppTheme.textSecondary),
                          const SizedBox(width: 6),
                          Text('Heure : ${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')}',
                              style: Theme.of(context).textTheme.bodySmall!.copyWith(color: AppTheme.textSecondary)),
                        ]),
                      ),
                    ],
                  ]),
                ),
                const SizedBox(height: 14),
                // ── Ajouter une séance manuellement ─────────────────
                GestureDetector(
                  onTap: () => _showAddLogDialog(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.add_circle_outline, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 6),
                      Text('Ajouter une séance manuellement',
                          style: Theme.of(context).textTheme.bodySmall!.copyWith(color: AppTheme.textSecondary)),
                    ]),
                  ),
                ),
                // ── Export / Import manuel (survit à une désinstallation) ──
                GestureDetector(
                  onTap: _exportData,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.ios_share, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 6),
                      Text('Exporter mes données',
                          style: Theme.of(context).textTheme.bodySmall!.copyWith(color: AppTheme.textSecondary)),
                    ]),
                  ),
                ),
                GestureDetector(
                  onTap: _importData,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.file_download_outlined, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 6),
                      Text('Importer des données',
                          style: Theme.of(context).textTheme.bodySmall!.copyWith(color: AppTheme.textSecondary)),
                    ]),
                  ),
                ),
                // ── Bouton reset ───────────────────────────────────
                GestureDetector(
                  onTap: () => _confirmReset(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.refresh, size: 14, color: AppTheme.textMuted),
                      const SizedBox(width: 6),
                      Text('Réinitialiser les données',
                          style: Theme.of(context).textTheme.bodySmall!.copyWith(color: AppTheme.textMuted)),
                    ]),
                  ),
                ),
                const SizedBox(height: 8),
                if (_versionLabel.isNotEmpty)
                  Center(
                    child: Text(_versionLabel,
                        style: Theme.of(context).textTheme.labelSmall!.copyWith(color: AppTheme.textMuted)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Corrige le pointeur de progression si les saisies manuelles l'ont désynchronisé
  Future<void> _showEditCurrentDayDialog() async {
    final controller = TextEditingController(text: '$_currentDay');
    final newDay = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        title: Text('Jour actuel du programme', style: AppTheme.h4.copyWith(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppTheme.textPrimary),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text)),
            child: const Text('Enregistrer', style: TextStyle(color: AppTheme.accentHighlight, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (newDay == null) return;
    await StorageService.setCurrentDay(newDay.clamp(1, tendiniteProgram.length + 999));
    if (mounted) _load();
  }

  // Permet de recréer une séance perdue (ex. réinstallation de l'app sans backup à jour)
  Future<void> _showAddLogDialog(BuildContext context) async {
    final dayController = TextEditingController(text: '${(_currentDay - 1).clamp(1, 999)}');
    final distanceController = TextEditingController();
    final titleController = TextEditingController(text: 'Séance kettlebell');
    final durationController = TextEditingController(text: '30');
    final volumeController = TextEditingController();
    DateTime selectedDate = DateTime.now().subtract(const Duration(days: 1));
    int selectedPain = 0;
    bool isKb = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceCard,
          title: Text('Ajouter une séance', style: AppTheme.h4.copyWith(color: AppTheme.textPrimary)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Type', style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: [
                ChoiceChip(
                  label: Text('🏃 Course',
                      style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: !isKb ? AppTheme.textPrimary : AppTheme.textSecondary)),
                  selected: !isKb,
                  selectedColor: AppTheme.accentPrimary,
                  backgroundColor: AppTheme.surfaceRaised,
                  onSelected: (_) => setDialogState(() => isKb = false),
                ),
                ChoiceChip(
                  label: Text('🏋️ Kettlebell',
                      style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: isKb ? AppTheme.textPrimary : AppTheme.textSecondary)),
                  selected: isKb,
                  selectedColor: AppTheme.accentPrimary,
                  backgroundColor: AppTheme.surfaceRaised,
                  onSelected: (_) => setDialogState(() => isKb = true),
                ),
              ]),
              const SizedBox(height: 12),
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
              if (!isKb) ...[
                Text('Jour du programme', style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: AppTheme.textSecondary)),
                TextField(
                  controller: dayController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 12),
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
              ] else ...[
                Text('Titre de la séance', style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: AppTheme.textSecondary)),
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 12),
                Text('Durée (min)', style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: AppTheme.textSecondary)),
                TextField(
                  controller: durationController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 12),
                Text('Volume estimé (kg)', style: Theme.of(ctx).textTheme.bodySmall!.copyWith(color: AppTheme.textSecondary)),
                TextField(
                  controller: volumeController,
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
                if (isKb) {
                  final duration = int.tryParse(durationController.text) ?? 0;
                  final volume = double.tryParse(volumeController.text.replaceAll(',', '.')) ?? 0;
                  await StorageService.saveWorkoutLog(WorkoutLog(
                    date: selectedDate,
                    estimatedVolumeKg: volume,
                    durationMinutes: duration,
                    sessionTitle: titleController.text.trim().isEmpty
                        ? 'Séance kettlebell'
                        : titleController.text.trim(),
                  ));
                } else {
                  final day = int.tryParse(dayController.text) ?? _currentDay;
                  final km = double.tryParse(distanceController.text.replaceAll(',', '.')) ?? 0;
                  await StorageService.saveLog(SessionLog(
                    dayIndex: day,
                    date: selectedDate,
                    completed: true,
                    painLevel: selectedPain,
                    distanceMeters: km * 1000,
                  ));
                }
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) _load();
              },
              child: const Text('Ajouter', style: TextStyle(color: AppTheme.accentHighlight, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportData() async {
    try {
      final json = await StorageService.exportJson();
      final dir = await getTemporaryDirectory();
      await dir.create(recursive: true);
      final file = File('${dir.path}/runsemi_backup.json');
      await file.writeAsString(json);
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Sauvegarde Run Semi',
        sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Export impossible : $e'),
        backgroundColor: AppTheme.statusDanger,
      ));
    }
  }

  Future<void> _importData() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      final path = result?.files.single.path;
      if (path == null) return;

      final content = await File(path).readAsString();
      final ok = await StorageService.importJson(content);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Données importées avec succès.' : 'Fichier invalide, import annulé.'),
        backgroundColor: ok ? AppTheme.statusSuccess : AppTheme.statusDanger,
      ));
      if (ok) _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Import impossible : $e'),
        backgroundColor: AppTheme.statusDanger,
      ));
    }
  }

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        title: Text('Tout réinitialiser ?', style: AppTheme.h4.copyWith(color: AppTheme.textPrimary)),
        content: Text(
            'Toutes tes données seront supprimées. Le programme repart du Jour 1.',
            style: Theme.of(ctx).textTheme.bodyMedium!.copyWith(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await StorageService.resetAll();
              if (mounted) _load();
            },
            child: const Text('Réinitialiser',
                style: TextStyle(color: AppTheme.statusDanger, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
