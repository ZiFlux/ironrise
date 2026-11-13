import 'package:flutter/material.dart';

/// Шесть параметров тела аватара (ТЗ, раздел 3.1).
/// Цвет части тела появляется только на аватаре, в «блинах» уровней и в данных.
enum BodyPart {
  chest('Грудь', 'Отстаёт грудь', Color(0xFFE8795A), 'Отжимания 3 × 10'),
  back(
    'Спина',
    'Отстаёт спина',
    Color(0xFF5AA9E6),
    'Тяга гантели в наклоне 3 × 10',
  ),
  arms(
    'Руки',
    'Отстают руки',
    Color(0xFFE6B85A),
    'Сгибания с гантелями 3 × 12',
  ),
  legs('Ноги', 'Отстают ноги', Color(0xFF8CCB6E), 'Приседания 3 × 10'),
  core('Пресс', 'Отстаёт пресс', Color(0xFFA58AE6), 'Планка 3 × 30 с'),
  cardio(
    'Кардио',
    'Отстаёт кардио',
    Color(0xFFE66A9A),
    '30 минут быстрой ходьбы',
  );

  const BodyPart(
    this.label,
    this.laggingTitle,
    this.color,
    this.beginnerExercise,
  );

  final String label;
  final String laggingTitle;
  final Color color;

  /// Временная рекомендация для отстающей части, пока нет справочника упражнений.
  final String beginnerExercise;
}
