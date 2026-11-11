import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../avatar/avatar_look.dart';
import '../avatar/avatar_view.dart';
import '../game/body_part.dart';
import '../game/game_config.dart';
import '../game/progression.dart';
import '../game/workout.dart';
import '../state/providers.dart';
import '../state/workout_state.dart';
import '../theme.dart';
import '../widgets/format.dart';

/// Итог тренировки: опыт по частям тела, новые уровни, монеты.
class WorkoutResultScreen extends ConsumerWidget {
  const WorkoutResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(lastSummaryProvider);
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
              xpNow: hero.xp,
            ),
          ),
          const SizedBox(height: 8),
          _Totals(summary: summary),
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

class _ValidityCard extends StatelessWidget {
  const _ValidityCard({required this.summary});

  final WorkoutSummary summary;

  @override
  Widget build(BuildContext context) {
    final verified = summary.isVerified;
    final multiplier = GameConfig.unverifiedValidity.toString().replaceAll(
      '.',
      ',',
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              verified ? LucideIcons.shieldCheck : LucideIcons.watch,
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
                        : 'Без часов: опыт ×$multiplier',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (!verified) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'С часами опыт будет полным, а тренировки пойдут в рейтинговые дуэли',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    return Container(
      height: 52,
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
    required this.xpNow,
  });

  final WorkoutSummary summary;
  final AvatarLook look;
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
