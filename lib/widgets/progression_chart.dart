import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../data/tendinite_program.dart';
import '../data/semi_program.dart';
import '../models/session.dart';
import '../theme/app_theme.dart';
import 'session_detail_dialog.dart';

enum _ChartPeriod { week, month, quarter }

const _painEmojis = ['😊', '😐', '😬', '😰'];

/// Un point de courbe, avec la séance d'origine pour ouvrir son détail au tap.
class _MetricPoint {
  final int offset;
  final double value;
  final SessionLog? sessionLog;
  final WorkoutLog? workoutLog;
  const _MetricPoint({required this.offset, required this.value, this.sessionLog, this.workoutLog});
}

/// Courbes de progression façon "Santé" : onglets Semaine/Mois/Trimestre,
/// navigation par flèches, métriques empilées (distance, allure moyenne,
/// durée, douleur du tendon ; poids KB masqué) — et tap sur un point pour
/// ouvrir le détail du jour.
class ProgressionChart extends StatefulWidget {
  final List<SessionLog> logs;
  final List<WorkoutLog> workoutLogs;
  final VoidCallback onChanged;
  const ProgressionChart({super.key, required this.logs, required this.workoutLogs, required this.onChanged});

  @override
  State<ProgressionChart> createState() => _ProgressionChartState();
}

class _ProgressionChartState extends State<ProgressionChart> {
  static const _rangeDaysByPeriod = {
    _ChartPeriod.week: 7,
    _ChartPeriod.month: 30,
    _ChartPeriod.quarter: 90,
  };
  static const _periodLabels = {
    _ChartPeriod.week: 'Semaine',
    _ChartPeriod.month: 'Mois',
    _ChartPeriod.quarter: 'Trimestre',
  };
  static const _months = [
    'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
    'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
  ];
  static const _weekdays = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  // Courbe « Poids KB » masquée (code conservé) : repasser à true pour la réafficher.
  static const _showKbWeight = false;

  // En dessous, la distance GPS d'un type de phase est trop faible pour une allure fiable.
  static const _minPaceMeters = 50.0;

  // Zoom max au pincement (vue Semaine : pas de zoom, 7 jours tiennent déjà).
  static const _maxZoomByPeriod = {
    _ChartPeriod.week: 1.0,
    _ChartPeriod.month: 4.0,
    _ChartPeriod.quarter: 8.0,
  };

  _ChartPeriod _period = _ChartPeriod.week;
  late DateTime _rangeEnd;

  // Contrôleur de zoom partagé : les 5 courbes zooment et défilent ensemble.
  final _zoomController = TransformationController();
  double _zoom = 1;

  @override
  void initState() {
    super.initState();
    _rangeEnd = _today;
    _zoomController.addListener(_onZoomChanged);
  }

  @override
  void dispose() {
    _zoomController.removeListener(_onZoomChanged);
    _zoomController.dispose();
    super.dispose();
  }

  void _onZoomChanged() {
    final zoom = _zoomController.value.getMaxScaleOnAxis();
    // On ne reconstruit que si la densité des dates de l'axe change.
    if (_bottomIntervalFor(zoom) != _bottomIntervalFor(_zoom)) {
      setState(() => _zoom = zoom);
    } else {
      _zoom = zoom;
    }
  }

  void _resetZoom() {
    _zoomController.value = Matrix4.identity();
    _zoom = 1;
  }

  bool get _canZoom => _maxZoomByPeriod[_period]! > 1;
  bool get _isZoomed => _zoom > 1.01;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  int get _rangeDays => _rangeDaysByPeriod[_period]!;
  DateTime get _rangeStart => _rangeEnd.subtract(Duration(days: _rangeDays - 1));
  bool get _canGoNext => _rangeEnd.isBefore(_today);

  void _shift(int days) {
    setState(() {
      var next = _rangeEnd.add(Duration(days: days));
      if (next.isAfter(_today)) next = _today;
      _rangeEnd = next;
      _resetZoom();
    });
  }

