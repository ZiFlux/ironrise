import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/body_part.dart';
import '../game/calendar.dart';
import '../game/streak.dart';
import '../game/workout.dart';
import 'hero.dart';

/// Подменяется в main() уже загруженным экземпляром.
final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('prefsProvider must be overridden'),
);

const _heroKey = 'hero_v1';

/// Герой хранится локально, пока нет сервера.
class HeroNotifier extends Notifier<HeroProfile?> {
  @override
  HeroProfile? build() {
    final raw = ref.read(prefsProvider).getString(_heroKey);
    if (raw == null) return null;
    try {
      return HeroProfile.decode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(HeroProfile hero) async {
    state = hero;
    await ref.read(prefsProvider).setString(_heroKey, hero.encode());
  }

  Future<void> reset() async {
    state = null;
    await ref.read(prefsProvider).remove(_heroKey);
  }

  /// Начислить итог тренировки: опыт, монеты, серия.
  Future<void> applyWorkout(WorkoutSummary summary, DateTime finishedAt) async {
    final h = state;
    if (h == null) return;
    await save(h.copyWith(
      xp: summary.applyTo(h.xp),
      coins: h.coins + summary.coins,
      streakDays: Streak.afterActivity(
        currentStreak: h.streakDays,
        lastActiveDay: h.lastActiveDay,
        today: finishedAt,
        maxRestDays: h.maxRestDays,
      ),
      lastActiveDay: finishedAt,
      activeDays: {...h.activeDays, dayKey(finishedAt)},
    ));
  }

  Future<void> addCoins(int amount) async {
    final h = state;
    if (h == null) return;
    await save(h.copyWith(coins: h.coins + amount));
  }

  /// Только для разработки: начислить опыт части тела.
  Future<void> debugAddXp(BodyPart part, int amount) async {
    final h = state;
    if (h == null) return;
    await save(h.copyWith(xp: {...h.xp, part: h.xp[part]! + amount}));
  }

  /// Только для разработки.
  Future<void> debugSetStreak(int days) async {
    final h = state;
    if (h == null) return;
    await save(h.copyWith(streakDays: days));
  }
}

final heroProvider = NotifierProvider<HeroNotifier, HeroProfile?>(HeroNotifier.new);
