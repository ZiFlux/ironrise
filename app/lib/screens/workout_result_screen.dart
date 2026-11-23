import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/circuit_rest.dart';
import '../state/rest_state.dart';
import '../avatar/avatar_look.dart';
import '../avatar/avatar_view.dart';
import '../game/anti_fraud.dart';
import '../game/muscles.dart';
import '../game/body_part.dart';
import '../game/game_config.dart';
import '../game/progression.dart';
import '../game/workout.dart';
import '../state/account_state.dart';
import '../state/joint_state.dart';
import '../game/exercise_ladder.dart';
import '../state/program_state.dart';
import '../state/providers.dart';
import '../state/workout_state.dart';
import '../state/training_log.dart';
import '../widgets/info_bubble.dart';
import '../widgets/body_part_sheet.dart';
import '../widgets/streak_sheet.dart';
import '../game/shop.dart';
import '../theme.dart';
import '../widgets/format.dart';
import '../widgets/next_time_card.dart';
import '../widgets/set_effort_card.dart';
import '../widgets/sign_up_card.dart';
import '../widgets/wellbeing_card.dart';

/// Итог тренировки: опыт по частям тела, новые уровни, монеты.
class WorkoutResultScreen extends ConsumerWidget {
  const WorkoutResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(lastSummaryProvider);
    final planResult = ref.watch(lastPlanResultProvider);
    final hero = ref.watch(heroProvider);
    if (summary == null || hero == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/'));
      return const SizedBox.shrink();
    }
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(summary.cardio == null ? 'Итог тренировки' : 'Итог кардио'),
            Text(switch (summary.cardio) {
              null =>
                '${formatMinutes(summary.duration)} · ${summary.totalSets} ${setsWord(summary.totalSets)}',
              final c when summary.isVerified =>
                '${c.activity} · ${formatMinutes(summary.duration)}, в зоне ${c.zoneMinutes} мин',
              final c => '${c.activity} · ${formatMinutes(summary.duration)}',
            }, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          SizedBox(
            height: 260,
            child: _GrowingAvatar(
              summary: summary,
              look: hero.look,
              muscles: hero.muscles,
              xpNow: hero.xp,
            ),
          ),
          const SizedBox(height: 8),
          _Totals(summary: summary),
          if (ref.watch(jointProvider).value case final j?
              when j.bonusActive) ...[
            const SizedBox(height: 16),
            _JointCard(partners: j.partnersOf(hero.nickname)),
          ],
          const SizedBox(height: 16),
          _ValidityCard(summary: summary),
          const SizedBox(height: 16),
          const Text(
            'По частям тела',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          for (final gain in summary.gains)
            _GainRow(gain: gain, maxXp: summary.gains.first.xp),
          for (final m in ref.watch(lastHeroMilestonesProvider)) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Text('🏆', style: TextStyle(fontSize: 28)),
                title: Text('Уровень героя ${m.level}!'),
                subtitle: Text(
                  'Подарок: ${ShopCatalog.byId(m.item).name.toLowerCase()}, '
                  'открыта ${m.perk}',
                ),
              ),
            ),
          ],
          if (ref.watch(lastStreakRewardProvider) case final streak?) ...[
            const SizedBox(height: 16),
            StreakRewardCard(reward: streak),
          ],
          if (ref.watch(lastSetEffortProvider) case final effort?
              when summary.cardio == null) ...[
            const SizedBox(height: 16),
            SetEffortCard(analysis: effort),
          ],
          if (ref.watch(lastCircuitProvider)) ...[
            const SizedBox(height: 16),
            const _CircuitPaceCard(),
          ],
          if (planResult != null && planResult.levelUps.isNotEmpty) ...[
            const SizedBox(height: 16),
            _LevelUpCard(levelUps: planResult.levelUps),
          ],
          if (planResult != null &&
              (planResult.skillsLearned.isNotEmpty ||
                  planResult.skillsRetry.isNotEmpty)) ...[
            const SizedBox(height: 16),
            _SkillCheckCard(
              learned: planResult.skillsLearned,
              retry: planResult.skillsRetry,
            ),
          ],
          if (planResult != null && planResult.changes.isNotEmpty) ...[
            const SizedBox(height: 16),
            NextTimeCard(result: planResult),
          ],
          // Только после силовой: у кардио своё восстановление.
          if (summary.cardio == null) ...[
            const SizedBox(height: 16),
            WellbeingCard(
              exerciseIds: [
                for (final e
                    in ref.watch(trainingLogProvider).firstOrNull?.exercises ??
                        const <LoggedExercise>[])
                  e.id,
              ],
            ),
          ],
          if (!ref.watch(accountProvider).signedIn) ...[
            const SizedBox(height: 16),
            const SignUpCard(compact: true),
          ] else if (ref.watch(accountProvider) case final a
              when a.pending > 0 && !a.syncing) ...[
            // Нет сети в зале — тренировка не потеряна (п. 114).
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  LucideIcons.cloudOff,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Сохранено на телефоне. Отправится само, когда появится сеть '
                    '(в очереди: ${a.pending})',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.go('/'),
            child: const Text('Готово'),
          ),
        ],
      ),
    );
  }
}

