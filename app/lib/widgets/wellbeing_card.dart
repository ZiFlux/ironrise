import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/exercise_catalog.dart';
import '../game/game_config.dart';
import '../game/wellbeing.dart';
import '../state/program_state.dart';
import '../theme.dart';

/// «Как самочувствие?» после тренировки: одно касание, при «болит» — где.
class WellbeingCard extends ConsumerStatefulWidget {
  const WellbeingCard({super.key, this.exerciseIds = const []});

  /// Упражнения прошедшей тренировки — для «не зашло».
  final List<String> exerciseIds;

  @override
  ConsumerState<WellbeingCard> createState() => _WellbeingCardState();
}

class _WellbeingCardState extends ConsumerState<WellbeingCard> {
  bool _askingWhere = false;
  WellbeingResponse? _response;

  Future<void> _answer(Feeling feeling, {PainZone? zone}) async {
    final response = await ref
        .read(programProvider.notifier)
        .recordWellbeing(feeling, zone: zone);
    if (mounted) setState(() => _response = response);
  }

  @override
  Widget build(BuildContext context) {
    final response = _response;
    final disliked = ref.watch(programProvider).disliked.keys.toSet();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Как самочувствие?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            // Упражнения этой тренировки: что «не зашло», месяц заменяем похожим.
            if (response != null && widget.exerciseIds.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Какое упражнение не зашло? Заменим похожим',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final id in widget.exerciseIds)
                    FilterChip(
                      label: Text(ExerciseCatalog.byId(id).name),
                      selected: disliked.contains(id),
                      onSelected: (_) =>
                          ref.read(programProvider.notifier).toggleDislike(id),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            if (response != null)
              Text(
                _reply(response),
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              )
            else if (_askingWhere)
              _Choices(
                options: [
                  for (final z in PainZone.values)
                    (z.label, () => _answer(Feeling.pain, zone: z)),
                ],
              )
            else
              _Choices(
                options: [
                  (Feeling.easy.label, () => _answer(Feeling.easy)),
                  (Feeling.ok.label, () => _answer(Feeling.ok)),
                  (Feeling.hard.label, () => _answer(Feeling.hard)),
                  (
                    Feeling.pain.label,
                    () => setState(() => _askingWhere = true),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static String _reply(WellbeingResponse r) => switch (r.feeling) {
    Feeling.easy when r.boostNext =>
      'Второй раз подряд легко — в следующей тренировке на подход больше '
          '(не больше ${GameConfig.maxSetsPerExercise})',
    Feeling.easy =>
      'Запомнили. Если и в следующий раз будет легко, добавим подход',
    Feeling.ok => 'Отлично. План без изменений',
    Feeling.hard when r.easeNext => 'Второй раз подряд тяжело — следующая тренировка будет легче: на подход меньше в каждом упражнении',
    Feeling.hard =>
      'Запомнили. Если в следующий раз снова будет тяжело, облегчим план',
    Feeling.pain => _painReply(r),
  };

  static String _painReply(WellbeingResponse r) {
    final zone = r.zone ?? PainZone.other;
    final changes = r.plan?.adjustments ?? const [];
    final plan = changes.isEmpty
        ? 'В следующей тренировке нагрузки на эту зону нет.'
        : 'На неделю бережём ${zone.label.toLowerCase()}: ${changes.map(_describe).join('; ')}.';
    final doctor = r.repeatedPain
        ? ' Боль повторяется — покажитесь врачу, прежде чем нагружать эту зону снова.'
        : ' Если боль острая или не проходит за пару дней, покажитесь врачу.';
    return zone == PainZone.other ? 'Запомнили.$doctor' : '$plan$doctor';
  }

  static String _describe(PlanAdjustment a) {
    final name = ExerciseCatalog.byId(a.exerciseId).name.toLowerCase();
    final replacement = a.replacementId;
    return replacement == null
        ? '$name — пропускаем'
        : '$name → ${ExerciseCatalog.byId(replacement).name.toLowerCase()}';
  }
}

class _Choices extends StatelessWidget {
  const _Choices({required this.options});

  final List<(String, VoidCallback)> options;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (label, onTap) in options)
          ActionChip(label: Text(label), onPressed: onTap),
      ],
    );
  }
}