  void _selectPeriod(_ChartPeriod p) {
    setState(() {
      _period = p;
      _rangeEnd = _today;
      _resetZoom();
    });
  }

  int? _offsetOf(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final offset = day.difference(_rangeStart).inDays;
    if (offset < 0 || offset >= _rangeDays) return null;
    return offset;
  }

  _MetricPoint? _pointAtOffset(List<_MetricPoint> points, int offset) {
    for (final p in points) {
      if (p.offset == offset) return p;
    }
    return null;
  }

  List<_MetricPoint> get _distancePoints {
    final points = <_MetricPoint>[];
    for (final log in widget.logs) {
      if (!log.completed) continue;
      final offset = _offsetOf(log.date);
      if (offset == null) continue;
      points.add(_MetricPoint(offset: offset, value: log.distanceMeters / 1000, sessionLog: log));
    }
    points.sort((a, b) => a.offset.compareTo(b.offset));
    return points;
  }

  // Séance du programme (phase 1 ou 2), retrouvée par dayIndex.
  Session? _programSession(int dayIndex) {
    for (final s in [...tendiniteProgram, ...semiProgram]) {
      if (s.dayIndex == dayIndex) return s;
    }
    return null;
  }

  int? _programMinutes(int dayIndex) => _programSession(dayIndex)?.totalDurationMinutes;

  // Allure (s/km) = durée prévue des phases retenues ÷ km parcourus pendant ces phases,
  // sauf si [measured] fournit une allure mesurée par l'accéléromètre.
  List<_MetricPoint> _pacePointsFor(bool Function(TimerPhase) phases, double? Function(SessionLog) meters,
      {double? Function(SessionLog)? measured}) {
    final points = <_MetricPoint>[];
    for (final log in widget.logs) {
      final measuredPace = measured?.call(log);
      if (log.completed && measuredPace != null) {
        final offset = _offsetOf(log.date);
        if (offset != null) points.add(_MetricPoint(offset: offset, value: measuredPace, sessionLog: log));
        continue;
      }
      final session = _programSession(log.dayIndex);
      final m = meters(log);
      if (!log.completed || session == null || m == null || m < _minPaceMeters) continue;
      final seconds = session.phases.where(phases).fold(0, (s, p) => s + p.durationSeconds);
      if (seconds <= 0) continue;
      final offset = _offsetOf(log.date);
      if (offset == null) continue;
      points.add(_MetricPoint(offset: offset, value: seconds / (m / 1000), sessionLog: log));
    }
    points.sort((a, b) => a.offset.compareTo(b.offset));
    return points;
  }

  List<_MetricPoint> get _pacePoints => _pacePointsFor((_) => true, (l) => l.distanceMeters);
  List<_MetricPoint> get _runPacePoints => _pacePointsFor((p) => p.isRun, (l) => l.runMeters,
      measured: (l) => l.runPaceSecPerKm);
  List<_MetricPoint> get _walkPacePoints => _pacePointsFor((p) => p.isWalk, (l) => l.walkMeters);

  // Lignes ajoutées à la bulle d'allure : allures course / marche du jour.
  String _paceDetail(int offset) {
    String at(List<_MetricPoint> pts) {
      final p = _pointAtOffset(pts, offset);
      return p == null ? '–' : _formatPace(p.value);
    }
    return '\nCourse ${at(_runPacePoints)}\nMarche ${at(_walkPacePoints)}';
  }

