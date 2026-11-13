import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';

import 'health_state.dart';
import 'providers.dart';

const _logKey = 'body_log_v1';
const _maxEntries = 300;

/// Как часто просить взвеситься.
const weighInEvery = Duration(days: 3);

/// Замер тела: вес вводит человек, состав тела приходит с часов (анализ тела
/// в Samsung Health и других → Health Connect). Хранится только на телефоне.
class BodyMeasurement {
  const BodyMeasurement({
    required this.at,
    this.weightKg,
    this.fatPct,
    this.leanKg,
    this.waterKg,
    this.bmrKcal,
    this.source,
  });

  final DateTime at;
  final double? weightKg;

  /// Процент жира.
  final double? fatPct;

  /// Безжировая масса (мышцы, кости, вода), кг.
  final double? leanKg;
  final double? waterKg;

  /// Базовый обмен, ккал/сутки.
  final double? bmrKcal;

  /// Откуда состав тела: приложение-источник в Health Connect; null — ручной вес.
  final String? source;

  bool get hasComposition =>
      fatPct != null || leanKg != null || waterKg != null || bmrKcal != null;

  Map<String, dynamic> toJson() => {
    'at': at.toIso8601String(),
    'weightKg': ?weightKg,
    'fatPct': ?fatPct,
    'leanKg': ?leanKg,
    'waterKg': ?waterKg,
    'bmrKcal': ?bmrKcal,
    'source': ?source,
  };

  factory BodyMeasurement.fromJson(Map<String, dynamic> j) => BodyMeasurement(
    at: DateTime.parse(j['at'] as String),
    weightKg: (j['weightKg'] as num?)?.toDouble(),
    fatPct: (j['fatPct'] as num?)?.toDouble(),
    leanKg: (j['leanKg'] as num?)?.toDouble(),
    waterKg: (j['waterKg'] as num?)?.toDouble(),
    bmrKcal: (j['bmrKcal'] as num?)?.toDouble(),
    source: j['source'] as String?,
  );
}

/// Сводка для экрана: последние значения и проценты от веса.
class BodySnapshot {
  const BodySnapshot({
    this.weightKg,
    this.weighedAt,
    this.fatPct,
    this.leanPct,
    this.waterPct,
    this.bmrKcal,
    this.analysedAt,
  });

  final double? weightKg;
  final DateTime? weighedAt;
  final double? fatPct;

  /// Безжировая масса от веса, % — мышцы с костями и водой.
  final double? leanPct;
  final double? waterPct;
  final double? bmrKcal;
  final DateTime? analysedAt;
}

/// Журнал замеров, от новых к старым.
class BodyLogNotifier extends Notifier<List<BodyMeasurement>> {
  AppLifecycleListener? _lifecycle;

  @override
  List<BodyMeasurement> build() {
    // Вернулись в приложение — вдруг на часах сделали анализ тела.
    _lifecycle ??= AppLifecycleListener(onResume: importFromHealth);
    ref.onDispose(() => _lifecycle?.dispose());
    Future.microtask(importFromHealth);
    final raw = ref.read(prefsProvider).getString(_logKey);
    if (raw == null) return const [];
    try {
      return [
        for (final e in jsonDecode(raw) as List)
          BodyMeasurement.fromJson(Map<String, dynamic>.from(e)),
      ]..sort((a, b) => b.at.compareTo(a.at));
    } catch (_) {
      return const [];
    }
  }

  Future<void> _save(List<BodyMeasurement> list) async {
    final sorted = [...list]..sort((a, b) => b.at.compareTo(a.at));
    state = sorted.take(_maxEntries).toList();
    await ref
        .read(prefsProvider)
        .setString(_logKey, jsonEncode([for (final m in state) m.toJson()]));
  }

  /// Ручное взвешивание. Вес идёт и в профиль: от него считаются лесенки упражнений.
  Future<void> addWeight(double kg, {DateTime? at}) async {
    await _save([
      BodyMeasurement(at: at ?? DateTime.now(), weightKg: kg),
      ...state,
    ]);
    final hero = ref.read(heroProvider);
    if (hero != null) {
      await ref
          .read(heroProvider.notifier)
          .setBody(hero.body.copyWith(weightKg: kg));
    }
  }

