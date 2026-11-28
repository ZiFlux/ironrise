import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../net/api_client.dart';
import 'account_state.dart';
import 'aura_state.dart';
import 'cardio_norms.dart';
import 'season_state.dart';
import 'server_game.dart';

/// Есть ли связь с сервером. Пропала (нет сети, VPN, сервер недоступен) —
/// вкладки показывают сохранённое и не ждут таймаутов, а телефон раз в 20 с
/// коротко проверяет сервер. Вернулась — вкладки один раз сверяются заново.
class ConnectionNotifier extends Notifier<bool> {
  static const probeEvery = Duration(seconds: 20);

  Timer? _probe;

  /// Когда вкладки последний раз обновлялись из-за вернувшейся связи.
  DateTime? _refreshedAt;

  /// Связь «мигает» (слабый VPN, плохая сеть) — вкладки обновляются не чаще
  /// раза в минуту, иначе они перезагружались бы по кругу.
  static const refreshEvery = Duration(minutes: 1);

  @override
  bool build() {
    ApiClient.onReachable = _report;
    ref.onDispose(() {
      _probe?.cancel();
      if (ApiClient.onReachable == _report) ApiClient.onReachable = null;
    });
    return true;
  }

  void _report(bool reachable) {
    if (reachable == state) return;
    // Уведомление — после текущего кадра: отчёт приходит из запросов, в том
    // числе запущенных во время сборки провайдеров.
    scheduleMicrotask(() {
      if (reachable == state) return;
      state = reachable;
      if (reachable) {
        _probe?.cancel();
        _probe = null;
        _refreshTabs();
      } else {
        _probe ??= Timer.periodic(probeEvery, (_) => retry());
      }
    });
  }

  /// Проверить связь сейчас (кнопка «Повторить», таймер).
  Future<bool> retry() => ref.read(apiProvider).ping();

  void _refreshTabs() {
    final now = DateTime.now();
    final last = _refreshedAt;
    if (last != null && now.difference(last) < refreshEvery) return;
    _refreshedAt = now;
    for (final p in [
      serverBotsProvider,
      serverLeagueProvider,
      serverFriendsProvider,
      serverFriendsLeagueProvider,
      serverAttacksProvider,
      notificationsProvider,
      seasonProvider,
      cardioNormsProvider,
    ]) {
      ref.invalidate(p);
    }
    ref.invalidate(auraProvider);
  }
}

final connectionProvider = NotifierProvider<ConnectionNotifier, bool>(
  ConnectionNotifier.new,
);
