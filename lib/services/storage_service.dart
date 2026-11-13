import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session.dart';

/// Stockage local (SharedPreferences) + backup JSON dans le dossier Documents
/// de l'app, visible depuis l'app Fichiers iOS sous "Sur mon iPhone/iPad › Run Semi"
/// (grâce à `UIFileSharingEnabled` dans Info.plist).
///
/// Fichier de backup : Sur mon iPhone / Run Semi / runsemi_backup.json
///
/// ⚠️ Ceci N'EST PAS un vrai sync iCloud Drive (qui nécessiterait la capacité
/// "iCloud Documents"/"iCloud Key-value" + un compte Apple Developer Program
/// PAYANT — les comptes personnels gratuits ne supportent pas la capacité
/// iCloud, même pour du simple key-value) : le dossier ne survit donc PAS à une
/// désinstallation complète de l'app. Il survit en revanche sans problème à une
/// simple mise à jour (réinstallation par-dessus la même app, TestFlight, App
/// Store) — SharedPreferences et ce dossier Documents ne sont jamais effacés
/// par iOS lors d'une mise à jour.
class StorageService {
  static const _currentDayKey = 'current_day';
  static const _kbIndexKey = 'kb_index';
  static const _logsKey = 'session_logs';
  static const _workoutLogsKey = 'workout_logs';
  static const _lastCompletionDayKey = 'last_completion_day';
  static const _lastCompletionDateKey = 'last_completion_date';
  static const _backupFileName = 'runsemi_backup.json';
  static const _remindersEnabledKey = 'reminders_enabled';
  static const _reminderHourKey = 'reminder_hour';
  static const _reminderMinuteKey = 'reminder_minute';

  // ── BACKUP ICLOUD DRIVE ───────────────────────────────────────────────────

  static Future<File?> _backupFile() async {
    try {
      // Dossier Documents de l'app — rendu visible dans Fichiers grâce à
      // UIFileSharingEnabled (Info.plist), directement à la racine pour
      // apparaître comme "Sur mon iPhone › Run Semi › runsemi_backup.json".
      final docsDir = await getApplicationDocumentsDirectory();
      return File('${docsDir.path}/$_backupFileName');
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> _buildBackup() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      _currentDayKey: prefs.getInt(_currentDayKey) ?? 1,
      _kbIndexKey: prefs.getInt(_kbIndexKey) ?? 1,
      _logsKey: prefs.getString(_logsKey) ?? '[]',
      _workoutLogsKey: prefs.getString(_workoutLogsKey) ?? '[]',
      _lastCompletionDayKey: prefs.getInt(_lastCompletionDayKey),
      _lastCompletionDateKey: prefs.getString(_lastCompletionDateKey),
    };
  }

  /// Écrit le backup JSON — appelé automatiquement après chaque sauvegarde.
  static Future<void> _writeBackup() async {
    try {
      final file = await _backupFile();
      if (file == null) return;
      final data = await _buildBackup();
      await file.writeAsString(jsonEncode(data));
    } catch (_) {
      // Backup silencieux — ne bloque pas l'app
    }
  }

  /// Restaure depuis le backup JSON si les données locales sont absentes.
  static Future<bool> restoreFromBackup() async {
    try {
      final file = await _backupFile();
      if (file == null || !await file.exists()) return false;

      final content = await file.readAsString();
      final prefs = await SharedPreferences.getInstance();

      // Ne restaure que si les données locales sont vraiment vides
      if (prefs.containsKey(_logsKey)) return false;

      return await _applyBackup(content);
    } catch (_) {
      return false;
    }
  }

  // ── EXPORT / IMPORT MANUEL ────────────────────────────────────────────────
  // Seule option pour conserver les données à travers une désinstallation
  // complète : le compte Apple Developer gratuit ne permet aucune capacité
  // iCloud (voir commentaire de classe ci-dessus).

