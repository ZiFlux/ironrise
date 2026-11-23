import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../avatar/avatar_look.dart';
import '../game/body_part.dart';
import '../game/calendar.dart';
import '../game/muscles.dart';
import '../game/shop.dart';
import '../game/streak.dart';
import '../game/streak_rewards.dart';
import '../game/hero_milestones.dart';
import '../game/progression.dart';
import '../game/workout.dart';
import '../game/schedule.dart';
import '../game/training_format.dart';
import 'hero.dart';
import 'showcase_state.dart';

/// Подменяется в main() уже загруженным экземпляром.
final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('prefsProvider must be overridden'),
);

const _heroKey = 'hero_v1';

/// Герой хранится локально, пока нет сервера.
/// Цели менялись на телефоне и ещё не ушли на сервер (state/goals_state.dart).
const goalsDirtyKey = 'goals_dirty';

class HeroNotifier extends Notifier<HeroProfile?> {
  @override
  HeroProfile? build() {
    final raw = ref.read(prefsProvider).getString(_heroKey);
    if (raw == null) return null;
    try {
      return _lockStartIfExpired(HeroProfile.decode(raw));
    } catch (_) {
      return null;
    }
  }

  /// Без аккаунта окно закрывается на телефоне; с аккаунтом то же сделает сервер.
  HeroProfile _lockStartIfExpired(HeroProfile h) {
    if (h.startLook != null || h.startLookOpen(DateTime.now())) return h;
    return _withLockedStart(h, h.look);
  }

  static HeroProfile _withLockedStart(HeroProfile h, AvatarLook look) =>
      h.copyWith(
        look: look,
        startLook: look,
        startLocked: true,
        ownedItems: {
          ...h.ownedItems,
          for (final i in ShopCatalog.creatorGrant(look, h.ownedItems)) i.id,
        },
      );

  /// Стартовый образ без аккаунта: lock — зафиксировать как «Старт» досрочно.
  Future<void> saveStartLook(AvatarLook look, {required bool lock}) async {
    final h = state;
    if (h == null || !h.startLookOpen(DateTime.now())) return;
    await save(lock ? _withLockedStart(h, look) : h.copyWith(look: look));
  }

  Future<void> save(HeroProfile hero) async {
    // Синхронизация каждые 5 минут обычно приносит то же самое: без изменений
    // не трогаем состояние — иначе перестраивались бы все вкладки с аватарами.
    final encoded = hero.encode();
    final current = state;
    if (current != null && encoded == (_encoded ??= current.encode())) return;
    _encoded = encoded;
    state = hero;
    await ref.read(prefsProvider).setString(_heroKey, encoded);
  }

  /// Последнее сохранённое состояние в JSON — для сравнения без пересборки.
  String? _encoded;

  Future<void> reset() async {
    state = null;
    await ref.read(prefsProvider).remove(_heroKey);
  }