  /// Состав тела из Health Connect за 60 дней: новые замеры добавляются сами.
  /// Возвращает, сколько новых замеров нашлось.
  Future<int> importFromHealth() async {
    final points = await ref
        .read(healthProvider.notifier)
        .bodyComposition(
          since: DateTime.now().subtract(const Duration(days: 60)),
        );
    if (points.isEmpty) return 0;
    final fresh = mergeComposition(state, points);
    if (fresh.isEmpty) return 0;
    await _save([...fresh, ...state]);
    return fresh.length;
  }
}

final bodyLogProvider =
    NotifierProvider<BodyLogNotifier, List<BodyMeasurement>>(
      BodyLogNotifier.new,
    );

/// Точки Health Connect → замеры. Точки одного анализа (в пределах 10 минут)
/// склеиваются в один замер; уже записанные (то же время и источник) пропускаются.
List<BodyMeasurement> mergeComposition(
  List<BodyMeasurement> existing,
  List<HealthDataPoint> points,
) {
  final known = {
    for (final m in existing)
      if (m.hasComposition) '${m.source}|${m.at.millisecondsSinceEpoch}',
  };
  final sorted = [...points]..sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
  final groups = <List<HealthDataPoint>>[];
  for (final p in sorted) {
    final last = groups.isEmpty ? null : groups.last;
    if (last != null &&
        p.dateFrom.difference(last.first.dateFrom).inMinutes.abs() <= 10 &&
        p.sourceName == last.first.sourceName) {
      last.add(p);
    } else {
      groups.add([p]);
    }
  }
  final out = <BodyMeasurement>[];
  for (final g in groups) {
    double? of(HealthDataType t) {
      final p = g.where((p) => p.type == t).firstOrNull;
      final v = p?.value;
      return v is NumericHealthValue ? v.numericValue.toDouble() : null;
    }

    final at = g.first.dateFrom;
    final source = g.first.sourceName.isNotEmpty
        ? g.first.sourceName
        : g.first.sourceId;
    if (known.contains('$source|${at.millisecondsSinceEpoch}')) continue;
    var fat = of(HealthDataType.BODY_FAT_PERCENTAGE);
    // Health Connect отдаёт процент как 0–100; у некоторых источников 0–1.
    if (fat != null && fat <= 1) fat *= 100;
    out.add(
      BodyMeasurement(
        at: at,
        fatPct: fat,
        leanKg: of(HealthDataType.LEAN_BODY_MASS),
        waterKg: of(HealthDataType.BODY_WATER_MASS),
        bmrKcal: of(HealthDataType.BASAL_ENERGY_BURNED),
        source: source,
      ),
    );
  }
  return out.where((m) => m.hasComposition).toList();
}

/// Последние значения. Проценты массы — от веса, ближайшего к анализу (±7 дней).
BodySnapshot bodySnapshot(List<BodyMeasurement> log) {
  final weighed = log.where((m) => m.weightKg != null).firstOrNull;
  final analysis = log.where((m) => m.hasComposition).firstOrNull;
  double? weightNear(DateTime at) {
    BodyMeasurement? best;
    for (final m in log.where((m) => m.weightKg != null)) {
      final d = m.at.difference(at).abs();
      if (d > const Duration(days: 7)) continue;
      if (best == null || d < best.at.difference(at).abs()) best = m;
    }
    return best?.weightKg;
  }

  final w = analysis == null ? null : weightNear(analysis.at);
  double? pct(double? kg) =>
      kg == null || w == null || w <= 0 ? null : kg / w * 100;
  return BodySnapshot(
    weightKg: weighed?.weightKg,
    weighedAt: weighed?.at,
    fatPct: analysis?.fatPct,
    leanPct: pct(analysis?.leanKg),
    waterPct: pct(analysis?.waterKg),
    bmrKcal: analysis?.bmrKcal,
    analysedAt: analysis?.at,
  );
}

/// Пора взвеситься: веса нет или последнему 3 дня и больше.
bool weighInDue(List<BodyMeasurement> log, DateTime now) {
  final last = log.where((m) => m.weightKg != null).firstOrNull;
  return last == null || now.difference(last.at) >= weighInEvery;
}

/// Изменение веса за [days] дней: последний минус ближайший к началу периода.
double? weightChange(List<BodyMeasurement> log, DateTime now, {int days = 30}) {
  final weights = log.where((m) => m.weightKg != null).toList();
  if (weights.length < 2) return null;
  final from = now.subtract(Duration(days: days));
  final older =
      weights.where((m) => !m.at.isAfter(from)).firstOrNull ?? weights.last;
  if (identical(older, weights.first)) return null;
  return weights.first.weightKg! - older.weightKg!;
}
