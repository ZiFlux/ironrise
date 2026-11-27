import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../net/api_client.dart';
import 'account_state.dart';
import 'connection.dart';
import 'providers.dart';

/// Последние ответы сервера для вкладок (дуэли, лига, друзья, сезон…): вкладка
/// открывается сразу с ними, а сервер лишь подтверждает «не изменилось» (304)
/// или присылает новое. Без сети видно последнее сохранённое.
///
/// Лежит на телефоне одним ключом и только для одного аккаунта: вошли в
/// другой — старое не показывается и стирается при первой записи.
class ApiCache {
  ApiCache(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'api_cache_v1';

  /// Не больше стольких ответов: остальные (самые старые) вытесняются.
  static const maxEntries = 24;

  Map<String, dynamic>? _all;

  Map<String, dynamic> _load() {
    if (_all != null) return _all!;
    try {
      final raw = _prefs.getString(_key);
      _all = raw == null ? {} : jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      _all = {};
    }
    return _all!;
  }

  ({Object? body, String? etag, DateTime at})? read(String owner, String path) {
    final all = _load();
    if (all['owner'] != owner) return null;
    final e = (all['items'] as Map?)?[path];
    if (e is! Map) return null;
    return (
      body: e['body'],
      etag: e['etag'] as String?,
      at: DateTime.tryParse(e['at'] as String? ?? '') ?? DateTime(2000),
    );
  }

  Future<void> write(
    String owner,
    String path,
    Object? body,
    String? etag,
  ) async {
    final all = _load();
    final items = all['owner'] == owner
        ? Map<String, dynamic>.from(all['items'] as Map? ?? const {})
        : <String, dynamic>{};
    items.remove(path);
    items[path] = {
      'body': body,
      'etag': ?etag,
      'at': DateTime.now().toIso8601String(),
    };
    while (items.length > maxEntries) {
      items.remove(items.keys.first);
    }
    _all = {'owner': owner, 'items': items};
    await _prefs.setString(_key, jsonEncode(_all));
  }

  Future<void> clear() async {
    _all = {};
    await _prefs.remove(_key);
  }
}

final apiCacheProvider = Provider<ApiCache>(
  (ref) => ApiCache(ref.read(prefsProvider)),
);

/// Данные вкладки: сразу из кэша телефона, затем проверка у сервера. Новое —
/// ещё одно значение; то же самое (304 или тот же ответ) — экран не
/// перерисовывается. Без сети остаётся сохранённое; ошибка — только если
/// показать совсем нечего.
Stream<T> cachedGet<T>(Ref ref, String path, T Function(Object? json) parse) {
  // Вошли в другой аккаунт или вышли — данные загрузятся заново. Всё из ref —
  // сразу, в сборке провайдера, а не внутри потока.
  final owner = ref.watch(accountProvider.select((a) => a.email)) ?? '';
  // Связи нет — сохранённое без запроса: не ждём таймаута на каждой вкладке.
  // Связь вернётся — connection.dart сам обновит вкладки.
  final offline = !ref.read(connectionProvider);
  return cachedStream(
    ref.read(apiCacheProvider),
    ref.read(apiProvider),
    owner,
    path,
    parse,
    offline: offline,
  );
}

/// Сам поток [cachedGet] — отдельно, чтобы проверять без провайдеров.
@visibleForTesting
Stream<T> cachedStream<T>(
  ApiCache cache,
  ApiClient api,
  String owner,
  String path,
  T Function(Object? json) parse, {
  bool offline = false,
}) async* {
  final hit = cache.read(owner, path);
  var shown = false;
  if (hit != null) {
    try {
      final cached = parse(hit.body);
      shown = true;
      yield cached;
    } catch (_) {
      // Старый формат ответа — просто ждём свежий.
    }
  }
  // Без связи и с сохранённым — на этом всё; без сохранённого — пробуем
  // (иначе «Повторить» никогда не дошёл бы до сервера).
  if (offline && shown) return;
  final ({Object? body, String? etag})? fresh;
  try {
    fresh = await api.getIfChanged(path, shown ? hit?.etag : null);
  } on ApiException {
    if (!shown) rethrow;
    return;
  }
  if (fresh == null) return;
  await cache.write(owner, path, fresh.body, fresh.etag);
  if (shown && jsonEncode(fresh.body) == jsonEncode(hit!.body)) return;
  yield parse(fresh.body);
}
