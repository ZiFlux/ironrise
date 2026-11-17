import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/exercise_catalog.dart';
import '../game/game_config.dart';
import '../game/wellbeing.dart';
import '../state/account_state.dart';
import '../state/program_state.dart';
import '../state/wellbeing_consent.dart';
import '../theme.dart';

/// «Как самочувствие?» после тренировки: одно касание, при «болит» — где и как (п. 81).
class WellbeingCard extends ConsumerStatefulWidget {
  const WellbeingCard({super.key, this.exerciseIds = const []});

  /// Упражнения прошедшей тренировки — для «не зашло».
  final List<String> exerciseIds;

  @override
  ConsumerState<WellbeingCard> createState() => _WellbeingCardState();
}

class _WellbeingCardState extends ConsumerState<WellbeingCard> {
  bool _askingWhere = false;
  PainZone? _zone;
  WellbeingResponse? _response;

  Future<void> _answer(
    Feeling feeling, {
    PainZone? zone,
    PainKind? kind,
  }) async {
    final response = await ref
        .read(programProvider.notifier)
        .recordWellbeing(feeling, zone: zone, kind: kind);
    if (mounted) setState(() => _response = response);
    // На сервер — только с отдельным согласием (п. 81).
    await ref
        .read(wellbeingConsentProvider.notifier)
        .report(
          feeling: feeling,
          zone: zone,
          kind: kind,
          exercises: widget.exerciseIds,
        );
  }

  /// Согласился отправлять — отправить и уже данный ответ.
  Future<void> _consent(bool granted) async {
    await ref.read(wellbeingConsentProvider.notifier).set(granted);
    final r = _response;
    if (granted && r != null) {
      await ref
          .read(wellbeingConsentProvider.notifier)
          .report(
            feeling: r.feeling,
            zone: r.zone,
            kind: r.kind,
            exercises: widget.exerciseIds,
          );
    }
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
            if (response != null) ...[
              Text(
                _reply(response),
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
              // Один раз спросить, можно ли отправлять ответы (данные о здоровье).
              if (ref.watch(wellbeingConsentProvider) == null &&
                  ref.watch(accountProvider).signedIn) ...[
                const SizedBox(height: 12),
                const Text(
                  'Помочь улучшить подбор упражнений? Ответы о самочувствии и боли — '
                  'данные о здоровье, отправляем их только с вашего согласия. '
                  'Отозвать можно в настройках',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 8),
                _Choices(
                  options: [
                    ('Отправлять', () => _consent(true)),
                    ('Не надо', () => _consent(false)),
                  ],
                ),
              ],
            ] else if (_askingWhere && _zone != null)
              _Choices(
                options: [
                  for (final k in PainKind.values)
                    (
                      k.label,
                      () => _answer(Feeling.pain, zone: _zone, kind: k),
                    ),
                ],
              )
            else if (_askingWhere)
              _Choices(
                options: [
                  for (final z in PainZone.values)
                    (z.label, () => setState(() => _zone = z)),
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
    if (r.kind?.normal ?? false) {
      return 'Это обычная мышечная усталость, план не меняем. Помогут сон, вода, '
          'лёгкая разминка и растяжка. Если через 3–4 дня не проходит или болит сустав — '
          'отметь это снова.';
    }
    final changes = r.plan?.adjustments ?? const [];
    final plan = changes.isEmpty
        ? 'В следующей тренировке нагрузки на эту зону нет.'
        : 'На неделю бережём ${zone.label.toLowerCase()}: ${changes.map(_describe).join('; ')}.';
    final doctor = (r.kind?.alarming ?? false)
        ? ' ${r.kind == PainKind.numb ? 'Онемение' : 'Острая боль'} — повод показаться врачу до того, как нагружать эту зону снова.'
        : r.repeatedPain
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
