import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/anti_fraud.dart';
import '../game/game_config.dart';
import '../game/cardio.dart';
import '../game/set_pulse.dart';
import '../game/workout.dart';
import '../legal/privacy_policy.dart';
import '../net/api_client.dart';
import '../net/app_log.dart';
import '../net/push.dart';
import 'health_state.dart';
import 'api_cache.dart';
import 'aura_state.dart';
import 'cardio_norms.dart';
import 'consent_state.dart';
import 'goals_state.dart';
import 'local_data.dart';
import 'providers.dart';
import 'season_state.dart';
import 'server_game.dart';

const _outboxKey = 'outbox_v1';
const _emailKey = 'account_email';
const _bannedKey = 'account_banned';

/// Причина блокировки аккаунта администратором ('' — без причины), null — не
/// заблокирован. Пока задана, вместо приложения — экран блокировки (BanScreen).
/// Снимается успешным входом в другой (или разблокированный) аккаунт.
class BanNotifier extends Notifier<String?> {
  @override
  String? build() => ref.read(prefsProvider).getString(_bannedKey);

  Future<void> set(String reason) async {
    state = reason;
    await ref.read(prefsProvider).setString(_bannedKey, reason);
  }

  Future<void> clear() async {
    state = null;
    await ref.read(prefsProvider).remove(_bannedKey);
  }
}

final banProvider = NotifierProvider<BanNotifier, String?>(BanNotifier.new);
const _autoSyncKey = 'auto_sync_v1';
const _lastSyncKey = 'last_sync_v1';

/// Пока приложение открыто, синхронизация повторяется с этим шагом.
const autoSyncEvery = Duration(minutes: 5);

/// Почему была синхронизация — для строки статуса в настройках.
enum SyncReason {
  launch('при входе'),
  change('после изменений'),
  timer('по расписанию'),
  background('при сворачивании'),
  manual('вручную');

  const SyncReason(this.label);
  final String label;
}

const _maxOutbox = 300;

/// Сверять ли вкладки (боты дня, лига, ауры, сезон) при синхронизации: герой на
/// сервере изменился, потянули вниз, прошло 10 минут (лига движется от чужих
/// боёв) или наступил новый день (новые боты). Иначе — экран не трогаем.
bool tabsNeedCheck({
  required bool heroChanged,
  required bool manual,
  required DateTime? last,
  required DateTime now,
}) =>
    heroChanged ||
    manual ||
    last == null ||
    now.difference(last) >= const Duration(minutes: 10) ||
    now.day != last.day;

/// Очередь с новым заданием [job] от [owner]: такое же ждущее действие того же
/// аккаунта (тот же key — образ, витрина) заменяется, тренировки копятся.
List<OutboxJob> outboxWith(List<OutboxJob> jobs, OutboxJob job, String? owner) {
  final key = job.key;
  return [
    for (final j in jobs)
      if (key == null || j.key != key || j.owner != owner) j,
    job.ownedBy(owner),
  ];
}

/// Запрос, ожидающий отправки на сервер: тренировка (clientId делает отправку
/// идемпотентной) или действие, сделанное без сети (образ, витрина, награда…).
class OutboxJob {
  const OutboxJob({
    required this.path,
    required this.body,
    this.owner,
    this.method = 'POST',
    this.key,
  });

  final String path;
  final Map<String, dynamic> body;

  /// POST или PUT.
  final String method;

  /// Одно и то же действие (образ, витрина): новое заменяет ждущее старое —
  /// на сервер уходит только последнее состояние.
  final String? key;

  /// Чья тренировка: e-mail аккаунта на момент записи. null — сделана до входа,
  /// уйдёт в первый аккаунт, в который войдут. Чужая (вошли в другой аккаунт) —
  /// не отправляется: иначе тренировки одного засчитались бы другому.
  final String? owner;

  Map<String, dynamic> toJson() => {
    'path': path,
    'body': body,
    if (owner != null) 'owner': owner,
    if (method != 'POST') 'method': method,
    'key': ?key,
  };

