import 'package:flutter/material.dart';

/// Упражнение тренировки ауры: работа [seconds] секунд.
typedef AuraMove = ({String name, int seconds});

/// Ауры для дуэлей (server/src/game/aura.ts): срабатывают один раз за бой,
/// прокачиваются особыми тренировками 2 раза в неделю, отдельно от основных.
enum AuraKind {
  fury(
    'Ярость',
    'Красное пламя: твои удары сильнее на 3 хода',
    Color(0xFFFF5A1F),
    Color(0xFFFFC23D),
    'Взрывная тренировка: максимум усилия короткими отрезками',
    [
      (name: 'Прыжки из приседа', seconds: 40),
      (name: 'Берпи', seconds: 40),
      (name: 'Взрывные отжимания', seconds: 30),
      (name: 'Бег на месте с ускорением', seconds: 40),
    ],
  ),
  guard(
    'Стойкость',
    'Синее пламя: урон по тебе меньше на 3 удара соперника',
    Color(0xFF2E7BFF),
    Color(0xFF7FDBFF),
    'Статика: держать позицию, пока горит',
    [
      (name: 'Планка', seconds: 60),
      (name: 'Стульчик у стены', seconds: 50),
      (name: 'Боковая планка (каждая сторона)', seconds: 40),
      (name: 'Удержание «лодочка»', seconds: 40),
    ],
  ),
  haste(
    'Скорость',
    'Молния: сразу лишний удар',
    Color(0xFFB6FF3D),
    Color(0xFFF2FFB0),
    'Скорость: быстрые ноги и руки',
    [
      (name: 'Джампинг-джек', seconds: 45),
      (name: 'Бег с высоким подниманием колен', seconds: 40),
      (name: 'Челночный бег на месте', seconds: 40),
      (name: 'Быстрые выпады', seconds: 40),
    ],
  ),
  focus(
    'Фокус',
    'Фиолетовая вспышка: удар без промаха с мощным критом',
    Color(0xFF9B5CF6),
    Color(0xFFE2C8FF),
    'Контроль: медленно, точно, с дыханием',
    [
      (name: 'Отжимания 3 с вниз — 3 с вверх', seconds: 50),
      (name: 'Присед с паузой внизу', seconds: 50),
      (name: 'Баланс на одной ноге (каждая)', seconds: 40),
      (name: 'Дыхание «квадрат» 4-4-4-4', seconds: 60),
    ],
  );

  const AuraKind(
    this.label,
    this.effect,
    this.color,
    this.glow,
    this.trainingTitle,
    this.moves,
  );

  final String label;
  final String effect;

  /// Основной цвет пламени и светлая сердцевина.
  final Color color;
  final Color glow;
  final String trainingTitle;
  final List<AuraMove> moves;

  /// Разовая (вспышка на ударе) или длительная (горит несколько ходов).
  bool get burst => this == haste || this == focus;

  /// Кругов комплекса; между упражнениями — 20 с отдыха.
  static const rounds = 2;
  static const restSeconds = 20;

  int get totalSeconds =>
      rounds *
      (moves.fold(0, (a, m) => a + m.seconds) + moves.length * restSeconds);
}

/// Аура на ударе дуэли: чья и началась ли сейчас.
class AuraMark {
  const AuraMark({
    required this.attacker,
    required this.kind,
    this.start = false,
  });

  final bool attacker;
  final AuraKind kind;
  final bool start;
}
