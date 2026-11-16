import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/state/heart_rate_state.dart';

void main() {
  test('пульс с часов', () {
    final m = parseWatchMessage('pulse;128;340;1794400000000') as WatchPulse;
    expect(m.bpm, 128);
    expect(m.steps, 340);
    expect(m.at, DateTime.fromMillisecondsSinceEpoch(1794400000000));
  });

  test('часы завершили тренировку', () {
    expect(parseWatchMessage('stopped'), isA<WatchStopped>());
  });

  test('битые сообщения отбрасываются', () {
    expect(parseWatchMessage('pulse;abc;1;2'), isNull);
    expect(parseWatchMessage('pulse;0;1;2'), isNull);
    expect(parseWatchMessage('hello'), isNull);
  });

  // Совместимость: часы и телефон разных версий понимают друг друга.
  test('лишние поля от более новых часов не ломают разбор', () {
    final m =
        parseWatchMessage('pulse;128;340;1794400000000;spo2=97') as WatchPulse;
    expect(m.bpm, 128);
    expect(parseWatchMessage('stopped;reason=user'), isA<WatchStopped>());
    expect(
      (parseWatchMessage('version;1.5.0;x') as WatchVersion).version,
      '1.5.0',
    );
  });

  test('возможности часов: протокол и известные ауры', () {
    final c =
        parseWatchMessage('caps;proto=2;auras=fury,guard,newaura') as WatchCaps;
    expect(c.protocol, 2);
    expect(c.auras, {'fury', 'guard', 'newaura'});
    // Непонятные поля — не беда, протокол по умолчанию 1.
    final old = parseWatchMessage('caps;что-то') as WatchCaps;
    expect(old.protocol, 1);
    expect(old.auras, isEmpty);
  });
}
