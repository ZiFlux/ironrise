import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/game/anti_fraud.dart';
import 'package:ironrise/state/account_state.dart';

// П. 114: без сети очередь тренировок пробует снова 30 с → 1 → 2 → 4 → 5 мин.
void main() {
  test('паузы повтора растут и упираются в 5 минут', () {
    expect(
      [for (var i = 0; i < 7; i++) netRetryDelay(i).inSeconds],
      [30, 60, 120, 240, 300, 300, 300],
    );
  });

  test('синхронизация после изменения: 3 с, но не чаще раза в 15 с', () {
    final now = DateTime(2026, 11, 16, 22);
    expect(afterWriteDelay(null, now).inSeconds, 3);
    expect(
      afterWriteDelay(now.subtract(const Duration(minutes: 1)), now).inSeconds,
      3,
    );
    expect(
      afterWriteDelay(now.subtract(const Duration(seconds: 5)), now).inSeconds,
      10,
    );
    expect(afterWriteDelay(now, now).inSeconds, 15);
  });

  test('пульс из Health Connect: ждём, пока не покроет тренировку', () {
    final from = DateTime(2026, 11, 17, 10);
    final to = from.add(const Duration(minutes: 60));
    PulseSample at(int min) =>
        PulseSample(from.add(Duration(minutes: min)), 120);
    expect(pulseCovers([], from, to), isFalse);
    // Samsung Health прислал только начало — ждём дальше.
    expect(pulseCovers([at(0), at(10), at(20)], from, to), isFalse);
    expect(pulseCovers([at(1), at(30), at(55)], from, to), isTrue);
    expect(AccountNotifier.watchSyncWait, const Duration(hours: 3));
  });

  test('очередь помнит, чья тренировка: чужое не уйдёт в другой аккаунт', () {
    const job = OutboxJob(path: '/v1/workouts/strength', body: {'a': 1});
    // До входа — без владельца: уйдёт в первый аккаунт.
    expect(OutboxJob.fromJson(job.toJson()).owner, isNull);
    final mine = job.ownedBy('a@x.ru');
    expect(OutboxJob.fromJson(mine.toJson()).owner, 'a@x.ru');
    // Владелец не перезаписывается.
    expect(mine.ownedBy('b@x.ru').owner, 'a@x.ru');
  });

  test(
    'действия без сети: метод и ключ сохраняются, старая очередь читается',
    () {
      const put = OutboxJob(
        path: '/v1/me/appearance',
        body: {'appearance': {}},
        method: 'PUT',
        key: 'appearance',
      );
      final back = OutboxJob.fromJson(put.toJson());
      expect(back.method, 'PUT');
      expect(back.key, 'appearance');
      // Записи до 1.7 — без метода: это POST тренировок.
      final old = OutboxJob.fromJson({
        'path': '/v1/workouts/cardio',
        'body': {},
      });
      expect(old.method, 'POST');
      expect(old.key, isNull);
    },
  );

  test('одно и то же действие заменяет ждущее, тренировки копятся', () {
    OutboxJob look(int n) => OutboxJob(
      path: '/v1/me/appearance',
      body: {'n': n},
      method: 'PUT',
      key: 'appearance',
    );
    const workout = OutboxJob(path: '/v1/workouts/strength', body: {'w': 1});
    var q = outboxWith([], workout, 'a@x.ru');
    q = outboxWith(q, look(1), 'a@x.ru');
    q = outboxWith(q, workout, 'a@x.ru');
    q = outboxWith(q, look(2), 'a@x.ru');
    expect(
      [for (final j in q) j.body],
      [
        {'w': 1},
        {'w': 1},
        {'n': 2},
      ],
    );
    // Образ другого аккаунта на этом телефоне не трогаем.
    q = outboxWith(q, look(3), 'b@x.ru');
    expect(q.where((j) => j.key == 'appearance'), hasLength(2));
  });

  test('вкладки сверяются, только когда есть зачем', () {
    final at = DateTime(2026, 11, 25, 12);
    bool check({
      bool hero = false,
      bool manual = false,
      required DateTime now,
    }) => tabsNeedCheck(heroChanged: hero, manual: manual, last: at, now: now);
    // Таймер через 5 минут, герой тот же — не трогаем.
    expect(check(now: at.add(const Duration(minutes: 5))), isFalse);
    expect(check(hero: true, now: at.add(const Duration(minutes: 1))), isTrue);
    expect(check(manual: true, now: at), isTrue);
    expect(check(now: at.add(const Duration(minutes: 10))), isTrue);
    // Полночь — новые боты дня.
    final late = DateTime(2026, 11, 25, 23, 58);
    expect(
      tabsNeedCheck(
        heroChanged: false,
        manual: false,
        last: late,
        now: late.add(const Duration(minutes: 3)),
      ),
      isTrue,
    );
    expect(
      tabsNeedCheck(heroChanged: false, manual: false, last: null, now: at),
      isTrue,
    );
  });
}
