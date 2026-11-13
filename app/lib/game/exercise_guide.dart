import 'exercise_data.dart';

/// Техника выполнения: короткие шаги и главная ошибка новичка.
class ExerciseGuide {
  const ExerciseGuide(this.steps, this.mistake);

  final List<String> steps;
  final String mistake;
}

/// Техника силовых и разминочных упражнений (shared/exercises.json).
const exerciseGuides = generatedGuides;
