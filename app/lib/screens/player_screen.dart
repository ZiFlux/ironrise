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
import '../widgets/info_bubble.dart';
import '../widgets/streak_sheet.dart';
import '../game/hero_milestones.dart';
import '../widgets/status_toast.dart';
import '../game/progression.dart';
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
                onPressed: () => context.push('/profile/settings'),
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
                look: hero.look,
                levels: hero.avatarLevels,
                name: hero.nickname,
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
        // Уровни частей тела списком: опыт до следующего уровня, отстающая и
        // «горящая» части. Кольца есть на главной — здесь подробнее, а не повтор.
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final part in BodyPart.values)
                _PartLevelRow(
                  part: part,
                  xp: hero.xp[part]!,
                  lagging: hero.lagging.contains(part),
                  hot: hot.contains(part),
                  onTap: () => showBodyPartSheet(context, part),
                ),
            ],
          ),
        ),
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
            'Рамка аватарки',
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
                          look: hero?.look,
                          levels: hero?.avatarLevels,
                          name: hero?.nickname,
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
              onTap: () => context.push('/profile/start-look'),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/profile/start-look'),
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
/// Пункт меню: иконка, название, строка состояния, путь; locked — нужен аккаунт.
typedef _MenuItem = (IconData, String, String, String, bool);

/// Меню профиля группами: друзья — награды и вещи — аккаунт и настройки.
/// Без аккаунта сетевые пункты с замком, а не с «Нужен аккаунт» в каждой строке.
class _Menu extends ConsumerWidget {
  const _Menu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider);
    final off = !account.signedIn;
    final joint = ref.watch(jointProvider).value;
    final bonus = '+${(GameConfig.jointBonus * 100).round()}% опыта';
    final premium = ref.watch(heroProvider)?.premium.active ?? false;
    final groups = <(String, List<_MenuItem>)>[
      (
        'Вместе',
        [
          (
            LucideIcons.users,
            'Друзья',
            'Заявки, поиск по нику, кто нападал',
            '/profile/friends',
            off,
          ),
          (
            feedIcon,
            'Лента друзей',
            'Уровни, серии и возвращения друзей',
            '/feed',
            off,
          ),
          (
            LucideIcons.handshake,
            'Тренировка вместе',
            joint?.bonusActive ?? false
                ? 'Идёт: $bonus'
                : '$bonus, если рядом друзья',
            '/workout/joint',
            false,
          ),
        ],
      ),
      (
        'Награды и вещи',
        [
          (
            LucideIcons.sparkles,
            'Сезон',
            'Очки за тренировки и дуэли — награды по уровням',
            '/season',
            off,
          ),
          (
            LucideIcons.shoppingBag,
            'Магазин',
            premium
                ? 'Одежда, аксессуары · премиум'
                : 'Одежда, аксессуары, премиум',
            '/shop',
            false,
          ),
          (
            LucideIcons.shirt,
            'Инвентарь',
            'Твои вещи — надеть и сменить образ',
            '/wardrobe',
            false,
          ),
        ],
      ),
      (
        'Аккаунт и настройки',
        [
          if (account.signedIn)
            (
              LucideIcons.circleUser,
              'Аккаунт',
              account.email!,
              '/profile/account',
              false,
            ),
          (
            LucideIcons.watch,
            'Часы и телефон',
            devicesSummary(ref),
            '/profile/devices',
            false,
          ),
          (
            LucideIcons.settings,
            'Настройки',
            'График, пульс, стиль, данные',
            '/profile/settings',
            false,
          ),
        ],
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (g, (title, items)) in groups.indexed) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(4, g == 0 ? 0 : 20, 4, 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (i, (icon, label, subtitle, path, locked))
                    in items.indexed) ...[
                  if (i > 0) const Divider(height: 1, indent: 56),
                  ListTile(
                    // Вложенные экраны — с возвратом назад, сюда же (п. 135).
                    onTap: () => context.push(path),
                    leading: Icon(
                      icon,
                      size: 20,
                      color: locked
                          ? AppColors.textMuted
                          : Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      label,
                      style: TextStyle(
                        color: locked
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      locked ? 'С аккаунтом' : subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    trailing: Icon(
                      locked ? LucideIcons.lock : LucideIcons.chevronRight,
                      size: locked ? 16 : 18,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.hero, required this.records});

  final HeroProfile hero;
  final TrainingRecords records;

  @override
  Widget build(BuildContext context) {
    // Каждая плитка ведёт туда, где про это подробно (п. 127).
    final tiles = <(String, String, void Function())>[
      (
        'Тренировок',
        '${records.workouts}',
        () => context.push('/workout/stats'),
      ),
      (
        'Подходов',
        formatThousands(records.sets),
        () => context.push('/workout/stats'),
      ),
      ('Серия', '${hero.streakDays}', () => showStreakSheet(context)),
      ('Монеты', formatThousands(hero.coins), () => context.push('/shop')),
    ];
    // Одна высота у всех плиток, даже если подпись где-то переносится.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, (label, value, open)) in tiles.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Tappable(
                radius: 12,
                semantics: '$label: $value',
                onTap: (_) => open(),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
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
    return Tappable(
      radius: 0,
      onTap: (c) => showInfoBubble(
        c,
        title: exercise.name,
        text:
            'Лучший подход: $best${oneRepMax == null ? '' : '. Максимум на один раз — '
                      'около ${formatWeight((oneRepMax * 2).round() / 2)} кг (по формуле, без проверки).'}'
            '${level == null ? '' : ' Уровень «${level!.label}» — по весу относительно твоего веса тела.'}',
        actionLabel: 'Динамика',
        onAction: () => context.push('/workout/stats'),
      ),
      child: Padding(
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
    return Tappable(
      radius: 6,
      onTap: (_) => showBodyPartSheet(context, muscle.part),
      child: Padding(
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
      ),
    );
  }
}

/// Строка уровня части тела: цвет части, уровень, полоса и опыт до следующего.
class _PartLevelRow extends StatelessWidget {
  const _PartLevelRow({
    required this.part,
    required this.xp,
    required this.lagging,
    required this.hot,
    required this.onTap,
  });

  final BodyPart part;
  final int xp;
  final bool lagging;
  final bool hot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final level = Progression.levelFromXp(xp);
    final into = xp % GameConfig.xpPerLevel;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text('$level', style: figureStyle(size: 18)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Одна гибкая подпись (часть, огонёк, «отстаёт») — при крупном
                  // шрифте переносится, а не вылезает за край.
                  Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: part.label,
                            children: [
                              if (hot)
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: Icon(
                                      LucideIcons.flame,
                                      size: 14,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .tertiary,
                                    ),
                                  ),
                                ),
                              if (lagging)
                                const TextSpan(
                                  text: '  отстаёт',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$into / ${GameConfig.xpPerLevel}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: into / GameConfig.xpPerLevel,
                      minHeight: 6,
                      color: part.color,
                      backgroundColor: AppColors.raised,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
