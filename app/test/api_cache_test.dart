import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ironrise/net/api_client.dart';
import 'package:ironrise/state/api_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Кэш ответов для вкладок: сразу сохранённое, потом сверка с сервером (ETag).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ApiClient api(http.Response Function(http.Request req) handle) {
    final tokens = TokenStore()..access = 'a';
    return ApiClient(
      tokens,
      baseUrl: 'https://x',
      client: MockClient((req) async => handle(req)),
    );
  }

  int parse(Object? j) => (j as Map)['n'] as int;

  test('первый раз — с сервера, ответ и метка сохраняются', () async {
    final cache = ApiCache(prefs);
    final values = await cachedStream(
      cache,
      api((_) => http.Response('{"n":1}', 200, headers: {'etag': 'W/"1"'})),
      'me@x',
      '/v1/league',
      parse,
    ).toList();
    expect(values, [1]);
    final hit = ApiCache(prefs).read('me@x', '/v1/league');
    expect(hit?.etag, 'W/"1"');
    expect(hit?.body, {'n': 1});
  });

  test(
    'не изменилось (304) — одно значение из кэша, без перерисовки',
    () async {
      final cache = ApiCache(prefs);
      await cache.write('me@x', '/v1/league', {'n': 1}, 'W/"1"');
      String? sent;
      final values = await cachedStream(
        cache,
        api((req) {
          sent = req.headers['if-none-match'];
          return http.Response('', 304);
        }),
        'me@x',
        '/v1/league',
        parse,
      ).toList();
      expect(sent, 'W/"1"');
      expect(values, [1]);
    },
  );

  test('изменилось — сначала старое, потом новое', () async {
    final cache = ApiCache(prefs);
    await cache.write('me@x', '/v1/league', {'n': 1}, 'W/"1"');
    final values = await cachedStream(
      cache,
      api((_) => http.Response('{"n":2}', 200, headers: {'etag': 'W/"2"'})),
      'me@x',
      '/v1/league',
      parse,
    ).toList();
    expect(values, [1, 2]);
    expect(cache.read('me@x', '/v1/league')?.etag, 'W/"2"');
  });

  test(
    'тот же ответ без 304 (прокси сменил метку) — без второго значения',
    () async {
      final cache = ApiCache(prefs);
      await cache.write('me@x', '/v1/league', {'n': 1}, 'W/"1"');
      final values = await cachedStream(
        cache,
        api(
          (_) => http.Response('{"n":1}', 200, headers: {'etag': 'W/"1-gz"'}),
        ),
        'me@x',
        '/v1/league',
        parse,
      ).toList();
      expect(values, [1]);
    },
  );

  test('без сети — остаётся сохранённое, без ошибки', () async {
    final cache = ApiCache(prefs);
    await cache.write('me@x', '/v1/league', {'n': 1}, null);
    final values = await cachedStream(
      cache,
      api((_) => throw const SocketException('нет сети')),
      'me@x',
      '/v1/league',
      parse,
    ).toList();
    expect(values, [1]);
  });

  test('без сети и без сохранённого — ошибка, экран покажет «повторить»', () {
    expect(
      cachedStream(
        ApiCache(prefs),
        api((_) => throw const SocketException('нет сети')),
        'me@x',
        '/v1/league',
        parse,
      ).toList(),
      throwsA(isA<ApiException>()),
    );
  });

  test('другой аккаунт не видит чужое и затирает его при записи', () async {
    final cache = ApiCache(prefs);
    await cache.write('a@x', '/v1/friends', {'n': 1}, null);
    expect(cache.read('b@x', '/v1/friends'), isNull);
    await cache.write('b@x', '/v1/league', {'n': 2}, null);
    expect(cache.read('a@x', '/v1/friends'), isNull);
    expect(jsonDecode(prefs.getString('api_cache_v1')!)['owner'], 'b@x');
  });

  test('ответов не больше предела: старые вытесняются', () async {
    final cache = ApiCache(prefs);
    for (var i = 0; i < ApiCache.maxEntries + 3; i++) {
      await cache.write('me@x', '/p$i', {'n': i}, null);
    }
    expect(cache.read('me@x', '/p0'), isNull);
    expect(cache.read('me@x', '/p${ApiCache.maxEntries + 2}'), isNotNull);
  });

  test(
    'связи нет — сохранённое без запроса, без сохранённого — пробуем',
    () async {
      final cache = ApiCache(prefs);
      await cache.write('me@x', '/v1/league', {'n': 1}, null);
      var calls = 0;
      final client = api((_) {
        calls++;
        return http.Response('{"n":2}', 200);
      });
      final values = await cachedStream(
        cache,
        client,
        'me@x',
        '/v1/league',
        parse,
        offline: true,
      ).toList();
      expect(values, [1]);
      expect(calls, 0);
      // Сохранённого нет — «Повторить» должен дойти до сервера.
      final fresh = await cachedStream(
        cache,
        client,
        'me@x',
        '/v1/friends',
        parse,
        offline: true,
      ).toList();
      expect(fresh, [2]);
      expect(calls, 1);
    },
  );

  test('ответ сервера и обрыв — сообщают о связи', () async {
    final seen = <bool>[];
    ApiClient.onReachable = seen.add;
    addTearDown(() => ApiClient.onReachable = null);
    await api((_) => http.Response('{"n":1}', 200)).get('/v1/league');
    await expectLater(
      api((_) => throw const SocketException('нет сети')).get('/v1/league'),
      throwsA(isA<ApiException>()),
    );
    expect(seen, [true, false]);
  });
}
