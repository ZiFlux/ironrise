import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Адрес API. По умолчанию — компьютер разработчика, каким его видит эмулятор Android.
/// Для телефона по Wi-Fi: flutter run --dart-define=API_URL=http://192.168.1.10:3000
const apiBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://10.0.2.2:3000',
);

class ApiException implements Exception {
  const ApiException(this.status, this.message);

  /// 0 — сервер недоступен (нет сети, сервер выключен).
  final int status;
  final String message;

  bool get isNetwork => status == 0;

  /// Запрос отклонён по существу (400, 409, 422): повторять бессмысленно.
  bool get isRejected => status >= 400 && status < 500 && status != 401;

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
  ApiClient(this.tokens, {http.Client? client})
    : _http = client ?? http.Client();

  final TokenStore tokens;
  final http.Client _http;

  static const _timeout = Duration(seconds: 15);

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) => _send('POST', path, body: body, auth: auth);

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) =>
      _send('PUT', path, body: body);

  Future<Map<String, dynamic>> get(String path) => _send('GET', path);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
    bool retried = false,
  }) async {
    if (auth && tokens.access == null) await _refresh();
    final http.Response res;
    try {
      final request = http.Request(method, Uri.parse('$apiBaseUrl$path'))
        ..headers['content-type'] = 'application/json'
        ..headers.addAll({
          if (auth && tokens.access != null)
            'authorization': 'Bearer ${tokens.access}',
        });
      if (body != null) request.body = jsonEncode(body);
      res = await http.Response.fromStream(
        await _http.send(request).timeout(_timeout),
      );
    } on SocketException {
      throw const ApiException(0, 'Сервер недоступен');
    } on http.ClientException {
      throw const ApiException(0, 'Сервер недоступен');
    } on TimeoutException {
      throw const ApiException(0, 'Сервер не отвечает');
    }

    if (res.statusCode == 401 && auth && !retried) {
      await _refresh();
      return _send(method, path, body: body, auth: auth, retried: true);
    }
    final decoded = res.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 400) {
      final message = decoded is Map
          ? '${decoded['message'] ?? 'Ошибка ${res.statusCode}'}'
          : 'Ошибка ${res.statusCode}';
      throw ApiException(res.statusCode, message);
    }
    return decoded as Map<String, dynamic>;
  }

  /// Обменять refresh-токен на новую пару. Нет токена или он отозван — 401.
  Future<void> _refresh() async {
    final refresh = await tokens.readRefresh();
    if (refresh == null) throw const ApiException(401, 'Нужно войти в аккаунт');
    try {
      await tokens.save(
        await _send(
          'POST',
          '/v1/auth/refresh',
          body: {'refreshToken': refresh},
          auth: false,
        ),
      );
    } on ApiException catch (e) {
      if (e.status == 401) await tokens.clear();
      rethrow;
    }
  }
}