  factory OutboxJob.fromJson(Map<String, dynamic> j) => OutboxJob(
    path: j['path'],
    body: Map<String, dynamic>.from(j['body']),
    owner: j['owner'] as String?,
    method: j['method'] as String? ?? 'POST',
    key: j['key'] as String?,
  );

  OutboxJob ownedBy(String? email) => OutboxJob(
    path: path,
    body: body,
    owner: owner ?? email,
    method: method,
    key: key,
  );
}

class AccountState {
  const AccountState({
    this.email,
    this.pending = 0,
    this.syncing = false,
    this.lastSyncedAt,
    this.error,
    this.rejected = 0,
    this.awaitingWatchPulse = false,
    this.autoSync = true,
    this.lastReason,
  });

  /// Автосинхронизация: при входе, после изменений на сервере, каждые 5 минут
  /// и при сворачивании.
  final bool autoSync;

  /// Почему была последняя синхронизация.
  final SyncReason? lastReason;

  /// null — аккаунта нет, приложение работает офлайн.
  final String? email;
  final int pending;
  final bool syncing;
  final DateTime? lastSyncedAt;
  final String? error;

  /// Сколько тренировок сервер отклонил (данные не прошли проверку).
  final int rejected;

  /// Тренировка ждёт, пока часы передадут пульс в Health Connect.
  final bool awaitingWatchPulse;

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
    bool? awaitingWatchPulse,
    bool? autoSync,
    SyncReason? lastReason,
  }) => AccountState(
    autoSync: autoSync ?? this.autoSync,
    lastReason: lastReason ?? this.lastReason,
    email: clearEmail ? null : email ?? this.email,
    pending: pending ?? this.pending,
    syncing: syncing ?? this.syncing,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    error: clearError ? null : error ?? this.error,
    rejected: rejected ?? this.rejected,
    awaitingWatchPulse: awaitingWatchPulse ?? this.awaitingWatchPulse,
  );
}

/// Ключ, под которым раньше хранился введённый тестером адрес сервера.
const serverUrlKey = 'server_url';

