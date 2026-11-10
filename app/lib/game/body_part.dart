import 'package:flutter/material.dart';

/// Шесть параметров тела аватара (ТЗ, раздел 3.1).
enum BodyPart {
  chest('Грудь', Color(0xFFFF6B3D), Icons.shield_outlined, 'Отжимания или жим лёжа'),
  back('Спина', Color(0xFF3DA5FF), Icons.swap_vert, 'Тяга гантели в наклоне'),
  arms('Руки', Color(0xFFFFC23D), Icons.fitness_center, 'Сгибания рук с гантелями'),
  legs('Ноги', Color(0xFF7CDB5A), Icons.directions_walk, 'Приседания с собственным весом'),
  core('Пресс', Color(0xFFB57CFF), Icons.grid_view_rounded, 'Планка 3 × 30 секунд'),
  cardio('Кардио', Color(0xFFFF4D8D), Icons.favorite_outline, '30 минут быстрой ходьбы');

  const BodyPart(this.label, this.color, this.icon, this.beginnerExercise);

  final String label;
  final Color color;
  final IconData icon;

  /// Временная рекомендация для отстающей части, пока нет справочника упражнений.
  final String beginnerExercise;
}
