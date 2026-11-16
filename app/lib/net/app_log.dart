import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../env.dart';
import 'api_client.dart';

/// Журнал приложения для отладки у тестеров (docs/BETA.md, «Логи тестеров»).
///
/// Пишет падения Flutter, неперехваченные ошибки, ошибки запросов к серверу и
/// диагностику (debugPrint). Последние [_keep] записей лежат на телефоне и уходят
/// на сервер при запуске, возврате и сворачивании, раз в 2 минуты, после каждой
/// синхронизации и через 5 секунд после ошибки; без сети — ждут.
/// Токены и пароли вычищаются до записи. Отправку можно выключить в настройках.
class AppLog {
  AppLog._();

  static const _storeKey = 'app_log_v1';
  static const _installKey = 'install_id';
  static const _enabledKey = 'send_logs';
  static const _keep = 300;
  static const _batch = 100;

  static SharedPreferences? _prefs;
  static final List<Map<String, dynamic>> _entries = [];
  static String _installId = '';
  static String _appVersion = '?';
  static bool _sending = false;
  static Timer? _timer;
  static AppLifecycleListener? _lifecycle;

  /// Отправлять ли логи на сервер (по умолчанию — да).
  static bool get enabled => _prefs?.getBool(_enabledKey) ?? true;

  static Future<void> setEnabled(bool value) async {
    await _prefs?.setBool(_enabledKey, value);
    if (!value) {
      _entries.clear();
      await _persist();
    }
  }

  /// Вызывается в main() до runApp: перехват ошибок и загрузка сохранённого.
  static Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
    _installId = prefs.getString(_installKey) ?? _newInstallId();
    await prefs.setString(_installKey, _installId);
    try {
      final saved = prefs.getString(_storeKey);
      if (saved != null) {
        _entries.addAll(
          (jsonDecode(saved) as List).cast<Map<String, dynamic>>(),
        );
      }
    } catch (_) {
      // Повреждённый журнал не должен мешать запуску.
    }
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {}

    final previousFlutter = FlutterError.onError;
    FlutterError.onError = (details) {
      error(details.exceptionAsString(), details.stack);
      previousFlutter?.call(details);
    };
    final previousPlatform = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (e, stack) {
      error('Неперехваченная ошибка: $e', stack);
      return previousPlatform?.call(e, stack) ?? false;
    };
    final previousPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) info(message);
      previousPrint(message, wrapWidth: wrapWidth);
    };
  }

  static void error(Object message, [StackTrace? stack]) =>
      _add('error', '$message', stack);
  static void warn(Object message) => _add('warn', '$message');
  static void info(Object message) => _add('info', '$message');

  static void _add(String level, String message, [StackTrace? stack]) {
    if (_prefs == null || !enabled) return;
    _entries.add({
      'at': DateTime.now().toUtc().toIso8601String(),
      'level': level,
      'message': _clip(scrub(message), 4000),
      if (stack != null) 'stack': _clip(scrub(stack.toString()), 8000),
    });
    if (_entries.length > _keep) {
      _entries.removeRange(0, _entries.length - _keep);
    }
    unawaited(_persist());
    // Ошибку отправляем почти сразу: приложение могут закрыть до таймера.
    if (level == 'error') uploadSoon();
  }

  static ApiClient Function()? _api;
  static Timer? _soon;

  /// Запустить отправку: сейчас, раз в 2 минуты, при возврате в приложение
  /// и при сворачивании. [api] — текущий клиент (адрес сервера и вход могут меняться).
  static void startUploading(ApiClient Function() api) {
    // Не инициализирован (тесты) или уже запущен — ничего не делаем.
    if (_prefs == null || _timer != null) return;
    _api = api;
    _timer = Timer.periodic(const Duration(minutes: 2), (_) => upload(api()));
    _lifecycle?.dispose();
    _lifecycle = AppLifecycleListener(
      onResume: () => upload(api()),
      // Свернули — возможно, навсегда: отправляем, пока процесс жив.
      onHide: () => upload(api()),
    );
    unawaited(upload(api()));
  }

  /// Отправить через несколько секунд: события подряд уходят одной пачкой.
  static void uploadSoon() {
    final api = _api;
    // Уже ждём — не откладываем: ошибка в каждом кадре иначе не дала бы отправить.
    if (api == null || (_soon?.isActive ?? false)) return;
    _soon = Timer(const Duration(seconds: 5), () => upload(api()));
  }

  /// Отправить накопленное пачками. Ошибка сети — оставить до следующего раза.
  static Future<void> upload(ApiClient api) async {
    if (_sending || _entries.isEmpty || !enabled) return;
    _sending = true;
    try {
      while (_entries.isNotEmpty) {
        final batch = _entries.take(_batch).toList();
        await api.post('/v1/logs', {
          'installId': _installId,
          'appVersion': _appVersion,
          'os': _clip(
            '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
            120,
          ),
          'env': appEnv.name,
          'entries': batch,
        }, auth: await api.tokens.readRefresh() != null);
        _entries.removeRange(0, batch.length);
        await _persist();
      }
    } catch (_) {
      // Нет сети или сервер не ответил — отправим позже. Сам этот сбой не логируем,
      // иначе без сети журнал заполнится записями о том, что он не отправился.
    } finally {
      _sending = false;
    }
  }

  static Future<void> _persist() async =>
      _prefs?.setString(_storeKey, jsonEncode(_entries));

  static String _newInstallId() {
    final r = Random.secure();
    return List.generate(
      16,
      (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  static String _clip(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max - 1)}…';

  static final _secrets = [
    RegExp(r'Bearer\s+[A-Za-z0-9._\-]+'),
    RegExp(r'("?(?:access|refresh)Token"?\s*[:=]\s*"?)[A-Za-z0-9._\-]+'),
    RegExp(r'("?password"?\s*[:=]\s*"?)[^",}\s]+', caseSensitive: false),
  ];

  /// Убрать токены и пароли из текста перед записью в журнал.
  @visibleForTesting
  static String scrub(String text) {
    var s = text.replaceAll(_secrets[0], 'Bearer ***');
    for (final re in _secrets.skip(1)) {
      s = s.replaceAllMapped(re, (m) => '${m.group(1)}***');
    }
    return s;
  }
}
