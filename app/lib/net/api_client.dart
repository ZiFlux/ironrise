import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../env.dart';
import 'app_log.dart';

/// Адрес API по умолчанию.
/// dev: сервер разработки на компьютере; телефон видит его как 127.0.0.1 через
/// `adb reverse tcp:3000 tcp:3000` (docs/DEV.md), эмулятор — так же.
/// beta: постоянный сервер беты на VPS (docs/DEPLOY.md).
/// Переопределить при сборке: --dart-define=API_URL=https://...
/// В приложении адрес можно сменить в «Профиль → Аккаунт».
const betaServerUrl = 'https://api.ironrise.ru';

const apiBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: appEnv == AppEnv.beta ? betaServerUrl : 'http://127.0.0.1:3000',
);

class ApiException implements Exception {
  const ApiException(this.status, this.message);

  /// 0 — сервер недоступен (нет сети, сервер выключен).
  final int status;
  final String message;

  bool get isNetwork => status == 0;

  /// Аккаунт заблокирован администратором; причина — в [banReason].
  bool get isBanned => status == 403 && message.startsWith('Account banned');

  String get banReason => message.replaceFirst('Account banned:', '').trim();

  /// Запрос отклонён по существу (400, 409, 422): повторять бессмысленно.
  /// Бан — не отказ по существу: тренировку из очереди не выбрасываем.
  bool get isRejected =>
      status >= 400 && status < 500 && status != 401 && !isBanned;

  @override
  String toString() => 'ApiException($status, $message)';
}

/// Refresh-токен — в защищённом хранилище Android, access-токен — только в памяти.
class TokenStore {
  TokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _refreshKey = 'refresh_token';

  String? access;

  /// Идущий обмен refresh-токена — общий для всех клиентов (хранилище одно).
  static Future<void>? _refreshing;

  Future<String?> readRefresh() => _storage.read(key: _refreshKey);

  Future<void> save(Map<String, dynamic> tokens) async {
    access = tokens['accessToken'] as String;
    await _storage.write(
      key: _refreshKey,
      value: tokens['refreshToken'] as String,
    );
  }

  Future<void> clear() async {
    access = null;
    await _storage.delete(key: _refreshKey);
  }
}

class ApiClient {
  ApiClient(this.tokens, {required this.baseUrl, http.Client? client})
    : _http = client ?? http.Client();

  final TokenStore tokens;

  /// Адрес сервера без завершающего «/».
  final String baseUrl;
  final http.Client _http;

  static const _timeout = Duration(seconds: 15);

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async =>
      (await _send('POST', path, body: body, auth: auth))
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body,
  ) async => (await _send('PUT', path, body: body)) as Map<String, dynamic>;

  Future<Map<String, dynamic>> get(String path) async =>
      (await _send('GET', path)) as Map<String, dynamic>;

  Future<List<dynamic>> getList(String path) async =>
      (await _send('GET', path)) as List<dynamic>;

  Future<void> delete(String path) => _send('DELETE', path);

  /// GET с проверкой «изменилось ли»: [etag] — метка прошлого ответа. null —
  /// не изменилось (сервер ответил 304 и ничего не прислал).
  Future<({Object? body, String? etag})?> getIfChanged(
    String path,
    String? etag,
  ) async {
    String? fresh;
    final body = await _send(
      'GET',
      path,
      headers: {'if-none-match': ?etag},
      onHeaders: (h) => fresh = h['etag'],
    );
    if (identical(body, _notModified)) return null;
    return (body: body, etag: fresh);
  }

  static const _notModified = Object();

  /// Разобранный JSON ответа: объект, массив или пустой объект для 204.
  Future<Object?> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
    bool retried = false,
    Map<String, String> headers = const {},
    void Function(Map<String, String> headers)? onHeaders,
  }) async {
    if (auth && tokens.access == null) await _refresh();
    final http.Response res;
    try {
      final request = http.Request(method, Uri.parse('$baseUrl$path'))
        ..headers['content-type'] = 'application/json'
        ..headers.addAll(headers)
        ..headers.addAll({
          if (auth && tokens.access != null)
            'authorization': 'Bearer ${tokens.access}',
        });
      if (body != null) request.body = jsonEncode(body);
      res = await http.Response.fromStream(
        await _http.send(request).timeout(_timeout),
      );
    } on SocketException catch (e) {
      _logFailure(method, path, 'нет связи: ${e.message}');
      throw const ApiException(0, 'Сервер недоступен');
    } on http.ClientException catch (e) {
      _logFailure(method, path, 'нет связи: ${e.message}');
      throw const ApiException(0, 'Сервер недоступен');
    } on TimeoutException {
      _logFailure(method, path, 'таймаут');
      throw const ApiException(0, 'Сервер не отвечает');
    }

    if (res.statusCode == 401 && auth && !retried) {
      await _refresh();
      return _send(
        method,
        path,
        body: body,
        auth: auth,
        retried: true,
        headers: headers,
        onHeaders: onHeaders,
      );
    }
    if (res.statusCode == 304) return _notModified;
    onHeaders?.call(res.headers);
    final decoded = res.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 400) {
      final message = decoded is Map
          ? '${decoded['message'] ?? 'Ошибка ${res.statusCode}'}'
          : 'Ошибка ${res.statusCode}';
      if (res.statusCode != 401) {
        _logFailure(method, path, '${res.statusCode} $message');
      }
      throw ApiException(res.statusCode, message);
    }
    // Что-то изменилось на сервере (покупка, награда, дуэль) — пусть приложение
    // вскоре сверится с ним и отправит журнал. Журнал и вход сами не считаются.
    if (method != 'GET' &&
        !path.startsWith('/v1/logs') &&
        !path.startsWith('/v1/auth')) {
      onServerWrite?.call(path);
    }
    return decoded;
  }

  /// Вызывается после каждого успешного изменения на сервере (см. AccountNotifier).
  static void Function(String path)? onServerWrite;

  /// В журнал тестера. Запросы самого журнала не пишем: без сети он забился бы
  /// записями о том, что не смог отправиться.
  void _logFailure(String method, String path, String what) {
    if (path.startsWith('/v1/logs')) return;
    AppLog.warn('API $method $path: $what');
  }

  /// Обменять refresh-токен на новую пару. Нет токена или он отозван — 401.
  ///
  /// Обмен один на всё приложение: после входа вкладки шлют запросы разом,
  /// и параллельные обмены одним токеном (сервер его меняет при каждом обмене)
  /// получали 401 и стирали вход.
  Future<void> _refresh() => TokenStore._refreshing ??= _doRefresh()
      .whenComplete(() => TokenStore._refreshing = null);

  Future<void> _doRefresh() async {
    final refresh = await tokens.readRefresh();
    if (refresh == null) throw const ApiException(401, 'Нужно войти в аккаунт');
    try {
      await tokens.save(
        await post('/v1/auth/refresh', {'refreshToken': refresh}, auth: false),
      );
    } on ApiException catch (e) {
      // Стираем вход, только если отклонён именно сохранённый сейчас токен:
      // пока шёл запрос, мог успеть войти пользователь или пройти другой обмен.
      // 403 — аккаунт заблокирован: сессию тоже стираем.
      if ((e.status == 401 || e.isBanned) &&
          await tokens.readRefresh() == refresh) {
        await tokens.clear();
      }
      rethrow;
    }
  }
}

/// Привести введённый адрес к виду https://host[:port] без «/» в конце.
String normalizeServerUrl(String input) {
  var url = input.trim();
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  final hasScheme = url.startsWith('http://') || url.startsWith('https://');
  return hasScheme ? url : 'https://$url';
}