  /// Contenu JSON à partager (export manuel via le Share Sheet, etc.).
  static Future<String> exportJson() async {
    final data = await _buildBackup();
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Réimporte un JSON exporté précédemment, en écrasant les données locales.
  static Future<bool> importJson(String content) => _applyBackup(content);

  static Future<bool> _applyBackup(String content) async {
    try {
      final data = jsonDecode(content) as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();

      if (data[_currentDayKey] != null) {
        await prefs.setInt(_currentDayKey, data[_currentDayKey] as int);
      }
      if (data[_kbIndexKey] != null) {
        await prefs.setInt(_kbIndexKey, data[_kbIndexKey] as int);
      }
      if (data[_logsKey] != null) {
        await prefs.setString(_logsKey, data[_logsKey] as String);
      }
      if (data[_workoutLogsKey] != null) {
        await prefs.setString(_workoutLogsKey, data[_workoutLogsKey] as String);
      }
      if (data[_lastCompletionDayKey] != null) {
        await prefs.setInt(
            _lastCompletionDayKey, data[_lastCompletionDayKey] as int);
      }
      if (data[_lastCompletionDateKey] != null) {
        await prefs.setString(
            _lastCompletionDateKey, data[_lastCompletionDateKey] as String);
      }
      await _writeBackup();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── PROGRAMME COURSE ──────────────────────────────────────────────────────

  static Future<int> getCurrentDay() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_currentDayKey) ?? 1;
  }

  static Future<void> setCurrentDay(int day) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_currentDayKey, day);
    await _writeBackup();
  }

  // Position dans le cycle des 7 séances KB — avance uniquement quand une séance est faite
  static Future<int> getCurrentKbIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kbIndexKey) ?? 1;
  }

  static Future<void> setCurrentKbIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kbIndexKey, index);
    await _writeBackup();
  }

  // ── RAPPELS ────────────────────────────────────────────────────────────────

  static Future<bool> getRemindersEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_remindersEnabledKey) ?? false;
  }

  static Future<void> setRemindersEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_remindersEnabledKey, enabled);
  }

  static Future<int> getReminderHour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_reminderHourKey) ?? 18;
  }

  static Future<int> getReminderMinute() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_reminderMinuteKey) ?? 0;
  }

  static Future<void> setReminderTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_reminderHourKey, hour);
    await prefs.setInt(_reminderMinuteKey, minute);
  }

  static Future<List<SessionLog>> getLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_logsKey);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list
        .map((e) => SessionLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> saveLog(SessionLog log) async {
    final prefs = await SharedPreferences.getInstance();
    final logs = await getLogs();
    logs.removeWhere((l) => l.dayIndex == log.dayIndex);
    logs.add(log);
    await prefs.setString(
        _logsKey, jsonEncode(logs.map((l) => l.toJson()).toList()));
    await _writeBackup();
  }

  static Future<SessionLog?> getLogForDay(int dayIndex) async {
    final logs = await getLogs();
    try {
      return logs.firstWhere((l) => l.dayIndex == dayIndex);
    } catch (_) {
      return null;
    }
  }

  /// Supprime la séance de course d'un jour — permet de la remplacer ensuite.
  static Future<void> deleteLog(int dayIndex) async {
    final prefs = await SharedPreferences.getInstance();
    final logs = await getLogs();
    logs.removeWhere((l) => l.dayIndex == dayIndex);
    await prefs.setString(
        _logsKey, jsonEncode(logs.map((l) => l.toJson()).toList()));
    await _writeBackup();
  }

  // ── COMPLETION TRACKING ───────────────────────────────────────────────────

  static Future<bool> wasCompletedToday() async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = prefs.getString(_lastCompletionDateKey);
    if (dateStr == null) return false;
    final date = DateTime.parse(dateStr);
    final now = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    if (!isToday) return false;
    // Le jour courant a déjà avancé après validation : la séance suivante n'est pas faite.
    final lastDay = prefs.getInt(_lastCompletionDayKey);
    final currentDay = prefs.getInt(_currentDayKey) ?? 1;
    return lastDay == null || lastDay == currentDay;
  }

  static Future<int?> getLastCompletedDay() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lastCompletionDayKey);
  }

  static Future<void> saveCompletion(int dayIndex) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastCompletionDayKey, dayIndex);
    await prefs.setString(
        _lastCompletionDateKey, DateTime.now().toIso8601String());
    await _writeBackup();
  }

  // ── SÉANCES KB ────────────────────────────────────────────────────────────

  static Future<List<WorkoutLog>> getWorkoutLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_workoutLogsKey);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list
        .map((e) => WorkoutLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> saveWorkoutLog(WorkoutLog log) async {
    final prefs = await SharedPreferences.getInstance();
    final logs = await getWorkoutLogs();
    logs.add(log);
    await prefs.setString(
        _workoutLogsKey,
        jsonEncode(logs.map((l) => l.toJson()).toList()));
    await _writeBackup();
  }

  /// Supprime une séance KB — comparée par valeur, car WorkoutLog n'a pas d'id. Permet de la remplacer ensuite.
  static Future<void> deleteWorkoutLog(WorkoutLog log) async {
    final prefs = await SharedPreferences.getInstance();
    final logs = await getWorkoutLogs();
    logs.removeWhere((l) =>
        l.date.isAtSameMomentAs(log.date) &&
        l.sessionTitle == log.sessionTitle &&
        l.durationMinutes == log.durationMinutes &&
        l.estimatedVolumeKg == log.estimatedVolumeKg);
    await prefs.setString(
        _workoutLogsKey,
        jsonEncode(logs.map((l) => l.toJson()).toList()));
    await _writeBackup();
  }

  // ── RESET COMPLET ─────────────────────────────────────────────────────────

  /// Supprime toutes les données — repart du Jour 1.
  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // Supprime aussi le backup JSON
    try {
      final file = await _backupFile();
      if (file != null && await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
