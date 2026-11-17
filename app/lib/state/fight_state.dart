/// Бой по раундам (docs/COMBAT.md): начать, сыграть раунд, продолжить начатый.
/// Числа и награды считает сервер; здесь — только его ответы.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/combat.dart';
import '../game/duel.dart';
import 'account_state.dart';
import 'providers.dart';
import 'season_state.dart';
import 'server_game.dart';

class FightView {
  const FightView({
    required this.id,
    required this.friend,
    required this.attacker,
    required this.defender,
    required this.powerA,
    required this.powerD,
    required this.hpA,
    required this.hpD,
    required this.round,
    required this.rules,
    this.lastSteps = const [],
    this.finished = false,
    this.won,
    this.coins,
    this.ladderNote,
  });

  final String id;

  /// Бой с другом (иначе — бот лестницы).
  final bool friend;
  final Fighter attacker;
  final Fighter defender;
  final int powerA;
  final int powerD;

  /// Здоровье после последнего сыгранного раунда.
  final int hpA;
  final int hpD;

  /// Сколько раундов сыграно.
  final int round;
  final CombatRules rules;

  /// Шаги последнего раунда — экран проигрывает их по очереди.
  final List<CombatStep> lastSteps;
  final bool finished;
  final bool? won;
  final int? coins;
  final String? ladderNote;

  FightView afterRound(Map<String, dynamic> j) => FightView(
    id: id,
    friend: friend,
    attacker: attacker,
    defender: defender,
    powerA: powerA,
    powerD: powerD,
    hpA: (j['hpA'] as num).toInt(),
    hpD: (j['hpD'] as num).toInt(),
    round: (j['round'] as num).toInt(),
    rules: rules,
    lastSteps: [
      for (final s in j['steps'] as List)
        CombatStep.fromJson(Map<String, dynamic>.from(s as Map)),
    ],
    finished: j['finished'] == true,
    won: j['attackerWon'] as bool?,
    coins: (j['coins'] as num?)?.toInt(),
    ladderNote: ladderNoteOf(j),
  );

  static FightView fromJson(Map<String, dynamic> j) => FightView(
    id: j['fightId'] as String,
    friend: j['opponentKind'] == 'user',
    attacker: fighterFromJson(Map<String, dynamic>.from(j['attacker'] as Map)),
    defender: fighterFromJson(Map<String, dynamic>.from(j['defender'] as Map)),
    powerA: (j['powerA'] as num).toInt(),
    powerD: (j['powerD'] as num).toInt(),
    hpA: (j['hpA'] as num).toInt(),
    hpD: (j['hpD'] as num).toInt(),
    round: (j['round'] as num).toInt(),
    rules: CombatRules.fromJson(Map<String, dynamic>.from(j['rules'] as Map)),
  );
}

/// Подпись лестницы в итоге боя: новая ступень, босс, первая победа.
String? ladderNoteOf(Map<String, dynamic> j) => j['tierUp'] == true
    ? 'Босс повержен — открыта новая ступень лестницы'
    : j['firstWin'] == true
    ? (j['boss'] == true
          ? 'Босс повержен'
          : 'Первая победа над этим ботом — полная награда')
    : null;

class FightNotifier extends Notifier<FightView?> {
  @override
  FightView? build() => null;

  Future<FightView> startBot(Fighter bot) =>
      _start('/v1/fights/bots/${bot.id}');

  Future<FightView> startFriend(Fighter friend) =>
      _start('/v1/fights/users/${friend.id}');

  Future<FightView> _start(String path) async {
    final j = await ref.read(apiProvider).post(path, {});
    return state = FightView.fromJson(j);
  }

  /// Незаконченный бой на сервере — продолжить; null — такого нет.
  Future<FightView?> resume() async {
    try {
      final j = await ref.read(apiProvider).get('/v1/fights/current');
      if (j['fightId'] == null) return null;
      return state = FightView.fromJson(j);
    } on FormatException {
      return null; // пустой ответ — боя нет
    }
  }

  /// Раунд: цепочка из 5 действий. На последнем — герой, лестница, сезон.
  Future<FightView> playRound(List<CombatAction> chain) async {
    final fight = state;
    if (fight == null) throw StateError('No fight');
    final j = await ref.read(apiProvider).post('/v1/fights/${fight.id}/round', {
      'actions': [for (final a in chain) a.name],
    });
    final next = fight.afterRound(j);
    if (next.finished) {
      if (j['hero'] case final Map hero) {
        await ref
            .read(heroProvider.notifier)
            .applyServer(Map<String, dynamic>.from(hero));
      }
      ref.invalidate(serverBotsProvider);
      ref.invalidate(serverFriendsProvider);
      ref.invalidate(serverLeagueProvider);
      ref.invalidate(seasonProvider);
    }
    return state = next;
  }

  void close() => state = null;

  /// Показать бой без сервера — для тестов раскладки.
  void show(FightView fight) => state = fight;
}

final fightProvider = NotifierProvider<FightNotifier, FightView?>(
  FightNotifier.new,
);
