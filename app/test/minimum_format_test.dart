import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/game/body_part.dart';
import 'package:ironrise/game/recovery.dart';
import 'package:ironrise/game/training_format.dart';

// Формат «Минимум» (TRAINING_SYSTEM.md 13.6): загрузка → восстановление.
void main() {
  const minimum = TrainingFormat.minimum;

  test('Пн-Вт-Чт-Пт: загрузка Пн и Чт, восстановление Вт и Пт', () {
    const days = [0, 1, 3, 4];
    expect(loadDaysOf(minimum, days), {0, 3});
    expect(recoveryDaysOf(minimum, days), {1, 4});
    expect(maxRestDaysInRow(days), 2);
  });

  test('через воскресенье: Вс → Пн и Ср → Чт', () {
    const days = [6, 0, 2, 3];
    expect(loadDaysOf(minimum, days), {6, 2});
    expect(recoveryDaysOf(minimum, days), {0, 3});
  });

  test('у других форматов дней восстановления нет', () {
    expect(recoveryDaysOf(TrainingFormat.fullBody, const [0, 1, 2]), isEmpty);
    expect(loadDaysOf(TrainingFormat.fullBody, const [0, 2, 4]), {0, 2, 4});
  });

  test('график: у «Минимума» ровно 2 загрузки не подряд', () {
    expect(scheduleValid(minimum, withRecoveryDays({0, 3})), isTrue);
    expect(scheduleValid(minimum, withRecoveryDays({0})), isFalse);
    // Загрузки подряд — восстановление съедается, график неверный.
    expect(scheduleValid(minimum, withRecoveryDays({0, 1})), isFalse);
    expect(scheduleValid(TrainingFormat.custom, {0}), isFalse);
    expect(scheduleValid(TrainingFormat.custom, {0, 2}), isTrue);
    expect(
      scheduleValid(TrainingFormat.custom, {0, 1, 2, 3, 4, 5, 6}),
      isFalse,
    );
    expect(scheduleValid(TrainingFormat.custom, {0, 2, 4}), isTrue);
  });

  test(
    'восстановление: кардио, растяжка того, что работало, кор и дыхание',
    () {
      final plan = recoveryPlan({BodyPart.chest, BodyPart.arms});
      expect(plan.first.name, 'Лёгкое кардио');
      expect(plan.last.name, startsWith('Дыхание'));
      expect(plan.where((m) => m.part == BodyPart.chest), isNotEmpty);
      expect(plan.where((m) => m.part == BodyPart.legs), isEmpty);
      // Кор не грузили — добавлен.
      expect(plan.where((m) => m.part == BodyPart.core), isNotEmpty);
      expect(recoveryMinutes(plan), inInclusiveRange(10, 20));
    },
  );

  test('серия: пропуск восстановления не сжигает её (п. 131)', () {
    // Пн/Чт загрузка: отдых до 3 дней (Пт–Вс), восстановление необязательно.
    expect(
      maxRestDaysInRow(loadDaysOf(minimum, const [0, 1, 3, 4]).toList()),
      3,
    );
  });
}
