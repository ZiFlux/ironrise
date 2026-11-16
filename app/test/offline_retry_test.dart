import 'package:flutter_test/flutter_test.dart';
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
}
