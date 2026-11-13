import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../avatar/avatar_look.dart';
import '../avatar/avatar_view.dart';
import '../game/body_part.dart';
import '../game/muscles.dart';
import '../game/exercise_catalog.dart';
import '../game/game_config.dart';
import '../game/strength.dart';
import '../state/account_state.dart';
import '../state/hero.dart';
import '../state/joint_state.dart';
import '../state/providers.dart';
import '../state/records_state.dart';
import '../avatar/body_frame.dart';
import '../avatar/posing_avatar.dart';
import '../game/avatar_icons.dart';
import '../game/training_stats.dart';
import '../state/showcase_state.dart';
import '../state/training_log.dart';
import '../widgets/body_part_sheet.dart';
import '../widgets/level_plate.dart';
import '../game/hero_milestones.dart';
import '../widgets/status_toast.dart';
import '../theme.dart';
import '../widgets/format.dart';
import '../widgets/shop_entry.dart';
import 'devices_screen.dart';
import 'feed_screen.dart' show feedIcon;
import '../widgets/sign_up_card.dart';
import '../widgets/guide.dart';

/// Профиль игрока: герой «было → стало», статистика, уровни силы.
class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hero = ref.watch(heroProvider);
    if (hero == null) return const SizedBox.shrink();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Flexible(
                child: Text('Профиль', overflow: TextOverflow.ellipsis),
              ),
              if (hero.premium.active) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: hero.premium.isTester
                      ? 'Премиум бета-тестера'
                      : 'Премиум',
                  child: const Icon(
                    LucideIcons.crown,
                    size: 18,
                    color: Color(0xFFD9B25A),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            GuideTarget(
              id: 'profile.showcase',
              child: IconButton(
                tooltip: 'Настроить витрину',
                onPressed: () => showShowcaseEditor(context),
                icon: const Icon(LucideIcons.palette, size: 20),
              ),
            ),
            GuideTarget(
              id: 'profile.settings',
              child: IconButton(
                tooltip: 'Настройки и конфиденциальность',
                onPressed: () => context.go('/profile/settings'),
                icon: const Icon(LucideIcons.settings, size: 20),
              ),
            ),
            const SizedBox(width: 8),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Витрина'),
              Tab(text: 'Меню'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _Showcase(hero: hero),
            _MenuTab(hero: hero),
          ],
        ),
      ),
    );
  }

  static String daysWord(int n) {
    final mod10 = n % 10, mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'день';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return 'дня';
    return 'дней';
  }
}

/// Витрина: аватарка, герой в выбранной позе, значки силы, статистика, мышцы.
class _Showcase extends ConsumerWidget {
  const _Showcase({required this.hero});

  final HeroProfile hero;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showcase = ref.watch(showcaseProvider);
    final records = ref.watch(recordsProvider);
    final log = ref.watch(trainingLogProvider);
    final now = DateTime.now();
    final days = now.difference(hero.createdAt).inDays + 1;
    final hot = hotParts(log, now, muscles: hero.muscles);
    final pose = showcase.pose;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => showShowcaseEditor(context),
              child: AvatarBadge(
                iconId: showcase.icon,
                background: showcase.background,
                size: 64,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hero.nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'сила ${hero.power} · серия ${hero.currentStreak(now)} · '
                    'с IronRise $days ${PlayerScreen.daysWord(days)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 300,
          child: pose == null
              ? PosingAvatar(
                  levels: hero.avatarLevels,
                  look: hero.look,
                  muscles: hero.muscles,
                  focus: recentMuscles(log, now),
                  withLamp: true,
                )
              : AvatarView(
                  levels: hero.avatarLevels,
                  look: hero.look,
                  muscles: hero.muscles,
                  withLamp: true,
                  pose: pose,
                  poseT: 1,
                ),
        ),
        const SizedBox(height: 12),
        // Значки силы: огонёк у того, что качается чаще всего.
        for (final row in [
          BodyPart.values.take(3),
          BodyPart.values.skip(3),
        ]) ...[
          Row(
            children: [
              for (final (i, part) in row.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: LevelPlate(
                    part: part,
                    xp: hero.xp[part]!,
                    lagging: hero.lagging.contains(part),
                    hot: hot.contains(part),
                    onTap: () => showBodyPartSheet(context, part),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 20),
        _Stats(hero: hero, records: records),
        const SizedBox(height: 24),
        _StrengthSection(hero: hero, records: records),
        const SizedBox(height: 24),
        _MuscleSection(
          hero: hero,
          hot: hotMuscles(log, now, muscles: hero.muscles),
        ),
      ],
    );
  }
}

/// Меню: «было → стало», аккаунт, премиум и все разделы, что раньше были в профиле.
class _MenuTab extends ConsumerWidget {
  const _MenuTab({required this.hero});

