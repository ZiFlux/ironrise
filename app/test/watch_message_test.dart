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
}
