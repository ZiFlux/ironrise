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
}
