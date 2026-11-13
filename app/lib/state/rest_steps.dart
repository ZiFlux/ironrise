import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/body_part.dart';
import '../game/calendar.dart';
import '../game/game_config.dart';
import '../net/api_client.dart';
import '../widgets/status_toast.dart';
import 'account_state.dart';
import 'health_state.dart';
import 'providers.dart';
import 'training_log.dart';

const _stepsDayKey = 'rest_steps_day_v1';

/// Шаги в день отдыха (PLAN 4.8, п. 3): 3 опыта кардио за тысячу, не больше 30,
/// раз в день, вечером и только без тренировки сегодня. Как на сервере.
int restStepsXp(int steps) => ((steps ~/ 1000) * 3).clamp(0, 30);

/// Вечером при открытии приложения — начислить шаги дня отдыха.
Future<void> maybeClaimRestSteps(WidgetRef ref) async {
  final now = DateTime.now();
  if (now.hour < 18) return;
  final prefs = ref.read(prefsProvider);
  final today = dayKey(now);
  if (prefs.getString(_stepsDayKey) == today) return;
  if (ref.read(trainingLogProvider).any((w) => dayKey(w.at) == today)) return;
  final health = ref.read(healthProvider);
  if (!health.connected) return;
  await ref.read(healthProvider.notifier).refresh();
  final steps = ref.read(healthProvider).stepsToday ?? 0;
  final xp = restStepsXp(steps);
  if (xp <= 0) return;

  if (ref.read(accountProvider).signedIn) {
    try {
      final r = await ref.read(apiProvider).post('/v1/me/steps', {
        'steps': steps,
      });
      await ref
          .read(heroProvider.notifier)
          .applyServer(Map<String, dynamic>.from(r['hero'] as Map));
    } on ApiException {
      // Уже начислено, сегодня была тренировка или нет сети — тихо пропускаем.
      return;
    }
  } else {
    final hero = ref.read(heroProvider);
    if (hero == null) return;
    await ref
        .read(heroProvider.notifier)
        .save(
          hero.copyWith(
            xp: {...hero.xp, BodyPart.cardio: hero.xp[BodyPart.cardio]! + xp},
            coins: hero.coins + (xp * GameConfig.coinsPerXp).round(),
          ),
        );
  }
  await prefs.setString(_stepsDayKey, today);
  showStatus(
    'День отдыха: $steps шагов — +$xp опыта кардио',
    kind: StatusKind.reward,
  );
}
