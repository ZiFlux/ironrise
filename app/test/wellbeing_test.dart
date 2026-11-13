import 'package:flutter_test/flutter_test.dart';

import 'support/days.dart';

import 'package:ironrise/game/exercise_catalog.dart';
import 'package:ironrise/game/program.dart';
import 'package:ironrise/game/wellbeing.dart';

void main() {
  final gymA = gymDayA; // присед, жим, тяга блока, планка
  List<String> ids(AdaptedDay d) => [
    for (final e in d.day.exercises) e.exerciseId,
  ];

  test('без жалоб план не меняется', () {
    final d = Wellbeing.adapt(gymA, ease: false, avoid: const {});
    expect(d.changed, isFalse);
    expect(ids(d), [for (final e in gymA.exercises) e.exerciseId]);
  });

  test('облегчение — на подход меньше, но не меньше одного', () {
    final d = Wellbeing.adapt(gymA, ease: true, avoid: const {});
    expect(d.eased, isTrue);
    expect(d.day.exercises.every((e) => e.sets == 1), isTrue);
  });

  test(
    'колено: присед заменяется румынской тягой, жим ногами тоже грузит колено',
    () {
      final d = Wellbeing.adapt(gymA, ease: false, avoid: {PainZone.knee});
      expect(ids(d).first, 'romanian_deadlift');
      expect(d.adjustments.single.replacementId, 'romanian_deadlift');
    },
  );

  test('поясница: присед заменяется жимом ногами', () {
    final d = Wellbeing.adapt(gymA, ease: false, avoid: {PainZone.lowerBack});
    expect(ids(d).first, 'leg_press');
  });

  test(
    'плечо: жим и тяга блока убираются, если замены тоже нагружают плечо',
    () {
      final d = Wellbeing.adapt(gymA, ease: false, avoid: {PainZone.shoulder});
      expect(ids(d), isNot(contains('bench_press')));
      expect(ids(d), isNot(contains('lat_pulldown')));
      expect(ids(d), contains('plank'));
    },
  );

  test('замены — только из справочника и не повторяют упражнения дня', () {
    for (final zone in PainZone.values) {
      for (final equipment in Equipment.values) {
        for (final day in startDays(equipment)) {
          final d = Wellbeing.adapt(
            day,
            ease: false,
            avoid: {zone},
            equipment: equipment,
          );
          for (final id in ids(d)) {
            expect(() => ExerciseCatalog.byId(id), returnsNormally);
          }
          expect(
            ids(d).toSet().length,
            ids(d).length,
            reason: '$zone $equipment ${day.id}',
          );
        }
      }
    }
  });

  test('дома с гантелями замены — без тренажёров', () {
    final homeA = homeDayA; // приседания, отжимания, тяга гантели, планка
    final d = Wellbeing.adapt(
      homeA,
      ease: false,
      avoid: {PainZone.lowerBack},
      equipment: Equipment.dumbbells,
    );
    expect(ids(d), isNot(contains('lat_pulldown')));
    expect(ids(d), isNot(contains('back_extension')));
  });
}
