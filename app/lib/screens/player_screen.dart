import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../avatar/avatar_view.dart';
import '../game/body_part.dart';
import '../game/exercise_catalog.dart';
import '../game/game_config.dart';
import '../game/strength.dart';
import '../state/account_state.dart';
import '../state/hero.dart';
import '../state/joint_state.dart';
import '../state/providers.dart';
import '../state/records_state.dart';
import '../theme.dart';
import '../widgets/format.dart';
import '../widgets/sign_up_card.dart';

/// Профиль игрока: герой «было → стало», статистика, уровни силы.
class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hero = ref.watch(heroProvider);
    if (hero == null) return const SizedBox.shrink();
    final records = ref.watch(recordsProvider);
    final days = DateTime.now().difference(hero.createdAt).inDays + 1;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(hero.nickname, overflow: TextOverflow.ellipsis),
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
          IconButton(
            tooltip: 'Настройки и конфиденциальность',
            onPressed: () => context.go('/profile/settings'),
            icon: const Icon(LucideIcons.settings, size: 20),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          _Growth(hero: hero),
          const SizedBox(height: 4),
          Text(
            'С IronRise $days ${_daysWord(days)} · сила ${hero.power}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          _Stats(hero: hero, records: records),
          const SizedBox(height: 16),
          if (!ref.watch(accountProvider).signedIn) ...[
            const SignUpCard(),
            const SizedBox(height: 16),
          ],
          const _Menu(),
          const SizedBox(height: 24),
          _StrengthSection(hero: hero, records: records),
        ],
      ),
    );
  }

  static String _daysWord(int n) {
    final mod10 = n % 10, mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'день';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return 'дня';
    return 'дней';
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
            child: _Figure(label: 'Старт', levels: _firstDay, hero: hero),
          ),
          Expanded(
            child: _Figure(
              label: 'Сейчас',
              levels: hero.avatarLevels,
              hero: hero,
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
    required this.hero,
  });

  final String label;
  final Map<BodyPart, num> levels;
  final HeroProfile hero;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: AvatarView(levels: levels, look: hero.look),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
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
        LucideIcons.users,
        'Друзья',
        account.signedIn
            ? 'Заявки, поиск по нику, кто нападал'
            : 'Нужен аккаунт',
        '/profile/friends',
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
              onTap: () => context.go(path),
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
    return Row(
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
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
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
