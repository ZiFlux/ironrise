import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../net/api_client.dart';
import 'account_state.dart';
import 'hero.dart';
import 'providers.dart';

/// Цели игрока (п. 100): главная и до двух дополнительных. Меняются в любой момент,
/// в том числе без сети: пометка [goalsDirtyKey] — «на сервер ещё не ушло», и пока
/// она стоит, сервер при синхронизации цели не перезаписывает.
class GoalsSync {
  GoalsSync(this.ref);

  final Ref ref;

  Future<void> save(Goal goal, List<Goal> extra) async {
    final hero = ref.read(heroProvider);
    if (hero == null) return;
    final extras = [
      for (final g in extra)
        if (g != goal) g,
    ].toSet().take(Goal.maxExtra).toList();
    await ref
        .read(heroProvider.notifier)
        .save(hero.copyWith(goal: goal, extraGoals: extras));
    await ref.read(prefsProvider).setBool(goalsDirtyKey, true);
    await push();
  }

  /// Отправить цели на сервер, если они менялись. Без сети — в следующий раз.
  Future<void> push() async {
    final prefs = ref.read(prefsProvider);
    final hero = ref.read(heroProvider);
    if (hero == null ||
        !(prefs.getBool(goalsDirtyKey) ?? false) ||
        !ref.read(accountProvider).signedIn) {
      return;
    }
    try {
      await ref.read(apiProvider).put('/v1/me/goals', {
        'goal': hero.goal.name,
        'goals': [for (final g in hero.extraGoals) g.name],
      });
      await prefs.remove(goalsDirtyKey);
    } on ApiException {
      // Нет сети или старый сервер — отправим при следующей синхронизации.
    }
  }
}

final goalsSyncProvider = Provider<GoalsSync>(GoalsSync.new);