  String _formatPace(double secondsPerKm) {
    final total = secondsPerKm.round();
    return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}/km';
  }

  List<_MetricPoint> get _painPoints {
    final points = <_MetricPoint>[];
    for (final log in widget.logs) {
      if (!log.completed || log.painLevel == SessionLog.unratedPain) continue;
      final offset = _offsetOf(log.date);
      if (offset == null) continue;
      points.add(_MetricPoint(offset: offset, value: log.painLevel.toDouble(), sessionLog: log));
    }
    points.sort((a, b) => a.offset.compareTo(b.offset));
    return points;
  }

  List<_MetricPoint> get _kbWeightPoints {
    final points = <_MetricPoint>[];
    for (final log in widget.workoutLogs) {
      final offset = _offsetOf(log.date);
      if (offset == null) continue;
      points.add(_MetricPoint(offset: offset, value: log.estimatedVolumeKg, workoutLog: log));
    }
    points.sort((a, b) => a.offset.compareTo(b.offset));
    return points;
  }

  // Durée totale du jour = séance de course programmée (si complétée) + séance KB loggée.
  List<_MetricPoint> get _durationPoints {
    final byOffset = <int, _MetricPoint>{};
    for (final log in widget.logs) {
      if (!log.completed) continue;
      final offset = _offsetOf(log.date);
      if (offset == null) continue;
      final minutes = _programMinutes(log.dayIndex) ?? 0;
      final existing = byOffset[offset];
      byOffset[offset] = _MetricPoint(
        offset: offset,
        value: (existing?.value ?? 0) + minutes,
        sessionLog: log,
        workoutLog: existing?.workoutLog,
      );
    }
    for (final log in widget.workoutLogs) {
      final offset = _offsetOf(log.date);
      if (offset == null) continue;
      final existing = byOffset[offset];
      byOffset[offset] = _MetricPoint(
        offset: offset,
        value: (existing?.value ?? 0) + log.durationMinutes,
        sessionLog: existing?.sessionLog,
        workoutLog: log,
      );
    }
    final points = byOffset.values.where((p) => p.value > 0).toList()
      ..sort((a, b) => a.offset.compareTo(b.offset));
    return points;
  }

  String _fmt(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  String get _rangeLabel {
    final start = _rangeStart, end = _rangeEnd;
    return start.year == end.year
        ? '${_fmt(start)} – ${_fmt(end)} ${end.year}'
        : '${_fmt(start)} ${start.year} – ${_fmt(end)} ${end.year}';
  }

  double get _baseBottomInterval => switch (_period) {
    _ChartPeriod.week => 1,
    _ChartPeriod.month => 7,
    _ChartPeriod.quarter => 14,
  };

  // Plus on zoome, plus les dates de l'axe se resserrent (jusqu'à une par jour).
  double _bottomIntervalFor(double zoom) {
    final raw = _baseBottomInterval / zoom;
    for (final step in const [1.0, 2.0, 3.0, 7.0, 14.0]) {
      if (step >= raw) return step;
    }
    return 14;
  }

  double get _bottomInterval => _bottomIntervalFor(_zoom);

  void _openPointDetail(_MetricPoint point) {
    if (point.sessionLog != null) {
      showSessionDetailDialog(context, point.sessionLog!, onDeleted: widget.onChanged);
    } else if (point.workoutLog != null) {
      showWorkoutLogDetailDialog(context, point.workoutLog!, onDeleted: widget.onChanged);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppTheme.surfaceCard, borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Progression',
            style: Theme.of(context).textTheme.bodySmall!.copyWith(fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
        const SizedBox(height: 10),

        // Onglets Semaine / Mois / Trimestre
        Row(children: _ChartPeriod.values.map((p) {
          final selected = p == _period;
          return Expanded(
            child: GestureDetector(
              onTap: () => _selectPeriod(p),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.accentPrimary : AppTheme.surfaceRaised,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_periodLabels[p]!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall!.copyWith(
                        color: selected ? AppTheme.textPrimary : AppTheme.textSecondary,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          );
        }).toList()),
        const SizedBox(height: 12),

        // Navigation de la plage
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          GestureDetector(
            onTap: () => _shift(-_rangeDays),
            child: const Icon(Icons.chevron_left, color: AppTheme.textSecondary, size: 20),
          ),
          Text(_rangeLabel,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
          GestureDetector(
            onTap: _canGoNext ? () => _shift(_rangeDays) : null,
            child: Icon(Icons.chevron_right, color: _canGoNext ? AppTheme.textSecondary : AppTheme.textMuted, size: 20),
          ),
        ]),

        if (_canZoom)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(
                _isZoomed ? 'Zoom ×${_zoom.toStringAsFixed(1)}' : 'Pincez une courbe pour zoomer',
                style: Theme.of(context).textTheme.labelSmall!.copyWith(color: AppTheme.textMuted, fontSize: 10),
              ),
              if (_isZoomed)
                TextButton(
                  onPressed: () => setState(_resetZoom),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: AppTheme.accentPrimary,
                  ),
                  child: const Text('Réinitialiser', style: TextStyle(fontSize: 11)),
                ),
            ]),
          ),

        _metricSection(
          title: 'Distance (km)',
          color: AppTheme.statusSuccess,
          points: _distancePoints,
          valueLabel: (v) => '${v.toStringAsFixed(1)} km',
          numericAxis: true,
        ),
        _metricSection(
          title: 'Allure (min/km) · moyenne ── course ┄',
          extraPoints: _runPacePoints,
          color: AppTheme.accentHighlight,
          points: _pacePoints,
          valueLabel: (v) => 'Moyenne ${_formatPace(v)}',
          tooltipExtra: _paceDetail,
          zoomY: true,
          numericAxis: true,
          axisDivisor: 60,
        ),
        if (_showKbWeight)
        _metricSection(
          title: 'Poids KB (kgs)',
          color: AppTheme.accentHighlight,
          points: _kbWeightPoints,
          valueLabel: (v) => '${v.round()} kg',
          numericAxis: true,
        ),
        _metricSection(
          title: 'Durée (min)',
          color: AppTheme.statusInfo,
          points: _durationPoints,
          valueLabel: (v) => '${v.round()} min',
          numericAxis: true,
          axisStep: 15,
        ),
        _metricSection(
          title: "Douleur du tendon",
          color: AppTheme.statusWarning,
          points: _painPoints,
          valueLabel: (v) => _painEmojis[v.round().clamp(0, 3)],
          maxYOverride: 3,
        ),
      ]),
    );
  }

  Widget _metricSection({
    required String title,
    required Color color,
    required List<_MetricPoint> points,
    required String Function(double) valueLabel,
    double? maxYOverride,
    bool zoomY = false,
    bool numericAxis = false,
    double axisDivisor = 1,
    double? axisStep,
    String Function(int offset)? tooltipExtra,
    List<_MetricPoint> extraPoints = const [],
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: Theme.of(context).textTheme.labelSmall!.copyWith(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        if (points.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text('Aucune donnée sur cette période',
                style: Theme.of(context).textTheme.labelSmall!.copyWith(color: AppTheme.textMuted)),
          )
        else
          SizedBox(
            height: 120,
            child: _buildChart(points: points, color: color, valueLabel: valueLabel, maxYOverride: maxYOverride, zoomY: zoomY, numericAxis: numericAxis, axisDivisor: axisDivisor, axisStep: axisStep, tooltipExtra: tooltipExtra, extraPoints: extraPoints),
          ),
      ]),
    );
  }

  Widget _buildChart({
    required List<_MetricPoint> points,
    required Color color,
    required String Function(double) valueLabel,
    double? maxYOverride,
    bool zoomY = false,
    bool numericAxis = false,
    double axisDivisor = 1,
    double? axisStep,
    String Function(int offset)? tooltipExtra,
    List<_MetricPoint> extraPoints = const [],
  }) {
    final values = [...points, ...extraPoints].map((p) => p.value).toList();
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final minVal = values.reduce((a, b) => a < b ? a : b);
    // Allure : axe resserré autour des valeurs, sinon les variations écrasent la courbe.
    var minY = zoomY ? (minVal * 0.9).floorToDouble() : 0.0;
    var maxY = zoomY
        ? (maxVal * 1.1).ceilToDouble().clamp(minY + 1, double.infinity)
        : (maxYOverride ?? (maxVal <= 0 ? 1 : maxVal * 1.25));
    var gridInterval = (maxY - minY) / 3 == 0 ? 1.0 : (maxY - minY) / 3;
    if (numericAxis) {
      // Graduations entières (unité de l'axe) pour des labels sans décimales.
      const steps = [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000];
      final lo = zoomY ? (minVal / axisDivisor).floorToDouble() : 0.0;
      final hi = (maxVal / axisDivisor).ceilToDouble();
      final raw = (hi - lo) / 3;
      final step = axisStep ?? steps.firstWhere((s) => s >= raw, orElse: () => 1000).toDouble();
      minY = (zoomY ? (lo / step).floorToDouble() * step : 0.0) * axisDivisor;
      var top = (hi / step).ceilToDouble() * step;
      if (top * axisDivisor <= minY) top = minY / axisDivisor + step;
      maxY = top * axisDivisor;
      gridInterval = step * axisDivisor;
    }
    return LineChart(
      transformationConfig: FlTransformationConfig(
        scaleAxis: _canZoom ? FlScaleAxis.horizontal : FlScaleAxis.none,
        minScale: 1,
        maxScale: _maxZoomByPeriod[_period]!,
        transformationController: _zoomController,
      ),
      LineChartData(
        minX: 0,
        maxX: (_rangeDays - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: gridInterval,
          getDrawingHorizontalLine: (_) => const FlLine(color: AppTheme.surfaceRaised, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 46,
            interval: gridInterval,
            getTitlesWidget: (value, meta) => Text(
                numericAxis ? (value / axisDivisor).round().toString() : valueLabel(value),
                style: Theme.of(context).textTheme.labelSmall!.copyWith(color: AppTheme.textMuted, fontSize: 10)),
          )),
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 22,
            interval: _bottomInterval,
            getTitlesWidget: (value, meta) {
              final day = _rangeStart.add(Duration(days: value.round()));
              final label = _period == _ChartPeriod.week
                  ? _weekdays[day.weekday - 1]
                  : '${day.day}/${day.month}';
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(label,
                    style: Theme.of(context).textTheme.labelSmall!.copyWith(color: AppTheme.textMuted, fontSize: 10)),
              );
            },
          )),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: points.map((p) => FlSpot(p.offset.toDouble(), p.value)).toList(),
            isCurved: true,
            color: color,
            barWidth: 2.5,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.08)),
          ),
          if (extraPoints.isNotEmpty)
            LineChartBarData(
              spots: extraPoints.map((p) => FlSpot(p.offset.toDouble(), p.value)).toList(),
              isCurved: true,
              color: AppTheme.textSecondary,
              barWidth: 1.5,
              dashArray: const [4, 4],
              dotData: const FlDotData(show: true),
            ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppTheme.surfaceRaised,
            // Une seule bulle par jour : celle de la courbe principale (barIndex 0).
            getTooltipItems: (spots) => spots.map((s) {
              final point = s.barIndex == 0 ? _pointAtOffset(points, s.x.round()) : null;
              if (point == null) return null;
              final date = _rangeStart.add(Duration(days: point.offset));
              return LineTooltipItem(
                '${date.day}/${date.month}\n${valueLabel(point.value)}${tooltipExtra?.call(point.offset) ?? ''}',
                Theme.of(context).textTheme.labelSmall!.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
              );
            }).toList(),
          ),
          touchCallback: (event, response) {
            if (event is! FlTapUpEvent) return;
            final spots = response?.lineBarSpots;
            if (spots == null || spots.isEmpty) return;
            final point = _pointAtOffset(points, spots.first.x.round());
            if (point != null) _openPointDetail(point);
          },
        ),
      ),
    );
  }
}
