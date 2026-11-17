import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/game/exercise_catalog.dart';
import 'package:ironrise/game/program.dart';
import 'package:ironrise/game/session_builder.dart';
import 'package:ironrise/game/training_format.dart';

List<ProgramDay> _days({
  required bool female,
  TrainingLevel level = TrainingLevel.intermediate,
  TrainingFormat format = TrainingFormat.upperLower,
  int step = 2,
}) => SessionBuilder.days(
  level: level,
  sessionsPerWeek: 4,
  equipment: Equipment.gym,
  stepOf: (_) => step,
  format: format,
  female: female,
);

Set<String> _ids(List<ProgramDay> days) => {
  for (final d in days)
    for (final e in d.exercises) e.exerciseId,
};

bool _marked(String id) => ExerciseCatalog.byId(id).marker == 'f';

void main() {
  test('девушке в дни ног — ягодичная изоляция и мост со штангой', () {
    final ids = _ids(_days(female: true));
    expect(
      ids.any((id) => ExerciseCatalog.byId(id).pattern == 'glutes_iso'),
      isTrue,
    );
    expect(ids, contains('hip_thrust'));
  });

  test('без метки пола — упражнения с меткой не подбираются', () {
    for (final format in TrainingFormat.values) {
      for (final level in TrainingLevel.values) {
        final ids = _ids(
          _days(
            female: false,
            format: format,
            level: level,
            step: level.index + 1,
          ),
        );
        expect(ids.where(_marked), isEmpty, reason: '$format $level');
      }
    }
  });

  test('в верхе и груди — бабочка для всех', () {
    final male = _days(female: false, format: TrainingFormat.split);
    expect(
      _ids(male).any((id) => ExerciseCatalog.byId(id).pattern == 'chest_fly'),
      isTrue,
    );
  });

  test('метка не попадает в тексты: только скрытое поле', () {
    for (final e in ExerciseCatalog.all) {
      expect(e.name.toLowerCase(), isNot(contains('жен')));
      expect(e.name.toLowerCase(), isNot(contains('девуш')));
    }
  });
}
