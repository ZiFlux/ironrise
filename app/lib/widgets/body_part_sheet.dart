import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/body_part.dart';
import '../game/exercise_catalog.dart';
import '../game/game_config.dart';
import '../game/muscles.dart';
import '../game/program.dart';
import '../game/progression.dart';
import '../game/tips.dart';
import '../game/training_stats.dart';
import '../state/program_state.dart';
import '../state/providers.dart';
import '../state/training_log.dart';
import '../theme.dart';
import 'exercise_picker.dart';

/// Меню части тела поверх экрана (размытый фон, «закрыть»): уровень, мышцы,
/// какие упражнения лучше всего её прокачали и что делать дальше.
Future<void> showBodyPartSheet(BuildContext context, BodyPart part) =>
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Закрыть',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => _BodyPartMenu(part: part),
      transitionBuilder: (context, anim, _, child) {
        final t = Curves.easeOutCubic.transform(anim.value);
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12 * t, sigmaY: 12 * t),
          child: Opacity(
            opacity: t,
            child: Transform.scale(scale: 0.96 + 0.04 * t, child: child),
          ),
        );
      },
    );

class _BodyPartMenu extends ConsumerWidget {
  const _BodyPartMenu({required this.part});

  final BodyPart part;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hero = ref.watch(heroProvider);
    if (hero == null) return const SizedBox.shrink();
    final log = ref.watch(trainingLogProvider);
    final program = ref.watch(programProvider);
    final xp = hero.xp[part] ?? 0;
    final level = Progression.levelFromXp(xp);
    final progress = Progression.levelProgress(xp);
    final lagging = hero.lagging.contains(part);
    final stats = TrainingStats(log);
    final now = DateTime.now();

    final top = stats.topExercisesFor(
      part,
      (id) => ExerciseCatalog.tryById(id)?.shares[part] ?? 0,
    );
    final muscles = [
      for (final m in Muscle.values)
        if (m.part == part) (m, hero.muscles[m] ?? 0.0),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    final musclesMax = muscles.fold(0.0, (m, e) => e.$2 > m ? e.$2 : m);
    final start = startLevelOf(hero);
    final next = part == BodyPart.cardio
        ? null
        : ExerciseCatalog.forPart(part)
              .where(
                (e) =>
                    isAvailable(e.id, program.equipment) &&
                    e.difficulty <= program.levelOf(e.pattern, start: start),
              )
              .firstOrNull;
    final tip = tipLibrary.where((t) => t.part == part).firstOrNull;
    final cardioMinutes = log
        .where(
          (w) =>
              w.kind == WorkoutKind.cardio && now.difference(w.at).inDays < 30,
        )
        .fold(0, (m, w) => m + w.duration.inMinutes);

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 440,
                maxHeight: MediaQuery.sizeOf(context).height * 0.8,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: part.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${part.label} · уровень $level',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Закрыть',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(LucideIcons.x, size: 20),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 6,
                              color: part.color,
                              backgroundColor: AppColors.raised,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${(progress * GameConfig.xpPerLevel).round()} из '
                            '${GameConfig.xpPerLevel} опыта до уровня ${level + 1}'
                            '${lagging ? ' · отстаёт: опыт ×1,5' : ''}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                          ),
                          if (part == BodyPart.cardio) ...[
                            const _Label('Кардио за 30 дней'),
                            Text(
                              cardioMinutes == 0
                                  ? 'Пока не было. Опыт идёт за минуты в зоне 2 по пульсу'
                                  : '$cardioMinutes мин',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                          if (muscles.isNotEmpty) ...[
                            const _Label('Мышцы'),
                            for (final (m, points) in muscles)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 104,
                                      child: Text(
                                        m.label,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(3),
                                        child: LinearProgressIndicator(
                                          value: musclesMax <= 0
                                              ? 0
                                              : points / musclesMax,
                                          minHeight: 5,
                                          color: part.color.withValues(
                                            alpha: 0.8,
                                          ),
                                          backgroundColor: AppColors.raised,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                          if (top.isNotEmpty) ...[
                            const _Label('Лучше всего прокачали'),
                            for (final t in top)
                              _ExerciseLine(
                                exercise: ExerciseCatalog.byId(t.id),
                                trailing: '${t.sets.round()} подх.',
                              ),
                          ],
                          if (next != null) ...[
                            const _Label('Что делать'),
                            _ExerciseLine(
                              exercise: next,
                              trailing: difficultyLabels[next.difficulty],
                            ),
                          ],
                          if (tip != null) ...[
                            const _Label('Совет'),
                            Text(
                              tip.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tip.text,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.4,
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
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
    ),
  );
}

class _ExerciseLine extends StatelessWidget {
  const _ExerciseLine({required this.exercise, required this.trailing});

  final Exercise exercise;
  final String trailing;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => showExerciseDetails(context, exercise),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(exercise.name, style: const TextStyle(fontSize: 14)),
          ),
          Text(
            trailing,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(width: 4),
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
