import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

import '../game/anti_fraud.dart';
import 'providers.dart';

const _connectedKey = 'health_connected';

const _types = [
  HealthDataType.HEART_RATE,
  HealthDataType.STEPS,
  HealthDataType.DISTANCE_DELTA,
];

enum HealthStatus {
  /// Ещё не проверяли.
  unknown,

  /// Health Connect не установлен или требует обновления.
  needsInstall,

  /// Установлен, но доступ не выдан.
  notConnected,
  connected,
}

class HealthState {
  const HealthState({
    this.status = HealthStatus.unknown,
    this.stepsToday,
    this.metersToday,
    this.updatedAt,
  });

  final HealthStatus status;
  final int? stepsToday;
  final double? metersToday;
  final DateTime? updatedAt;

  bool get connected => status == HealthStatus.connected;
}

/// Шаги, расстояние и пульс из Health Connect — общего хранилища здоровья Android.
/// Galaxy Watch пишет туда через Samsung Health, а также Pixel Watch, Mi Fitness,
/// Zepp (Amazfit), Garmin Connect и другие. Только чтение.
class HealthNotifier extends Notifier<HealthState> {
  final _health = Health();
  bool _configured = false;
  AppLifecycleListener? _lifecycle;

  @override
  HealthState build() {
    final wasConnected =
        ref.read(prefsProvider).getBool(_connectedKey) ?? false;
    if (wasConnected) {
      Future.microtask(refresh);
      // Вернулись в приложение — шаги могли вырасти.
      _lifecycle ??= AppLifecycleListener(onResume: refresh);
      ref.onDispose(() => _lifecycle?.dispose());
    }
    return HealthState(
      status: wasConnected ? HealthStatus.connected : HealthStatus.unknown,
    );
  }

  Future<bool> _ensureConfigured() async {
    if (_configured) return true;
    try {
      await _health.configure();
      _configured = true;
    } catch (e) {
      debugPrint('Health не настроен: $e');
    }
    return _configured;
  }

  Future<bool> _available() async {
    if (!await _ensureConfigured()) return false;
    final sdk = await _health.getHealthConnectSdkStatus();
    if (sdk != HealthConnectSdkStatus.sdkAvailable) {
      state = const HealthState(status: HealthStatus.needsInstall);
      return false;
    }
    return true;
  }

  /// Запросить доступ. true — разрешено.
  Future<bool> connect() async {
    if (!await _available()) return false;
    await Permission.activityRecognition.request();
    final granted = await _health.requestAuthorization(
      _types,
      permissions: [for (final _ in _types) HealthDataAccess.READ],
    );
    await ref.read(prefsProvider).setBool(_connectedKey, granted);
    state = HealthState(
      status: granted ? HealthStatus.connected : HealthStatus.notConnected,
    );
    if (granted) await refresh();
    return granted;
  }

  Future<void> installHealthConnect() async {
    if (await _ensureConfigured()) await _health.installHealthConnect();
  }

  Future<void> disconnect() async {
    await ref.read(prefsProvider).setBool(_connectedKey, false);
    state = const HealthState(status: HealthStatus.notConnected);
  }

  /// Шаги и расстояние за сегодня.
  Future<void> refresh() async {
    if (!await _available()) return;
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final steps = await _health.getTotalStepsInInterval(midnight, now);
      final distance = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.DISTANCE_DELTA],
        startTime: midnight,
        endTime: now,
      );
      final meters = distance.fold<double>(0, (sum, p) => sum + _number(p));
      state = HealthState(
        status: HealthStatus.connected,
        stepsToday: steps,
        metersToday: meters,
        updatedAt: now,
      );
    } catch (e) {
      // Доступ отозвали в настройках Health Connect.
      debugPrint('Health Connect: $e');
      state = const HealthState(status: HealthStatus.notConnected);
    }
  }

  /// Пульс за промежуток — для проверки тренировки, когда часы не транслировали его
  /// по Bluetooth. Пусто, если доступа нет или часы ещё не синхронизировались.
  Future<List<PulseSample>> heartRateBetween(DateTime from, DateTime to) async {
    if (!state.connected || !await _available()) return const [];
    try {
      final points = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.HEART_RATE],
        startTime: from,
        endTime: to,
      );
      return [
        for (final p in points)
          if (_number(p) > 0) PulseSample(p.dateFrom, _number(p).round()),
      ]..sort((a, b) => a.at.compareTo(b.at));
    } catch (e) {
      debugPrint('Health Connect пульс: $e');
      return const [];
    }
  }

  /// Кто пишет в Health Connect пульс и шаги за неделю: приложение, сколько
  /// записей и когда последняя. Пусто — нет доступа или данных.
  Future<List<HealthSource>> sources() async {
    if (!state.connected || !await _available()) return const [];
    try {
      final now = DateTime.now();
      final points = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.HEART_RATE, HealthDataType.STEPS],
        startTime: now.subtract(const Duration(days: 7)),
        endTime: now,
      );
      final bySource = <String, HealthSource>{};
      for (final p in points) {
        final name = p.sourceName.isNotEmpty ? p.sourceName : p.sourceId;
        final old = bySource[name];
        final pulse = p.type == HealthDataType.HEART_RATE;
        bySource[name] = HealthSource(
          name: appLabelFor(name),
          id: name,
          records: (old?.records ?? 0) + 1,
          hasPulse: (old?.hasPulse ?? false) || pulse,
          hasSteps: (old?.hasSteps ?? false) || !pulse,
          lastAt: old == null || p.dateTo.isAfter(old.lastAt)
              ? p.dateTo
              : old.lastAt,
        );
      }
      return bySource.values.toList()
        ..sort((a, b) => b.lastAt.compareTo(a.lastAt));
    } catch (e) {
      debugPrint('Health Connect источники: $e');
      return const [];
    }
  }

  static double _number(HealthDataPoint p) {
    final v = p.value;
    return v is NumericHealthValue ? v.numericValue.toDouble() : 0;
  }
}

final healthProvider = NotifierProvider<HealthNotifier, HealthState>(
  HealthNotifier.new,
);

/// Приложение, которое пишет данные в Health Connect.
class HealthSource {
  const HealthSource({
    required this.name,
    required this.id,
    required this.records,
    required this.hasPulse,
    required this.hasSteps,
    required this.lastAt,
  });

  final String name;
  final String id;
  final int records;
  final bool hasPulse;
  final bool hasSteps;
  final DateTime lastAt;
}

/// Понятное имя по пакету приложения: com.sec.android.app.shealth → Samsung Health.
String appLabelFor(String packageOrName) {
  const known = {
    'com.sec.android.app.shealth': 'Samsung Health',
    'com.mi.health': 'Mi Fitness',
    'com.xiaomi.wearable': 'Mi Fitness',
    'com.huami.watch.hmwatchmanager': 'Zepp',
    'com.huawei.health': 'Huawei Health',
    'com.google.android.apps.fitness': 'Google Fit',
    'com.fitbit.FitbitMobile': 'Fitbit',
    'com.garmin.android.apps.connectmobile': 'Garmin Connect',
    'fi.polar.polarflow': 'Polar Flow',
    'com.stt.android.suunto': 'Suunto',
    'com.google.android.apps.healthdata': 'Health Connect',
  };
  return known[packageOrName] ??
      (packageOrName.startsWith('com.ironrise') ? 'IronRise' : packageOrName);
}