/// Тренировка в совместной сессии: бонус считает сервер при синхронизации.
class _JointCard extends StatelessWidget {
  const _JointCard({required this.partners});

  final List<String> partners;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(LucideIcons.users, size: 18, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Вместе с ${partners.join(', ')}: '
                '+${(GameConfig.jointBonus * 100).round()}% опыта и монет. '
                'Бонус начислится после синхронизации с сервером',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.summary});

  final WorkoutSummary summary;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Опыт за тренировку',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: summary.totalXp),
                duration: _growDuration,
                curve: Curves.easeOutCubic,
                builder: (_, v, _) =>
                    Text('+$v', style: figureStyle(size: 40, color: accent)),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'Монеты',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text('+${summary.coins}', style: figureStyle(size: 20)),
          ],
        ),
      ],
    );
  }
}

class _ValidityCard extends ConsumerWidget {
  const _ValidityCard({required this.summary});

  final WorkoutSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verified = summary.isVerified;
    final report = summary.validityReport;
    final waiting = !verified && ref.watch(accountProvider).awaitingWatchPulse;
    final multiplier = GameConfig.unverifiedValidity.toString().replaceAll(
      '.',
      ',',
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Tappable(
        radius: 12,
        onTap: (c) => showInfoBubble(
          c,
          title: 'Как пульс подтверждает тренировку',
          text:
              'Пульс должен подниматься на подходах и спадать на отдыхе, а записан — '
              'хотя бы на ${(GameConfig.minPulseCoverage * 100).round()}% тренировки. '
              'Тогда опыт полный и тренировка идёт в рейтинг. Без пульса опыт ×$multiplier: '
              'так честнее для всех в лиге.',
          actionLabel: 'Подключить часы',
          onAction: () => context.push('/profile/devices'),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                verified
                    ? LucideIcons.shieldCheck
                    : waiting
                    ? LucideIcons.hourglass
                    : LucideIcons.watch,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      verified
                          ? 'Пульс подтверждён часами'
                          : waiting
                          ? 'Ждём пульс с часов'
                          : report == null
                          ? 'Без часов: опыт ×$multiplier'
                          : 'Опыт ×${_decimal(summary.validity)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (!verified)
                      for (final reason
                          in waiting || report == null
                              ? [
                                  waiting
                                      ? 'Часы передают пульс через Samsung Health с задержкой — ждём до 3 часов, опыт пересчитается сам. '
                                            'Чтобы пульса хватило: запускай тренировку и в Samsung Health на часах '
                                            'или включи там постоянное измерение пульса'
                                      : 'С часами опыт будет полным, а тренировки пойдут в рейтинговые дуэли',
                                ]
                              : report.issues.map((i) => _explain(i, report)))
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            reason,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _decimal(double v) => v
    .toStringAsFixed(2)
    .replaceAll(RegExp(r'0+$'), '')
    .replaceAll(RegExp(r'\.$'), '')
    .replaceAll('.', ',');

/// Человеческое объяснение, почему опыт урезан.
String _explain(ValidityIssue issue, ValidityReport report) => switch (issue) {
  ValidityIssue.noPulse =>
    'Пульса нет: подключи часы или датчик, и опыт будет полным',
  ValidityIssue.partialPulse =>
    'Пульс записан только на ${(report.pulseCoverage * 100).round()}% тренировки, нужно от '
        '${(GameConfig.minPulseCoverage * 100).round()}%: часы передавали его не всё время',
  ValidityIssue.lowIntensity =>
    'Пульс почти как в покое: так бывает, если записывать подходы сидя',
  ValidityIssue.flatPulse =>
    'Пульс ровный, без подъёмов на подходах и спадов на отдыхе',
  ValidityIssue.tooFast =>
    'Подходов больше, чем успеть за это время: на подход нужно от ${GameConfig.minTimePerSet.inSeconds} с',
};

class _GainRow extends StatelessWidget {
  const _GainRow({required this.gain, required this.maxXp});

  final PartGain gain;
  final int maxXp;

  String get _note {
    final level = gain.leveledUp
        ? 'Уровень ${gain.levelBefore} → ${gain.levelAfter}'
        : 'Уровень ${gain.levelAfter} · ${gain.progressInLevel} из ${GameConfig.xpPerLevel}';
    return gain.wasLagging ? '$level · опыт ×1,5' : level;
  }

  @override
  Widget build(BuildContext context) {
    final highlight = gain.leveledUp || gain.wasLagging;
    return Tappable(
      radius: 0,
      onTap: (_) => showBodyPartSheet(context, gain.part),
      child: _row(context, highlight),
    );
  }

  Widget _row(BuildContext context, bool highlight) {
    return Container(
      // Подпись про уровень может перенестись — строка растёт, а не обрезается.
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: gain.part.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 64,
            child: Text(gain.part.label, style: const TextStyle(fontSize: 14)),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: gain.xp / maxXp),
                    duration: AppMotion.enter,
                    curve: AppMotion.curve,
                    builder: (_, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 4,
                      color: gain.part.color,
                      backgroundColor: AppColors.raised,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _note,
                  style: TextStyle(
                    fontSize: 12,
                    color: highlight
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              '+${gain.xp}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

extension on PartGain {
  /// Опыт внутри текущего уровня после тренировки.
  int get progressInLevel =>
      xpAfter - (Progression.levelFromXp(xpAfter) - 1) * GameConfig.xpPerLevel;
}

const _growDuration = Duration(milliseconds: 1600);

/// Аватар плавно дорастает от «до тренировки» к «после», затем — плашка новых уровней.
class _GrowingAvatar extends StatefulWidget {
  const _GrowingAvatar({
    required this.summary,
    required this.look,
    required this.muscles,
    required this.xpNow,
  });

  final WorkoutSummary summary;
  final AvatarLook look;
  final MusclePoints muscles;
  final Map<BodyPart, int> xpNow;

  @override
  State<_GrowingAvatar> createState() => _GrowingAvatarState();
}

class _GrowingAvatarState extends State<_GrowingAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _growDuration,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Curves.easeInOutCubic,
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Map<BodyPart, double> _levelsAt(double t) {
    final gained = {for (final g in widget.summary.gains) g.part: g};
    return {
      for (final p in BodyPart.values)
        p: switch (gained[p]) {
          null => Progression.fractionalLevel(widget.xpNow[p] ?? 0),
          final g =>
            Progression.fractionalLevel(g.xpAfter - g.xp) +
                g.xp * t / GameConfig.xpPerLevel,
        },
    };
  }

  @override
  Widget build(BuildContext context) {
    final levelUps = [
      for (final g in widget.summary.gains)
        if (g.leveledUp) g,
    ];
    final accent = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) => Stack(
        fit: StackFit.expand,
        children: [
          AvatarView(
            levels: _levelsAt(_t.value),
            look: widget.look,
            muscles: widget.muscles,
            withLamp: true,
          ),
          if (levelUps.isNotEmpty)
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedOpacity(
                opacity: _c.isCompleted ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                child: AnimatedScale(
                  scale: _c.isCompleted ? 1 : 0.8,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Новый уровень: ${levelUps.map((g) => '${g.part.label.toLowerCase()} ${g.levelAfter}').join(', ')}',
                      style: const TextStyle(
                        color: AppColors.onAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Освоил упражнение — со следующей тренировки вариант сложнее.
class _LevelUpCard extends StatelessWidget {
  const _LevelUpCard({required this.levelUps});

  final List<LevelUp> levelUps;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.trendingUp, size: 20, color: accent),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Новая ступень',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Результат хороший для твоей комплекции — дальше вариант сложнее',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            for (final l in levelUps)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${l.from} → ${l.to}',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Проверка отработки через две недели (skill_practice.dart).
class _SkillCheckCard extends StatelessWidget {
  const _SkillCheckCard({required this.learned, required this.retry});

  final List<String> learned;
  final List<String> retry;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.graduationCap, size: 20, color: accent),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Проверка отработки',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            for (final name in learned)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '$name — получается! Упражнение снова в плане как обычное.',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            for (final name in retry)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '$name — пока не выходит. Ещё две недели замены и подводящих, '
                  'потом проверим снова.',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// «Каким был темп кардио?» — по ответу отдых между кардио-упражнениями
/// становится длиннее или постепенно короче (не меньше 30 с).
class _CircuitPaceCard extends ConsumerStatefulWidget {
  const _CircuitPaceCard();

  @override
  ConsumerState<_CircuitPaceCard> createState() => _CircuitPaceCardState();
}

class _CircuitPaceCardState extends ConsumerState<_CircuitPaceCard> {
  String? _answer;

  @override
  Widget build(BuildContext context) {
    final rest = ref.read(circuitRestProvider.notifier).current();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Каким был темп кардио?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              _answer ??
                  'Отдых между кардио-упражнениями сейчас ${rest.seconds} с. '
                      'По ответу подстроим его к следующей тренировке.',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            if (_answer == null) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final pace in CircuitPace.values)
                    ActionChip(
                      label: Text(pace.label),
                      onPressed: () async {
                        final before = rest.seconds;
                        final next = await ref
                            .read(circuitRestProvider.notifier)
                            .answer(pace);
                        if (!mounted) return;
                        setState(
                          () => _answer = next.seconds > before
                              ? 'Отдых между кардио-упражнениями — ${next.seconds} с: '
                                    'дадим отдышаться.'
                              : next.seconds < before
                              ? 'Отдых между кардио-упражнениями — ${next.seconds} с: '
                                    'темп чуть выше.'
                              : next.seconds <= CircuitRest.minSeconds
                              ? 'Отдых уже минимальный — ${next.seconds} с. '
                                    'Дальше растут темп и число повторов.'
                              : 'Оставляем ${next.seconds} с. Ещё одна такая '
                                    'тренировка — и сократим отдых на 5 с.',
                        );
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
