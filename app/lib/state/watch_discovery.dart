import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../game/watch_detect.dart';
import 'heart_rate_state.dart';
import 'providers.dart';

const _devices = MethodChannel('ironrise/devices');

/// Что нашёл мастер «Найти мои часы».
class WatchDiscovery {
  const WatchDiscovery({
    this.searching = false,
    this.done = false,
    this.watches = const [],
    this.brandsByApp = const {},
    this.watchApp = false,
    this.noPermission = false,
    this.waitingFor,
  });

  final bool searching;

  /// Поиск прошёл хотя бы раз — показываем итог, даже пустой.
  final bool done;
  final List<DetectedWatch> watches;

  /// Марки, чьи приложения стоят, а часов рядом не видно.
  final Set<String> brandsByApp;

  /// На часах Wear OS стоит IronRise (ответили версией).
  final bool watchApp;

  /// Не дали разрешение «Устройства поблизости».
  final bool noPermission;

  /// Ждём трансляцию пульса с этих часов.
  final DetectedWatch? waitingFor;

  WatchDiscovery copyWith({
    bool? searching,
    bool? done,
    List<DetectedWatch>? watches,
    Set<String>? brandsByApp,
    bool? watchApp,
    bool? noPermission,
    DetectedWatch? waitingFor,
    bool clearWaiting = false,
  }) => WatchDiscovery(
    searching: searching ?? this.searching,
    done: done ?? this.done,
    watches: watches ?? this.watches,
    brandsByApp: brandsByApp ?? this.brandsByApp,
    watchApp: watchApp ?? this.watchApp,
    noPermission: noPermission ?? this.noPermission,
    waitingFor: clearWaiting ? null : waitingFor ?? this.waitingFor,
  );
}

/// Ключ: о каких часах уже предлагали подключить пульс при запуске.
const _suggestedKey = 'watch_suggested';

class WatchDiscoveryNotifier extends Notifier<WatchDiscovery> {
  ProviderSubscription<HeartRateState>? _waiting;

  @override
  WatchDiscovery build() {
    ref.onDispose(() => _waiting?.close());
    return const WatchDiscovery();
  }

  /// Найти часы: узлы Wear OS, сопряжённые устройства, приложения-компаньоны.
  /// [ask] — спросить разрешение (кнопка в мастере); без него — тихая проверка.
  Future<WatchDiscovery> search({bool ask = true}) async {
    if (!Platform.isAndroid) return state;
    state = state.copyWith(searching: true);
    var permission = await Permission.bluetoothConnect.status;
    if (!permission.isGranted && ask) {
      permission = await Permission.bluetoothConnect.request();
    }
    final granted = permission.isGranted;
    try {
      final nodes = await _list('wearNodes');
      final bonded = granted ? await _list('bonded') : const <Map>[];
      final installed =
          await _devices.invokeListMethod<String>('installed', {
            'packages': companionApps.keys.toList(),
          }) ??
          const [];
      final found = detectWatches(
        wearNodes: [
          for (final n in nodes)
            (id: '${n['id']}', name: '${n['name'] ?? 'Часы'}'),
        ],
        bonded: [
          for (final d in bonded)
            (name: '${d['name'] ?? ''}', address: '${d['address'] ?? ''}'),
        ],
        installedCompanions: installed,
      );
      // Стоит ли IronRise на часах: спросить версию и подождать ответа.
      var watchApp = ref.read(watchVersionProvider) != null;
      if (nodes.isNotEmpty && !watchApp) {
        await ref.read(heartRateProvider.notifier).askWatchVersion();
        for (var i = 0; i < 15 && ref.read(watchVersionProvider) == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
        watchApp = ref.read(watchVersionProvider) != null;
      }
      state = state.copyWith(
        searching: false,
        done: true,
        watches: found.watches,
        brandsByApp: found.brandsByApp,
        watchApp: watchApp,
        noPermission: !granted,
      );
    } on PlatformException {
      state = state.copyWith(searching: false, done: true);
    }
    return state;
  }

  Future<List<Map>> _list(String method) async =>
      await _devices.invokeListMethod<Map>(method) ?? const [];

  /// Открыть страницу IronRise в магазине на часах. false — не вышло.
  Future<bool> installOnWatch(DetectedWatch watch) async {
    try {
      return await _devices.invokeMethod<bool>('installOnWatch', {
            'node': watch.wearNode,
          }) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  /// Пользователь включил трансляцию: ищем датчик пульса и сами подключаемся
  /// к первому, чьё имя похоже на эти часы.
  Future<void> waitForBroadcast(DetectedWatch watch) async {
    final pulse = ref.read(heartRateProvider.notifier);
    state = state.copyWith(waitingFor: watch);
    _waiting?.close();
    _waiting = ref.listen(heartRateProvider, (_, hr) {
      if (hr.isConnected) {
        _stopWaiting();
        return;
      }
      for (final d in hr.found) {
        final same =
            d.name.toLowerCase() == watch.name.toLowerCase() ||
            guideIdForName(d.name) == watch.guideId;
        if (same) {
          pulse.connect(d);
          _stopWaiting();
          return;
        }
      }
      if (hr.status == HeartRateStatus.idle ||
          hr.status == HeartRateStatus.failed) {
        _stopWaiting();
      }
    });
    await pulse.startScan();
  }

  void _stopWaiting() {
    _waiting?.close();
    _waiting = null;
    state = state.copyWith(clearWaiting: true);
  }

  /// При запуске: без вопросов о разрешениях, раз на каждое устройство.
  /// Возвращает часы, о которых стоит напомнить, или null.
  Future<DetectedWatch?> newWatchToSuggest() async {
    if (!Platform.isAndroid) return null;
    final hr = ref.read(heartRateProvider);
    if (hr.isConnected) return null;
    final result = await search(ask: false);
    final prefs = ref.read(prefsProvider);
    final seen = prefs.getStringList(_suggestedKey) ?? const [];
    final candidates = result.watches.where(
      (w) => !seen.contains(w.name) && !(w.isWearOs && result.watchApp),
    );
    final watch = candidates.firstOrNull;
    if (watch != null) {
      await prefs.setStringList(_suggestedKey, [...seen, watch.name]);
    }
    return watch;
  }
}

final watchDiscoveryProvider =
    NotifierProvider<WatchDiscoveryNotifier, WatchDiscovery>(
      WatchDiscoveryNotifier.new,
    );
