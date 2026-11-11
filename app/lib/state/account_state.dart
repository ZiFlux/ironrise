import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/anti_fraud.dart';
import '../game/cardio.dart';
import '../game/workout.dart';
import '../net/api_client.dart';
import '../net/push.dart';
import 'providers.dart';
import 'server_game.dart';

const _outboxKey = 'outbox_v1';
const _emailKey = 'account_email';
const _maxOutbox = 300;

/// Тренировка, ожидающая отправки на сервер. clientId делает отправку идемпотентной.
class OutboxJob {
  const OutboxJob({required this.path, required this.body});

  final String path;
  final Map<String, dynamic> body;

  Map<String, dynamic> toJson() => {'path': path, 'body': body};

  factory OutboxJob.fromJson(Map<String, dynamic> j) =>
      OutboxJob(path: j['path'], body: Map<String, dynamic>.from(j['body']));
}

class AccountState {
  const AccountState({
    this.email,
    this.pending = 0,
    this.syncing = false,
    this.lastSyncedAt,
    this.error,
    this.rejected = 0,
  });

  /// null — аккаунта нет, приложение работает офлайн.
  final String? email;
  final int pending;
  final bool syncing;
  final DateTime? lastSyncedAt;
  final String? error;

  /// Сколько тренировок сервер отклонил (данные не прошли проверку).
  final int rejected;

  bool get signedIn => email != null;

  AccountState copyWith({
    String? email,
    bool clearEmail = false,
    int? pending,
    bool? syncing,
    DateTime? lastSyncedAt,
    String? error,
    bool clearError = false,
    int? rejected,
  }) => AccountState(
    email: clearEmail ? null : email ?? this.email,
    pending: pending ?? this.pending,
    syncing: syncing ?? this.syncing,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    error: clearError ? null : error ?? this.error,
    rejected: rejected ?? this.rejected,
  );
}

const _serverUrlKey = 'server_url';

/// Адрес сервера: введённый в приложении или заданный при сборке.
class ServerUrlNotifier extends Notifier<String> {
  @override
  String build() =>
      ref.read(prefsProvider).getString(_serverUrlKey) ?? apiBaseUrl;

  Future<void> set(String input) async {
    final url = normalizeServerUrl(input);
    await ref.read(prefsProvider).setString(_serverUrlKey, url);
    state = url;
  }
}

final serverUrlProvider = NotifierProvider<ServerUrlNotifier, String>(
  ServerUrlNotifier.new,
);

/// Один токен-стор на всё приложение: смена адреса не теряет вход.
final _tokenStore = TokenStore();

final apiProvider = Provider<ApiClient>(
  (ref) => ApiClient(_tokenStore, baseUrl: ref.watch(serverUrlProvider)),
);