  final HeroProfile hero;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
    children: [
      _Growth(hero: hero),
      if (hero.startLookOpen(DateTime.now())) ...[
        const SizedBox(height: 8),
        _StartLookCard(hero: hero),
      ],
      const SizedBox(height: 16),
      if (!ref.watch(accountProvider).signedIn) ...[
        const SignUpCard(),
        const SizedBox(height: 16),
      ],
      const PremiumBanner(),
      const SizedBox(height: 12),
      const _Menu(),
    ],
  );
}

/// Настроить витрину: аватарка, фон и поза героя.
Future<void> showShowcaseEditor(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.3,
        maxChildSize: 0.92,
        // Тянется вниз за полоску и за содержимое, когда список вверху.
        builder: (_, scroll) => _ShowcaseEditor(scroll: scroll),
      ),
    );

class _ShowcaseEditor extends ConsumerWidget {
  const _ShowcaseEditor({required this.scroll});

  final ScrollController scroll;

  static const _poses = <(AvatarPose?, String)>[
    (null, 'Сам меняет'),
    (AvatarPose.relaxed, 'Стойка'),
    (AvatarPose.doubleBiceps, 'Двойной бицепс'),
    (AvatarPose.latSpread, 'Широчайшие'),
    (AvatarPose.handsBehindHead, 'Руки за головой'),
    (AvatarPose.victory, 'Победа'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showcase = ref.watch(showcaseProvider);
    final notifier = ref.read(showcaseProvider.notifier);
    final hero = ref.watch(heroProvider);
    final level = hero == null ? 0 : heroLevel(hero.levels);
    final workouts = ref.watch(recordsProvider).workouts;
    bool open(AvatarIcon icon) => icon.unlockedFor(
      heroLevel: level,
      streak: hero?.currentStreak(DateTime.now()) ?? 0,
      workouts: workouts,
    );
    return SafeArea(
      child: ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Витрина',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500),
                ),
              ),
              IconButton(
                tooltip: 'Закрыть',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(LucideIcons.x, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Аватарка',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final icon in avatarIcons)
                Tooltip(
                  message: icon.label,
                  child: GestureDetector(
                    onTap: () => !open(icon)
                        ? showStatus(
                            'Откроется за достижение: ${icon.unlockText}',
                          )
                        : notifier.save(showcase.copyWith(icon: icon.id)),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: showcase.icon == icon.id
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Opacity(
                        opacity: open(icon) ? 1 : 0.35,
                        child: AvatarBadge(
                          iconId: icon.id,
                          background: showcase.background,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Фон',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: [
              for (final (i, color) in avatarBackgrounds.indexed)
                GestureDetector(
                  onTap: () => notifier.save(showcase.copyWith(background: i)),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: showcase.background == i
                            ? Theme.of(context).colorScheme.primary
                            : AppColors.hairline,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Поза героя на витрине',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (pose, label) in _poses)
                ChoiceChip(
                  label: Text(
                    pose == AvatarPose.victory && level < victoryPoseLevel
                        ? '$label · ур. $victoryPoseLevel'
                        : label,
                  ),
                  selected: showcase.pose == pose,
                  showCheckmark: false,
                  onSelected:
                      pose == AvatarPose.victory && level < victoryPoseLevel
                      ? null
                      : (_) => notifier.save(
                          showcase.copyWith(pose: pose, autoPose: pose == null),
                        ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Витрину видят друзья. «Сам меняет» — герой встаёт в позы своих '
            'сильных мышц. Выбор сохраняется сразу',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Готово'),
          ),
        ],
      ),
    );
  }
}

/// Герой в первый день рядом с сегодняшним — главный «момент» экрана.
class _Growth extends StatelessWidget {
  const _Growth({required this.hero});

  final HeroProfile hero;

  static final _firstDay = {for (final p in BodyPart.values) p: 1};

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: Row(
        children: [
          Expanded(
            child: _Figure(
              label: 'Старт',
              levels: _firstDay,
              look: hero.firstDayLook,
              onTap: () => context.go('/profile/start-look'),
            ),
          ),
          Expanded(
            child: _Figure(
              label: 'Сейчас',
              levels: hero.avatarLevels,
              look: hero.look,
              muscles: hero.muscles,
            ),
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.levels,
    required this.look,
    this.muscles = const {},
    this.onTap,
  });

  final String label;
  final Map<BodyPart, num> levels;
  final AvatarLook look;
  final MusclePoints muscles;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final figure = Column(
      children: [
        Expanded(
          child: AvatarView(levels: levels, look: look, muscles: muscles),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
    return onTap == null
        ? figure
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: figure,
          );
  }
}

/// Первые 14 дней: позвать собрать себя, пока «Старт» не зафиксирован.
class _StartLookCard extends StatelessWidget {
  const _StartLookCard({required this.hero});

  final HeroProfile hero;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final days = (hero.startLookUntil!.difference(DateTime.now()).inHours / 24)
        .ceil();
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.hairline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/profile/start-look'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              Icon(LucideIcons.personStanding, color: accent, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Собери себя на старте',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Телосложение, причёска и одежда бесплатно\n'
                      'Осталось дней: $days',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Разделы профиля: аккаунт, друзья, совместная тренировка, гардероб, настройки.
class _Menu extends ConsumerWidget {
  const _Menu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider);
    final joint = ref.watch(jointProvider).value;
    final items = [
      (
        LucideIcons.circleUser,
        'Аккаунт',
        account.signedIn
            ? account.email!
            : 'Не создан — прогресс только на телефоне',
        '/profile/account',
      ),
      (
        LucideIcons.watch,
        'Часы и телефон',
        devicesSummary(ref),
        '/profile/devices',
      ),
      (
        LucideIcons.users,
        'Друзья',
        account.signedIn
            ? 'Заявки, поиск по нику, кто нападал'
            : 'Нужен аккаунт',
        '/profile/friends',
      ),
      (
        feedIcon,
        'Лента друзей',
        account.signedIn
            ? 'Уровни, серии и возвращения друзей'
            : 'Нужен аккаунт',
        '/feed',
      ),
      (
        LucideIcons.handshake,
        'Тренировка вместе',
        joint?.bonusActive ?? false
            ? 'Идёт: +${(GameConfig.jointBonus * 100).round()}% опыта'
            : '+${(GameConfig.jointBonus * 100).round()}% опыта, если рядом друзья',
        '/workout/joint',
      ),
      (
        LucideIcons.shoppingBag,
        'Магазин',
        (ref.watch(heroProvider)?.premium.active ?? false)
            ? 'Одежда, аксессуары · премиум активен'
            : 'Одежда, аксессуары, премиум',
        '/shop',
      ),
      (
        LucideIcons.shirt,
        'Инвентарь',
        'Ваши вещи — надеть и сменить образ',
        '/wardrobe',
      ),
      (
        LucideIcons.settings,
        'Настройки',
        'График, часы, пульс, данные',
        '/profile/settings',
      ),
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (i, (icon, title, subtitle, path)) in items.indexed) ...[
            if (i > 0) const Divider(height: 1, indent: 56),
            ListTile(
              // Лента — поверх вкладок, с возвратом назад.
              onTap: () =>
                  path == '/feed' ? context.push(path) : context.go(path),
              leading: Icon(icon, size: 20),
              title: Text(title),
              subtitle: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              trailing: const Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.hero, required this.records});

  final HeroProfile hero;
  final TrainingRecords records;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      ('Тренировок', '${records.workouts}'),
      ('Подходов', formatThousands(records.sets)),
      ('Серия', '${hero.streakDays}'),
      ('Монеты', formatThousands(hero.coins)),
    ];
    // Одна высота у всех плиток, даже если подпись где-то переносится.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, (label, value)) in tiles.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Column(
                  children: [
                    Text(value, style: figureStyle(size: 17)),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StrengthSection extends StatelessWidget {
  const _StrengthSection({required this.hero, required this.records});

  final HeroProfile hero;
  final TrainingRecords records;

  bool get _female =>
      hero.body.sex == Sex.female ||
      (hero.body.sex == null && hero.look.isFemale);

  StrengthLevel? _levelOf(String exerciseId, BestLift lift) {
    if (StrengthStandards.usesReps(exerciseId)) {
      return StrengthStandards.byReps(exerciseId, lift.reps, female: _female);
    }
    final oneRepMax = lift.oneRepMax;
    if (oneRepMax == null) return null;
    return StrengthStandards.byOneRepMax(
      exerciseId,
      oneRepMax,
      hero.body.weightKg,
      female: _female,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final id in StrengthStandards.exercises)
        if (records.best[id] case final lift?)
          (id: id, lift: lift, level: _levelOf(id, lift)),
    ];
    final overall = StrengthStandards.overall(
      rows.map((r) => r.level).nonNulls,
    );
    final noWeight = hero.body.weightKg == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Сила',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
              ),
            ),
            if (overall != null)
              Text(
                overall.label,
                style: figureStyle(
                  size: 15,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          const Text(
            'Сделай присед, жим лёжа, тягу верхнего блока, отжимания или подтягивания — '
            'здесь появится твой уровень силы',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          )
        else
          Card(
            child: Column(
              children: [
                for (final (i, row) in rows.indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  _LiftRow(
                    exerciseId: row.id,
                    lift: row.lift,
                    level: row.level,
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 8),
        Text(
          noWeight
              ? 'Укажи свой вес в профиле, чтобы сравнить силу с нормативами'
              : 'Уровень — по лучшему подходу относительно веса тела. Нормативы предварительные',
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _LiftRow extends StatelessWidget {
  const _LiftRow({
    required this.exerciseId,
    required this.lift,
    required this.level,
  });

  final String exerciseId;
  final BestLift lift;
  final StrengthLevel? level;

  @override
  Widget build(BuildContext context) {
    final exercise = ExerciseCatalog.byId(exerciseId);
    final best = lift.weight > 0
        ? '${formatWeight(lift.weight)} кг × ${lift.reps}'
        : '${lift.reps} повт.';
    final oneRepMax = lift.oneRepMax;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exercise.name, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  oneRepMax == null
                      ? 'Лучший: $best'
                      : 'Лучший: $best · максимум ≈ ${formatWeight((oneRepMax * 2).round() / 2)} кг',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            level?.label ?? '—',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

/// Мышцы: какие впереди, какие отстают, и шуточная гротескная мышца.
class _MuscleSection extends StatelessWidget {
  const _MuscleSection({required this.hero, this.hot = const {}});

  final HeroProfile hero;

  /// Что качается чаще всего за две недели — помечаем огоньком.
  final Set<Muscle> hot;

  @override
  Widget build(BuildContext context) {
    final points = hero.muscles;
    final total = points.values.fold<double>(0, (a, b) => a + b);
    final balance = MuscleMath.balance(points);
    final grotesque = MuscleMath.grotesque(points);
    final accent = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Мышцы',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        if (total == 0)
          const Text(
            'После силовых тренировок здесь будет видно, какие мышцы растут '
            'быстрее, а какие отстают. Аватар меняется так же.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          )
        else ...[
          if (grotesque != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.bicepsFlexed, color: accent, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      grotesqueJoke(grotesque),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Column(
                children: [
                  for (final part in BodyPart.values)
                    for (final m in Muscle.values.where((m) => m.part == part))
                      _MuscleRow(
                        muscle: m,
                        balance: balance[m]!,
                        grotesque: m == grotesque,
                        hot: hot.contains(m),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Считается по подходам: чем чаще мышца в работе, тем она крупнее на '
            'аватаре. Нажми на упражнение в справочнике — там его целевые мышцы.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}

class _MuscleRow extends StatelessWidget {
  const _MuscleRow({
    required this.muscle,
    required this.balance,
    required this.grotesque,
    this.hot = false,
  });

  final Muscle muscle;
  final double balance;
  final bool grotesque;
  final bool hot;

  @override
  Widget build(BuildContext context) {
    final (tag, color) = grotesque
        ? ('гротеск', Theme.of(context).colorScheme.primary)
        : balance > 1.12
        ? ('впереди', muscle.part.color)
        : balance < 0.9
        ? ('отстаёт', const Color(0xFFFFB547))
        : ('ровно', AppColors.textMuted);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    muscle.label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                if (hot) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    LucideIcons.flame,
                    size: 14,
                    color: Color(0xFFFF8A3D),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: ((balance - 0.6) / 0.9).clamp(0.05, 1.0),
                minHeight: 6,
                color: muscle.part.color,
                backgroundColor: AppColors.raised,
              ),
            ),
          ),
          SizedBox(
            width: 76,
            child: Text(
              tag,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 13, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