/// Адрес сервера задаётся только при сборке (--dart-define, см. apiBaseUrl).
/// Свой адрес в приложении больше не вводится: иначе вход и токен могли бы
/// уйти на чужой сервер. Сохранённый прежде адрес стираем.
final serverUrlProvider = Provider<String>((ref) {
  ref.read(prefsProvider).remove(serverUrlKey);
  return apiBaseUrl;
});

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
  Timer? _pulseRetry;

  /// Нет сети, а в очереди тренировки — пробуем снова чаще, чем раз в 5 минут:
  /// 30 с, 1, 2, 4 и дальше каждые 5 минут (п. 114).
  Timer? _netRetry;
  int _netFailures = 0;
  Timer? _autoTimer;
  Timer? _afterWrite;

  /// Синхронизацию попросили, пока шла предыдущая, — повторить сразу после неё,
  /// иначе только что законченная тренировка ждала бы до таймера.
  bool _again = false;

  /// Последний ответ /v1/me: не изменился — вкладки не пересверяем.
  String? _lastMe;

  /// Когда вкладки (боты, лига, ауры, сезон) последний раз сверялись с сервером.
  DateTime? _tabsAt;

  /// Как часто перепроверять Health Connect, пока тренировка ждёт пульс.
  static const _pulseRetryEvery = Duration(minutes: 1);

  @override
  AccountState build() {
    final prefs = ref.read(prefsProvider);
    final last = _readLastSync(prefs.getString(_lastSyncKey));
    final s = AccountState(
      email: prefs.getString(_emailKey),
      pending: _readOutbox().length,
      autoSync: prefs.getBool(_autoSyncKey) ?? true,
      lastSyncedAt: last?.at,
      lastReason: last?.reason,
    );
    // Автосинхронизация: сразу при входе, каждые 5 минут, пока приложение открыто,
    // и последний раз при сворачивании — до следующего открытия.
    // Выключена — как раньше: отправляем только накопившуюся очередь.
    if (s.signedIn && (s.autoSync || s.pending > 0)) {
      Future.microtask(() => sync(reason: SyncReason.launch));
    }
    if (s.signedIn && s.autoSync) _startAutoTimer();
    final lifecycle = AppLifecycleListener(
      onResume: () {
        if (!state.signedIn) return;
        if (state.autoSync) {
          sync(reason: SyncReason.launch);
          _startAutoTimer();
        } else if (state.pending > 0) {
          sync(reason: SyncReason.launch);
        }
      },
      onHide: () {
        _autoTimer?.cancel();
        if (state.signedIn && state.autoSync) {
          sync(reason: SyncReason.background);
        }
      },
    );
    ref.onDispose(lifecycle.dispose);
    ref.onDispose(() => _pulseRetry?.cancel());
    ref.onDispose(() => _netRetry?.cancel());
    ref.onDispose(() => _autoTimer?.cancel());
    // Покупка, награда, дуэль и т. п. — через несколько секунд сверяемся с сервером
    // (одной синхронизацией на серию действий). Запросы самой синхронизации не в счёт.
    ApiClient.onServerWrite = (_) {
      if (state.syncing || !state.signedIn || !state.autoSync) return;
      _afterWrite?.cancel();
      _afterWrite = Timer(
        afterWriteDelay(state.lastSyncedAt, DateTime.now()),
        () => sync(reason: SyncReason.change),
      );
    };
    ref.onDispose(() {
      _afterWrite?.cancel();
      ApiClient.onServerWrite = null;
    });
    if (s.signedIn) Future.microtask(() => setupPush(ref, _api));
    return s;
  }

  void _startAutoTimer() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(autoSyncEvery, (_) {
      if (state.signedIn && state.autoSync) sync(reason: SyncReason.timer);
    });
  }

  Future<void> setAutoSync(bool on) async {
    await ref.read(prefsProvider).setBool(_autoSyncKey, on);
    state = state.copyWith(autoSync: on);
    if (on && state.signedIn) {
      _startAutoTimer();
      sync(reason: SyncReason.manual);
    } else {
      _autoTimer?.cancel();
    }
  }

  static ({DateTime at, SyncReason reason})? _readLastSync(String? raw) {
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return (
        at: DateTime.parse(j['at']),
        reason: SyncReason.values.asNameMap()[j['reason']] ?? SyncReason.manual,
      );
    } catch (_) {
      return null;
    }
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

  /// Снять ждущую отправки тренировку из очереди («вернуться к тренировке»).
  /// Идёт синхронизация — сначала дождаться её. true — была в очереди и снята,
  /// false — уже на сервере (или не было).
  Future<bool> dropQueued(String clientId) async {
    for (var i = 0; i < 75 && state.syncing; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    final jobs = _readOutbox();
    final left = [
      for (final j in jobs)
        if (j.body['clientId'] != clientId) j,
    ];
    if (left.length == jobs.length) return false;
    await _writeOutbox(left);
    return true;
  }

  Future<void> enqueueStrength(
    WorkoutSession s,
    DateTime finishedAt,
    List<PulseSample> pulse, {
    String? clientId,
  }) => _enqueue(
    OutboxJob(
      path: '/v1/workouts/strength',
      body: {
        'clientId': clientId ?? newClientId(),
        'startedAt': s.startedAt.toUtc().toIso8601String(),
        'finishedAt': finishedAt.toUtc().toIso8601String(),
        'entries': _strengthEntries(s, pulse),
        if (s.events.isNotEmpty)
          'events': [
            for (final e in s.events)
              {
                't': e.at.difference(s.startedAt).inSeconds.clamp(0, 86400),
                'k': e.kind.code,
                if (e.exerciseId != null) 'ex': e.exerciseId,
              },
          ],
        'pulse': _pulseJson(pulse),
        if (s.planCompleted) 'planCompleted': true,
      },
    ),
  );

  /// Подходы с метками времени и сводкой пульса по каждому (п. 106): секунды от
  /// начала, отдых перед подходом, пик и пульс отдыха. Пульс — только при согласии
  /// ([pulse] тогда пустой и пиков нет).
  static List<Map<String, dynamic>> _strengthEntries(
    WorkoutSession s,
    List<PulseSample> pulse,
  ) {
    final perSet = {
      for (final (id, i, p) in setPulses(
        startedAt: s.startedAt,
        entries: s.entries,
        pulse: pulse,
      ))
        (id, i): p,
    };
    return [
      for (final e in s.entries)
        if (e.sets.isNotEmpty)
          {
            'exerciseId': e.exercise.id,
            'sets': [
              for (final (i, set) in e.sets.indexed)
                {
                  'weight': set.weight,
                  'reps': set.reps,
                  if (perSet[(e.exercise.id, i)] case final p?) ...{
                    't': p.t,
                    'rest': ?p.rest,
                    'peak': ?p.peak,
                    'base': ?p.base,
                  },
                },
            ],
          },
    ];
  }

  /// Тренировка ауры — тоже через очередь: в зале без сети она не теряется, а
  /// сервер кладёт её в день окончания, даже если дошла позже (п. 114).
  Future<void> enqueueAura(
    String kind, {
    required DateTime startedAt,
    required DateTime finishedAt,
    required List<PulseSample> pulse,
  }) => _enqueue(
    OutboxJob(
      path: '/v1/auras/$kind/train',
      body: {
        'startedAt': startedAt.toUtc().toIso8601String(),
        'finishedAt': finishedAt.toUtc().toIso8601String(),
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

  /// Входная тренировка (п. 116): результаты на сервер через очередь — без сети не теряются,
  /// а clientId не даст начислить монеты дважды.
  Future<void> enqueueEntryTest(Map<String, dynamic> body) =>
      _enqueue(OutboxJob(path: '/v1/entry-test', body: body));

  /// Действие на сервере, которое можно отложить (п. 114, часть 2): есть сеть —
  /// уходит сразу и возвращает ответ; нет — встаёт в очередь (с [key] — вместо
  /// ждущего такого же) и уйдёт при синхронизации; тогда null. Сервер отказал по
  /// существу — [ApiException], как обычно. Без аккаунта — null, ничего не шлём.
  Future<Map<String, dynamic>?> sendOrQueue(
    String method,
    String path,
    Map<String, dynamic> body, {
    String? key,
  }) async {
    if (!state.signedIn) return null;
    try {
      return method == 'PUT'
          ? await _api.put(path, body)
          : await _api.post(path, body);
    } on ApiException catch (e) {
      if (!e.isNetwork) rethrow;
      await _enqueue(
        OutboxJob(path: path, body: body, method: method, key: key),
      );
      return null;
    }
  }

  Future<void> _enqueue(OutboxJob job) async {
    final jobs = outboxWith(_readOutbox(), job, state.email);
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
      if (hero.extraGoals.isNotEmpty)
        'goals': [for (final g in hero.extraGoals) g.name],
      'trainingFormat': hero.format.name,
      'scheduleDays': hero.trainingDays,
      'appearance': hero.look.toJson(),
      'timezone': deviceTimeZone(),
      if (hero.body.age != null) 'age': hero.body.age,
      if (hero.body.restingHeartRate != null)
        'restingHr': hero.body.restingHeartRate,
      if (ref.read(healthConsentProvider).asked) ...{
        'healthConsent': ref.read(healthConsentProvider).allowsPulse,
        'policyVersion': privacyPolicyUpdated,
      },
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
    await ref.read(banProvider.notifier).clear();
    if (state.autoSync) _startAutoTimer();
    await ref.read(healthConsentProvider.notifier).pushToServer();
    await sync();
    await setupPush(ref, _api);
  }

  Future<void> logout() async {
    _autoTimer?.cancel();
    // Пока вход ещё есть — отправить очередь: после выхода её не отправить.
    if (state.pending > 0) {
      try {
        await sync(reason: SyncReason.manual);
      } catch (_) {}
    }
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
    // Лиги, друзья, уведомления прошлого аккаунта не остаются на телефоне.
    await ref.read(apiCacheProvider).clear();
    _lastMe = null;
    state = state.copyWith(clearEmail: true, clearError: true);
  }

  /// Удалить аккаунт на сервере и все данные на телефоне. Бросает [ApiException]
  /// при неверном пароле или без сети — тогда ничего не удаляется.
  /// После удаления этот провайдер пересоздаётся, поэтому состояние здесь не трогаем.
  Future<void> deleteAccount(String password) async {
    await _api.post('/v1/auth/delete-account', {'password': password});
    await ref.read(localDataProvider).wipe();
  }

  void _scheduleNetRetry() {
    _netRetry?.cancel();
    final delay = netRetryDelay(_netFailures++);
    _netRetry = Timer(delay, () => sync(reason: SyncReason.timer));
  }

  /// Приложение открыто, а пульс с часов ещё не пришёл — проверим снова позже.
  void _schedulePulseRetry(bool waiting) {
    _pulseRetry?.cancel();
    state = state.copyWith(awaitingWatchPulse: waiting);
    if (waiting) _pulseRetry = Timer(_pulseRetryEvery, sync);
  }

  /// Сколько ждать, пока Samsung Health и другие приложения часов передадут
  /// пульс в Health Connect: обычно минуты, но бывает и через час-два (часы
  /// синхронизируются с телефоном пачками). Дольше — уходит с тем, что есть.
  static const watchSyncWait = Duration(hours: 3);

  /// Тело запроса с пульсом из Health Connect, если живого пульса не было.
  /// null — пульса пока нет, но он может появиться: отправку откладываем.
  Future<Map<String, dynamic>?> _withWatchPulse(
    Map<String, dynamic> body,
  ) async {
    // Задания без пульса (входная тренировка) — как есть.
    if (body['pulse'] is! List) return body;
    // Без согласия на данные о здоровье пульс не отправляем, даже записанный.
    if (!ref.read(healthConsentProvider).allowsPulse)
      return {...body, 'pulse': []};
    final health = ref.read(healthProvider);
    if ((body['pulse'] as List).isNotEmpty || !health.connected) return body;
    final from = DateTime.parse(body['startedAt'] as String);
    final to = DateTime.parse(body['finishedAt'] as String);
    final pulse = await ref
        .read(healthProvider.notifier)
        .heartRateBetween(from, to);
    final mayStillArrive = DateTime.now().difference(to) < watchSyncWait;
    // Ждём, пока пульс не покроет тренировку: Samsung Health досылает его частями.
    if (mayStillArrive && !pulseCovers(pulse, from, to)) return null;
    return {...body, 'pulse': _pulseJson(pulse)};
  }

  /// Отправить очередь по порядку, затем взять состояние героя с сервера.
  /// Нет сети — очередь ждёт; данные отклонены — тренировка снимается с очереди.
  Future<void> sync({SyncReason reason = SyncReason.manual}) async {
    if (!state.signedIn) return;
    if (state.syncing) {
      _again = true;
      return;
    }
    _again = false;
    state = state.copyWith(syncing: true, clearError: true);
    var rejected = 0;
    var waitingForPulse = false;
    try {
      // Задание, которое ждёт пульс из Samsung Health, остаётся в очереди, а
      // остальные (кардио, аура, входная тренировка) уходят, не дожидаясь его.
      final waiting = <OutboxJob>[];
      var jobs = _readOutbox();
      while (jobs.isNotEmpty) {
        final job = jobs.first;
        final mine = job.owner == null || job.owner == state.email;
        final body = mine ? await _withWatchPulse(job.body) : null;
        if (!mine) {
          // Тренировка другого аккаунта на этом телефоне: не отправляем, но и не
          // теряем — уйдёт, когда её владелец снова войдёт.
          waiting.add(job);
        } else if (body == null) {
          waitingForPulse = true;
          waiting.add(job);
        } else {
          try {
            job.method == 'PUT'
                ? await _api.put(job.path, body)
                : await _api.post(job.path, body);
          } on ApiException catch (e) {
            if (!e.isRejected) rethrow;
            rejected++;
          }
        }
        jobs = jobs.sublist(1);
        await _writeOutbox([...waiting, ...jobs]);
      }
      // Тренировка ещё ждёт пульс (Samsung Health, до 3 ч) — на сервере её пока нет.
      // Не накладываем его состояние: иначе опыт, монеты и серия на телефоне
      // откатились бы до прихода пульса. Применим, когда очередь разойдётся.
      var heroChanged = true;
      if (!waitingForPulse) {
        final me = await _api.get('/v1/me');
        final key = jsonEncode(me);
        heroChanged = key != _lastMe;
        _lastMe = key;
        await ref.read(heroProvider.notifier).applyServer(me);
      }
      // Герой на сервере изменился (тренировка, бой, награда) — боты дня, лига,
      // ауры и очки сезона тоже: сверяем их. Не изменился (таймер, сворачивание) —
      // вкладки не трогаем. Уведомления приходят сами по себе — сверка дешёвая (304).
      final now = DateTime.now();
      if (tabsNeedCheck(
        heroChanged: heroChanged,
        manual: reason == SyncReason.manual,
        last: _tabsAt,
        now: now,
      )) {
        _tabsAt = now;
        ref.invalidate(serverBotsProvider);
        ref.invalidate(serverLeagueProvider);
        ref.invalidate(auraProvider);
        ref.invalidate(seasonProvider);
        // Новое кардио — норма пульса вида могла сдвинуться (калибровка).
        ref.invalidate(cardioNormsProvider);
      }
      ref.invalidate(notificationsProvider);
      await ref.read(goalsSyncProvider).push();
      _netFailures = 0;
      _netRetry?.cancel();
      final at = DateTime.now();
      state = state.copyWith(
        lastSyncedAt: at,
        lastReason: reason,
        rejected: state.rejected + rejected,
      );
      await ref
          .read(prefsProvider)
          .setString(
            _lastSyncKey,
            jsonEncode({'at': at.toIso8601String(), 'reason': reason.name}),
          );
      _schedulePulseRetry(waitingForPulse);
    } on ApiException catch (e) {
      if (e.status == 401 || e.isBanned) {
        // Refresh-токен отозван или истёк: просим войти заново, очередь сохраняется.
        await ref.read(prefsProvider).remove(_emailKey);
        if (e.isBanned) await ref.read(banProvider.notifier).set(e.banReason);
        state = state.copyWith(
          clearEmail: true,
          error: e.isBanned
              ? 'Аккаунт заблокирован: ${e.banReason}'
              : 'Войди в аккаунт заново',
        );
      } else {
        state = state.copyWith(
          error: e.message,
          rejected: state.rejected + rejected,
        );
        if (e.isNetwork && state.pending > 0) _scheduleNetRetry();
      }
    } finally {
      state = state.copyWith(syncing: false);
      // Журнал — вместе с синхронизацией: после тренировки и покупки он тоже на сервере.
      unawaited(AppLog.upload(_api));
    }
    if (_again && state.signedIn) {
      _again = false;
      await sync(reason: reason);
    }
  }
}

/// Пульс покрывает тренировку настолько, что сервер её засчитает (как
/// hasEnoughPulse на сервере): от первой до последней точки — не меньше доли.
bool pulseCovers(List<PulseSample> pulse, DateTime from, DateTime to) {
  if (pulse.length < 2) return false;
  final total = to.difference(from).inSeconds;
  final covered = pulse.last.at.difference(pulse.first.at).inSeconds;
  return total > 0 && covered / total >= GameConfig.minPulseCoverage;
}

/// Пауза перед синхронизацией после изменения на сервере: 3 с, чтобы серия
/// действий ушла одной синхронизацией, и не чаще раза в 15 с — предохранитель
/// от зацикливания, если синхронизация сама вызовет запрос-изменение.
Duration afterWriteDelay(DateTime? lastSync, DateTime now) {
  const min = Duration(seconds: 3);
  if (lastSync == null) return min;
  final wait = const Duration(seconds: 15) - now.difference(lastSync);
  return wait > min ? wait : min;
}

/// Пауза перед новой попыткой отправить очередь без сети: 30 с, 1, 2, 4, затем 5 мин.
Duration netRetryDelay(int failures) {
  final seconds = 30 * (1 << failures.clamp(0, 4));
  return Duration(seconds: seconds > 300 ? 300 : seconds);
}

final accountProvider = NotifierProvider<AccountNotifier, AccountState>(
  AccountNotifier.new,
);