String newClientId() {
  final rnd = Random.secure();
  return List.generate(
    16,
    (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

List<Map<String, dynamic>> _pulseJson(List<PulseSample> pulse) => [
  for (final s in pulse) {'at': s.at.toUtc().toIso8601String(), 'bpm': s.bpm},
];

/// IANA-зона вида Etc/GMT-3 по текущему смещению (знак у Etc/GMT обратный).
/// Получасовые пояса пока считаются как UTC — позже через плагин часовых поясов.
String deviceTimeZone() {
  final offset = DateTime.now().timeZoneOffset;
  if (offset.inMinutes % 60 != 0) return 'UTC';
  final h = offset.inHours;
  if (h == 0) return 'UTC';
  return h > 0 ? 'Etc/GMT-$h' : 'Etc/GMT+${-h}';
}

/// Аккаунт и синхронизация. Тренировки всегда сначала считаются на телефоне
/// (итог виден сразу, даже без сети) и встают в очередь; сервер пересчитывает
/// их и становится источником правды для опыта и серии.
class AccountNotifier extends Notifier<AccountState> {
  ApiClient get _api => ref.read(apiProvider);

  @override
  AccountState build() {
    final prefs = ref.read(prefsProvider);
    final s = AccountState(
      email: prefs.getString(_emailKey),
      pending: _readOutbox().length,
    );
    if (s.signedIn && s.pending > 0) Future.microtask(sync);
    if (s.signedIn) Future.microtask(() => setupPush(ref, _api));
    return s;
  }

  List<OutboxJob> _readOutbox() {
    final raw = ref.read(prefsProvider).getString(_outboxKey);
    if (raw == null) return [];
    try {
      return [for (final j in jsonDecode(raw) as List) OutboxJob.fromJson(j)];
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeOutbox(List<OutboxJob> jobs) async {
    await ref
        .read(prefsProvider)
        .setString(_outboxKey, jsonEncode([for (final j in jobs) j.toJson()]));
    state = state.copyWith(pending: jobs.length);
  }

  Future<void> enqueueStrength(
    WorkoutSession s,
    DateTime finishedAt,
    List<PulseSample> pulse,
  ) => _enqueue(
    OutboxJob(
      path: '/v1/workouts/strength',
      body: {
        'clientId': newClientId(),
        'startedAt': s.startedAt.toUtc().toIso8601String(),
        'finishedAt': finishedAt.toUtc().toIso8601String(),
        'entries': [
          for (final e in s.entries)
            if (e.sets.isNotEmpty)
              {
                'exerciseId': e.exercise.id,
                'sets': [for (final set in e.sets) set.toJson()],
              },
        ],
        'pulse': _pulseJson(pulse),
      },
    ),
  );

  Future<void> enqueueCardio(
    CardioSession s,
    DateTime finishedAt,
    List<PulseSample> pulse,
  ) => _enqueue(
    OutboxJob(
      path: '/v1/workouts/cardio',
      body: {
        'clientId': newClientId(),
        'startedAt': s.startedAt.toUtc().toIso8601String(),
        'finishedAt': finishedAt.toUtc().toIso8601String(),
        'activity': s.activity.name,
        'pulse': _pulseJson(pulse),
      },
    ),
  );

  Future<void> _enqueue(OutboxJob job) async {
    final jobs = _readOutbox()..add(job);
    // Без аккаунта очередь не растёт бесконечно: старейшие уходят первыми.
    await _writeOutbox(
      jobs.length > _maxOutbox ? jobs.sublist(jobs.length - _maxOutbox) : jobs,
    );
    if (state.signedIn) await sync();
  }

  Future<void> register(String email, String password) async {
    final hero = ref.read(heroProvider);
    if (hero == null) return;
    final body = {
      'email': email,
      'password': password,
      'adultConfirmed': true,
      'nickname': hero.nickname,
      'goal': hero.goal.name,
      'trainingFormat': hero.format.name,
      'scheduleDays': hero.trainingDays,
      'appearance': hero.look.toJson(),
      'timezone': deviceTimeZone(),
      if (hero.body.age != null) 'age': hero.body.age,
      if (hero.body.restingHeartRate != null)
        'restingHr': hero.body.restingHeartRate,
    };
    await _signedIn(
      email,
      await _api.post('/v1/auth/register', body, auth: false),
    );
  }

  Future<void> login(String email, String password) async {
    await _signedIn(
      email,
      await _api.post('/v1/auth/login', {
        'email': email,
        'password': password,
      }, auth: false),
    );
  }

  Future<void> _signedIn(String email, Map<String, dynamic> tokens) async {
    await _api.tokens.save(tokens);
    await ref.read(prefsProvider).setString(_emailKey, email.toLowerCase());
    state = state.copyWith(email: email.toLowerCase(), clearError: true);
    await sync();
    await setupPush(ref, _api);
  }

  Future<void> logout() async {
    await unregisterPush(_api);
    final refresh = await _api.tokens.readRefresh();
    if (refresh != null) {
      try {
        await _api.post('/v1/auth/logout', {
          'refreshToken': refresh,
        }, auth: false);
      } on ApiException {
        // Сервер недоступен — токен всё равно удаляем с телефона.
      }
    }
    await _api.tokens.clear();
    await ref.read(prefsProvider).remove(_emailKey);
    state = state.copyWith(clearEmail: true, clearError: true);
  }

  /// Отправить очередь по порядку, затем взять состояние героя с сервера.
  /// Нет сети — очередь ждёт; данные отклонены — тренировка снимается с очереди.
  Future<void> sync() async {
    if (!state.signedIn || state.syncing) return;
    state = state.copyWith(syncing: true, clearError: true);
    var rejected = 0;
    try {
      var jobs = _readOutbox();
      while (jobs.isNotEmpty) {
        try {
          await _api.post(jobs.first.path, jobs.first.body);
        } on ApiException catch (e) {
          if (!e.isRejected) rethrow;
          rejected++;
        }
        jobs = jobs.sublist(1);
        await _writeOutbox(jobs);
      }
      await ref
          .read(heroProvider.notifier)
          .applyServer(await _api.get('/v1/me'));
      // Уровни изменились — боты дня и лига на сервере тоже.
      ref.invalidate(serverBotsProvider);
      ref.invalidate(serverLeagueProvider);
      state = state.copyWith(
        lastSyncedAt: DateTime.now(),
        rejected: state.rejected + rejected,
      );
    } on ApiException catch (e) {
      if (e.status == 401) {
        // Refresh-токен отозван или истёк: просим войти заново, очередь сохраняется.
        await ref.read(prefsProvider).remove(_emailKey);
        state = state.copyWith(
          clearEmail: true,
          error: 'Войдите в аккаунт заново',
        );
      } else {
        state = state.copyWith(
          error: e.message,
          rejected: state.rejected + rejected,
        );
      }
    } finally {
      state = state.copyWith(syncing: false);
    }
  }
}

final accountProvider = NotifierProvider<AccountNotifier, AccountState>(
  AccountNotifier.new,
);
