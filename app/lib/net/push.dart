// getToken/onTokenRefresh/deleteToken устарели в firebase_messaging 17: новый
// register()/onRegistered отдаёт ID установки (FID), а сервер шлёт через FCM v1
// по токену регистрации. Переход — после проверки отправки на FID с живым проектом.
// ignore_for_file: deprecated_member_use

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../router.dart';
import '../state/server_game.dart';
import 'api_client.dart';

/// Параметры Firebase приходят при сборке: flutter run --dart-define-from-file=firebase.json
/// (значения — из google-services.json, см. docs/BETA.md). Нет параметров — пуши выключены.
const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
const _appId = String.fromEnvironment('FIREBASE_APP_ID');
const _senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

bool get pushConfigured =>
    _apiKey.isNotEmpty &&
    _appId.isNotEmpty &&
    _senderId.isNotEmpty &&
    _projectId.isNotEmpty;

/// Для всплывающих сообщений вне BuildContext (пуш пришёл, пока приложение открыто).
final messengerKey = GlobalKey<ScaffoldMessengerState>();

bool _ready = false;
bool _listening = false;

Future<bool> _ensureFirebase() async {
  if (_ready) return true;
  if (!pushConfigured) return false;
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: _apiKey,
        appId: _appId,
        messagingSenderId: _senderId,
        projectId: _projectId,
      ),
    );
    _ready = true;
  } catch (e) {
    debugPrint('Firebase не запустился, пуши выключены: $e');
  }
  return _ready;
}

String _pathFor(RemoteMessage m) => switch (m.data['screen']) {
  'friends' => '/duels/friends',
  'duels' => '/duels',
  _ => '/',
};

/// После входа: разрешение на уведомления, токен на сервер, обработчики.
/// Любая ошибка здесь не мешает работе приложения.
Future<void> setupPush(Ref ref, ApiClient api) async {
  if (!await _ensureFirebase()) return;
  try {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    Future<void> send(String token) =>
        api.post('/v1/me/devices', {'token': token, 'platform': 'android'});
    final token = await messaging.getToken();
    if (token != null) await send(token);

    if (_listening) return;
    _listening = true;
    messaging.onTokenRefresh.listen((t) => send(t).catchError((_) {}));
    FirebaseMessaging.onMessage.listen((m) {
      ref.invalidate(serverFriendsProvider);
      ref.invalidate(serverAttacksProvider);
      ref.invalidate(notificationsProvider);
      final title = m.notification?.title;
      if (title != null) {
        messengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(title),
            action: SnackBarAction(
              label: 'Открыть',
              onPressed: () => ref.read(routerProvider).go(_pathFor(m)),
            ),
          ),
        );
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen(
      (m) => ref.read(routerProvider).go(_pathFor(m)),
    );
    final initial = await messaging.getInitialMessage();
    if (initial != null) ref.read(routerProvider).go(_pathFor(initial));
  } catch (e) {
    debugPrint('Пуши не настроены: $e');
  }
}

/// При выходе: сервер больше не шлёт на этот телефон.
Future<void> unregisterPush(ApiClient api) async {
  if (!_ready) return;
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await api.post('/v1/me/devices/remove', {
        'token': token,
        'platform': 'android',
      });
    }
    await FirebaseMessaging.instance.deleteToken();
  } catch (_) {
    // Нет сети — токен на сервере удалится сам, когда FCM скажет, что он устарел.
  }
}
