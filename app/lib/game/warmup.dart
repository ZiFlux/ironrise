import 'body_part.dart';
import 'exercise_catalog.dart';
import 'program.dart';

/// Разминка перед тренировкой (п. 26 бэклога): лёгкое кардио, общая суставная
/// разминка сверху вниз — шея, плечи, локти и кисти, спина, поясница, таз,
/// колени и стопы — для любой тренировки, а потом акцент на мышцы и суставы,
/// которые сегодня работают больше всего: так меньше риск растяжений и
/// нагрузки на холодные суставы.
class Warmup {
  const Warmup._();

  /// Порядок общей разминки: сверху вниз (zone в shared/exercises.json).
  static const zones = [
    'neck',
    'shoulders',
    'arms',
    'back',
    'waist',
    'hips',
    'knees',
  ];

  /// Движений на акцент под мышцы дня.
  static const focusMoves = 3;

  /// Всего движений без кардио.
  static const maxMoves = 10;

  static bool _available(ExerciseGear gear, Equipment equipment) =>
      switch (gear) {
        ExerciseGear.none => true,
        ExerciseGear.dumbbells => true,
        ExerciseGear.gym => equipment == Equipment.gym,
      };

  /// Части тела, на которые приходится заметная доля нагрузки дня.
  static Set<BodyPart> partsOf(List<Exercise> exercises) {
    final parts = {
      for (final e in exercises)
        for (final s in e.shares.entries)
          if (s.value >= 0.2 && s.key != BodyPart.cardio) s.key,
    };
    return parts.isEmpty
        ? {BodyPart.chest, BodyPart.back, BodyPart.legs, BodyPart.core}
        : parts;
  }

  /// Сколько работы дня приходится на каждую часть тела (сумма долей).
  static Map<BodyPart, double> loadOf(List<Exercise> exercises) {
    final load = <BodyPart, double>{};
    for (final e in exercises) {
      for (final s in e.shares.entries) {
        if (s.key == BodyPart.cardio) continue;
        load[s.key] = (load[s.key] ?? 0) + s.value;
      }
    }
    if (load.isEmpty) {
      for (final p in partsOf(const [])) {
        load[p] = 1;
      }
    }
    return load;
  }

  /// Кардио, общая разминка по суставам, затем акцент на части тела дня (жадно:
  /// по самой нагруженной ещё не размятой части).
  static List<WarmupMove> forExercises(
    List<Exercise> exercises,
    Equipment equipment,
  ) {
    final parts = partsOf(exercises);
    final load = loadOf(exercises);
    final moves = ExerciseCatalog.warmups
        .where((m) => _available(m.gear, equipment))
        .toList();
    final cardioOptions = moves.where((m) => m.isCardio).toList()
      // В зале — тренажёр; гребля, если день про спину. Дома — без прыжков сначала.
      ..sort((a, b) => _cardioRank(a, parts).compareTo(_cardioRank(b, parts)));
    final out = <WarmupMove>[if (cardioOptions.isNotEmpty) cardioOptions.first];
    for (final zone in zones) {
      final move = moves.where((m) => m.general == zone).firstOrNull;
      if (move != null) out.add(move);
    }
    // Акцент: части дня, которые общая разминка ещё не покрыла как следует.
    final need = {for (final p in parts) p: load[p] ?? 0.0};
    final focus = moves.where((m) => !m.isCardio && m.general == null).toList();
    var added = 0;
    while (added < focusMoves && out.length <= maxMoves) {
      WarmupMove? best;
      var bestScore = 0.0;
      for (final m in focus) {
        if (out.contains(m)) continue;
        final score = m.targets.fold(0.0, (s, p) => s + (need[p] ?? 0));
        if (score > bestScore) {
          best = m;
          bestScore = score;
        }
      }
      if (best == null) break;
      out.add(best);
      added++;
      // Размятая часть дальше весит вдвое меньше: следующее движение — на другую.
      for (final p in best.targets) {
        if (need.containsKey(p)) need[p] = need[p]! / 2;
      }
    }
    return out;
  }

  static int _cardioRank(WarmupMove m, Set<BodyPart> parts) {
    var rank = m.gear == ExerciseGear.gym ? 0 : 10;
    if (m.id == 'warm_rower' && !parts.contains(BodyPart.back)) rank += 5;
    if (m.id == 'warm_jumping_jacks') rank += 2;
    return rank;
  }

  /// Примерная длительность: секунды как есть, повтор ≈ 3 с, переходы по 15 с.
  static Duration duration(List<WarmupMove> moves) => Duration(
    seconds: moves.fold(
      0,
      (s, m) => s + (m.seconds ? m.amount : m.amount * 3) + 15,
    ),
  );
}
