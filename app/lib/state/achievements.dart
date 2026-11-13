import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../net/api_client.dart';
import '../widgets/status_toast.dart';
import 'account_state.dart';
import 'providers.dart';

const _claimedKey = 'achievements_claimed_v1';

/// Награды за достижения в приложении. Совпадает с server/src/game/shop.ts.
enum Achievement {
  guide('sn_first_step', 'кроссовки «Первый шаг»'),
  watch('acc_smartwatch', 'аксессуар «Смарт-часы»');

  const Achievement(this.itemId, this.title);

  final String itemId;
  final String title;
}

/// Какие награды уже выданы на этом телефоне.
class AchievementsNotifier extends Notifier<Set<Achievement>> {
  bool _resending = false;

  @override
  Set<Achievement> build() {
    // Награду получили без аккаунта, потом вошли — сервер о ней не знает:
    // досылаем, как только профиль с сервера придёт без этой вещи.
    ref.listen(heroProvider, (_, hero) => _resendMissing(hero?.ownedItems));
    final names = ref.read(prefsProvider).getStringList(_claimedKey) ?? [];
    return {
      for (final n in names)
        if (Achievement.values.asNameMap()[n] case final a?) a,
    };
  }

  Future<void> _resendMissing(Set<String>? owned) async {
    if (_resending || owned == null || !ref.read(accountProvider).signedIn) {
      return;
    }
    final missing = state.where((a) => !owned.contains(a.itemId)).toList();
    if (missing.isEmpty) return;
    _resending = true;
    try {
      for (final a in missing) {
        await ref.read(apiProvider).post('/v1/rewards/${a.name}', const {});
      }
      await ref.read(accountProvider.notifier).sync();
    } on ApiException {
      // Без сети — в следующий раз.
    } finally {
      _resending = false;
    }
  }

  /// Выдать один раз: с аккаунтом — сервер (вещь закрепится за аккаунтом),
  /// без — на телефоне. Без сети — попробуем в следующий раз.
  Future<void> claim(Achievement a) async {
    if (state.contains(a)) return;
    if (ref.read(accountProvider).signedIn) {
      try {
        await ref.read(apiProvider).post('/v1/rewards/${a.name}', const {});
        await ref.read(accountProvider.notifier).sync();
      } on ApiException {
        return;
      }
    } else {
      await ref.read(heroProvider.notifier).grantItems([a.itemId]);
    }
    state = {...state, a};
    await ref.read(prefsProvider).setStringList(_claimedKey, [
      for (final x in state) x.name,
    ]);
    showStatus(
      'Награда: ${a.title} — в инвентаре',
      kind: StatusKind.reward,
      duration: const Duration(seconds: 4),
    );
  }
}

final achievementsProvider =
    NotifierProvider<AchievementsNotifier, Set<Achievement>>(
      AchievementsNotifier.new,
    );