  /// Начислить итог тренировки: опыт, монеты, серия.
  /// muscles — очки мышц силовой тренировки (MuscleMath.pointsOf), у кардио пусто.
  /// Тренировка: опыт, монеты, серия, бустеры. Возвращает награду за серию, если
  /// серия выросла. [grantStreak] — выдать её здесь (без аккаунта); с аккаунтом
  /// её выдаёт сервер, а синхронизация приносит итог.
  Future<StreakReward?> applyWorkout(
    WorkoutSummary summary,
    DateTime finishedAt, {
    MusclePoints muscles = const {},
    bool usedBoosters = false,
    bool grantStreak = true,
  }) async {
    final h = state;
    if (h == null) return null;
    final after = Streak.afterActivity(
      currentStreak: h.streakDays,
      lastActiveDay: h.lastActiveDay,
      today: finishedAt,
      maxRestDays: h.maxRestDays,
    );
    // Сгоревшая серия начинается заново: награды — с первого дня.
    final before = h.currentStreak(finishedAt);
    final reward = streakReward(before, after);
    var xp = summary.applyTo(h.xp);
    var coins = h.coins + summary.coins;
    var owned = h.ownedItems;
    var boosters = usedBoosters ? h.boosters.afterUse : h.boosters;
    if (reward != null && grantStreak) {
      coins += reward.coins;
      owned = {...owned, ...reward.items};
      boosters = boosters + reward.boosters;
      if (reward.xp > 0) {
        // Опыт за рубеж — самой отстающей части, как на сервере.
        final weakest = xp.entries
            .reduce((a, b) => b.value < a.value ? b : a)
            .key;
        xp = {...xp, weakest: xp[weakest]! + reward.xp};
      }
    }
    // Вехи героя: средний уровень 5/10/20 — подарок (без аккаунта выдаём здесь).
    final milestones = heroMilestonesBetween(
      heroLevel(Progression.levels(h.xp)),
      heroLevel(Progression.levels(xp)),
    );
    ref.read(lastHeroMilestonesProvider.notifier).show(milestones);
    if (grantStreak) owned = {...owned, for (final m in milestones) m.item};
    await save(
      h.copyWith(
        muscles: MuscleMath.add(h.muscles, muscles),
        xp: xp,
        coins: coins,
        ownedItems: owned,
        boosters: boosters,
        streakDays: after,
        lastActiveDay: finishedAt,
        activeDays: {...h.activeDays, dayKey(finishedAt)},
      ),
    );
    return reward;
  }

  Future<void> addCoins(int amount) async {
    final h = state;
    if (h == null) return;
    await save(h.copyWith(coins: h.coins + amount));
  }

  /// Купить примеренные вещи и надеть образ. false — не хватает монет.
  Future<bool> buyAndWear(List<ShopItem> items, AvatarLook look) async {
    final h = state;
    if (h == null) return false;
    final toBuy = items.where((i) => !i.isFree && !h.ownedItems.contains(i.id));
    final total = toBuy.fold<int>(0, (sum, i) => sum + i.price);
    if (h.coins < total) return false;
    await save(
      h.copyWith(
        coins: h.coins - total,
        ownedItems: {...h.ownedItems, ...toBuy.map((i) => i.id)},
        look: look,
      ),
    );
    return true;
  }

  Future<void> setLook(AvatarLook look) async {
    final h = state;
    if (h == null) return;
    await save(h.copyWith(look: look));
  }

