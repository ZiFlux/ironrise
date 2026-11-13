import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/game/program.dart';

void main() {
  test('сплит: спина+бицепс, грудь+трицепс+предплечья, ноги+плечи', () {
    final days = BaseProgram.days(Equipment.gym, 5, split: true);
    expect(days.map((d) => d.title), [
      'Спина и бицепс',
      'Грудь, трицепс, предплечья',
      'Ноги и плечи',
    ]);
    expect(days.every((d) => d.exercises.isNotEmpty), isTrue);
  });

  test('раскладка недели идёт с сегодняшнего дня и по кругу дней', () {
    final days = BaseProgram.days(Equipment.gym, 3, split: true);
    final layout = weekLayout(
      days: days,
      nextIndex: 1,
      trainingDays: [0, 2, 4],
      today: DateTime(2026, 11, 11), // среда
    );
    expect(layout.map((d) => d.weekday), [2, 4, 0]);
    expect(layout.map((d) => d.title), [
      'Грудь, трицепс, предплечья',
      'Ноги и плечи',
      'Спина и бицепс',
    ]);
  });
}