  /// Состояние с сервера — источник правды для опыта, серии, монет и покупок.
  Future<void> applyServer(Map<String, dynamic> me) async {
    final h = state;
    if (h == null) return;
    if (me['showcase'] is Map) {
      await ref
          .read(showcaseProvider.notifier)
          .applyServer(Map<String, dynamic>.from(me['showcase'] as Map));
    }
    AvatarLook? look;
    try {
      look = AvatarLook.fromJson(
        Map<String, dynamic>.from(me['appearance'] as Map),
      );
    } catch (_) {
      look = null; // старый или неполный образ на сервере — оставляем свой
    }
    AvatarLook? startLook;
    if (me['startAppearance'] is Map) {
      try {
        startLook = AvatarLook.fromJson(
          Map<String, dynamic>.from(me['startAppearance'] as Map),
        );
      } catch (_) {}
    }
    final startUntil = me['startLookUntil'] as String?;
    final xp = Map<String, dynamic>.from(me['xp'] as Map);
    final last = me['lastActiveDay'] as String?;
    final lastDay = last == null ? null : DateTime.parse(last);
    await save(
      h.copyWith(
        xp: {
          for (final p in BodyPart.values)
            p: (xp[p.name] as num?)?.toInt() ?? 0,
        },
        streakDays: (me['streakDays'] as num).toInt(),
        lastActiveDay: lastDay,
        activeDays: {...h.activeDays, if (lastDay != null) dayKey(lastDay)},
        coins: (me['coins'] as num).toInt(),
        boosters: me['boosters'] is Map
            ? Boosters.fromJson(
                Map<String, dynamic>.from(me['boosters'] as Map),
              )
            : null,
        ownedItems: Set<String>.from(me['ownedItems'] as List? ?? const []),
        premium: PremiumInfo.fromJson(
          (me['premium'] as Map?)?.cast<String, dynamic>(),
        ),
        look: look,
        // Ник — с сервера: он там уникален, а здесь мог остаться от сброса героя.
        nickname: me['nickname'] as String?,
        // Цели — с сервера, если на телефоне нет неотправленной правки (п. 100).
        goal: ref.read(prefsProvider).getBool(goalsDirtyKey) ?? false
            ? null
            : Goal.values.asNameMap()[me['goal']],
        extraGoals: ref.read(prefsProvider).getBool(goalsDirtyKey) ?? false
            ? null
            : [
                for (final g in (me['goals'] as List? ?? const []))
                  ?Goal.values.asNameMap()[g],
              ],
        nextNicknameChangeAt: me['nextNicknameChangeAt'] == null
            ? null
            : DateTime.parse(me['nextNicknameChangeAt'] as String).toLocal(),
        nicknameChangeAllowed: me['nextNicknameChangeAt'] == null,
        // График тоже с сервера: его могли сменить на другом телефоне.
        format: TrainingFormat.values.asNameMap()[me['trainingFormat']],
        trainingDays: (me['scheduleDays'] as List?)?.cast<int>(),
        nextScheduleChangeAt: me['nextScheduleChangeAt'] == null
            ? null
            : DateTime.parse(me['nextScheduleChangeAt'] as String).toLocal(),
        scheduleChangeAllowed: me['nextScheduleChangeAt'] == null,
        startLook: startLook,
        startLookUntil: startUntil == null
            ? null
            : DateTime.parse(startUntil).toLocal(),
        startLocked: startUntil == null && startLook != null,
        // Старый сервер мышцы не присылает — тогда остаются свои.
        muscles: me['muscles'] is Map
            ? MuscleMath.fromJson(
                Map<String, dynamic>.from(me['muscles'] as Map),
              )
            : null,
      ),
    );
  }

  /// Без аккаунта ник только на телефоне: меняется свободно.
  Future<void> renameLocally(String nickname) async {
    final h = state;
    if (h == null) return;
    await save(h.copyWith(nickname: nickname));
  }

  /// Сменить график без аккаунта: раз в 7 дней, первая смена — сразу.
  Future<void> changeScheduleLocally(
    TrainingFormat format,
    List<int> days,
  ) async {
    final h = state;
    if (h == null ||
        !canChangeSchedule(h.nextScheduleChangeAt, DateTime.now())) {
      return;
    }
    await save(
      h.copyWith(
        format: format,
        trainingDays: [...days]..sort(),
        nextScheduleChangeAt: DateTime.now().add(scheduleChangeCooldown),
      ),
    );
  }

  /// Выдать вещи без аккаунта (награды за достижения): на телефоне.
  Future<void> grantItems(Iterable<String> ids) async {
    final h = state;
    if (h == null) return;
    await save(h.copyWith(ownedItems: {...h.ownedItems, ...ids}));
  }

  Future<void> setBody(BodyStats body) async {
    final h = state;
    if (h == null) return;
    await save(h.copyWith(body: body));
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

final heroProvider = NotifierProvider<HeroNotifier, HeroProfile?>(
  HeroNotifier.new,
);

/// Награда за серию после последней тренировки — для экрана итогов.
class LastStreakRewardNotifier extends Notifier<StreakReward?> {
  @override
  StreakReward? build() => null;

  void show(StreakReward? reward) => state = reward;
}

final lastStreakRewardProvider =
    NotifierProvider<LastStreakRewardNotifier, StreakReward?>(
      LastStreakRewardNotifier.new,
    );

/// Вехи героя после последней тренировки — для экрана итогов.
class LastHeroMilestonesNotifier extends Notifier<List<HeroMilestone>> {
  @override
  List<HeroMilestone> build() => const [];

  void show(List<HeroMilestone> m) => state = m;
}

final lastHeroMilestonesProvider =
    NotifierProvider<LastHeroMilestonesNotifier, List<HeroMilestone>>(
      LastHeroMilestonesNotifier.new,
    );
