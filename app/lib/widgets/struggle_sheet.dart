import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/exercise_catalog.dart';
import '../game/exercise_guide.dart';
import '../game/exercise_swap.dart';
import '../theme.dart';

/// Выбор в панели «Не получается?»: на что заменить, учиться ли делать
/// упражнение или убрать его на месяц.
typedef StruggleChoice = ({Exercise to, bool dislike, bool learn});

/// «Не получается упражнение?» (п. 80): техника по шагам, частая ошибка,
/// советы и замены с той же нагрузкой на те же мышцы.
Future<StruggleChoice?> showStruggleSheet(
  BuildContext context, {
  required Exercise exercise,
  required List<Exercise> options,
  required bool hasSets,
  List<Exercise> drills = const [],
}) => showModalBottomSheet<StruggleChoice>(
  context: context,
  isScrollControlled: true,
  backgroundColor: AppColors.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  ),
  builder: (context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.85,
    minChildSize: 0.4,
    maxChildSize: 0.92,
    builder: (context, scroll) => _StruggleSheet(
      exercise: exercise,
      options: options,
      hasSets: hasSets,
      drills: drills,
      scroll: scroll,
    ),
  ),
);

class _StruggleSheet extends StatefulWidget {
  const _StruggleSheet({
    required this.exercise,
    required this.options,
    required this.hasSets,
    required this.scroll,
    this.drills = const [],
  });

  /// Подводящие: чем научиться делать упражнение.
  final List<Exercise> drills;

  final Exercise exercise;
  final List<Exercise> options;
  final bool hasSets;
  final ScrollController scroll;

  @override
  State<_StruggleSheet> createState() => _StruggleSheetState();
}

class _StruggleSheetState extends State<_StruggleSheet> {
  bool _dislike = false;
  late bool _learn = widget.drills.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final guide = exerciseGuides[exercise.id];
    return SafeArea(
      child: ListView(
        controller: widget.scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.raised,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Не получается?',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            '${exercise.name}. Это нормально: у каждого есть упражнения, '
            'которые сначала не идут.',
            style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
          if (guide != null) ...[
            const _Heading('Как делать'),
            for (final (i, step) in guide.steps.indexed)
              _Numbered(n: i + 1, text: step),
            const SizedBox(height: 4),
            _Note(icon: LucideIcons.triangleAlert, text: guide.mistake),
          ],
          const _Heading('Что помогает'),
          for (final tip in struggleTips(exercise))
            _Note(icon: LucideIcons.check, text: tip, muted: false),
          const _Heading('Заменить'),
          if (widget.options.isEmpty)
            const Text(
              'Равноценной замены с твоим инвентарём нет. Попробуй советы выше '
              'или убери упражнение крестиком в карточке.',
              style: TextStyle(fontSize: 14, color: AppColors.textMuted),
            )
          else ...[
            Text(
              widget.hasSets
                  ? 'Сделанные подходы останутся, замена встанет следом с оставшимися.'
                  : 'Та же нагрузка на те же мышцы. План подходов сохранится.',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            for (final option in widget.options)
              _OptionTile(
                original: exercise,
                option: option,
                onTap: () => Navigator.pop<StruggleChoice>(context, (
                  to: option,
                  dislike: _dislike,
                  learn: _learn && !_dislike,
                )),
              ),
            const SizedBox(height: 4),
            if (widget.drills.isNotEmpty)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _learn,
                onChanged: (v) => setState(() {
                  _learn = v ?? false;
                  if (_learn) _dislike = false;
                }),
                title: const Text(
                  'Научиться делать',
                  style: TextStyle(fontSize: 14),
                ),
                subtitle: Text(
                  'В тренировках с этим упражнением — замена и подводящие: '
                  '${widget.drills.map((e) => e.name.toLowerCase()).join(', ')}. '
                  'Через 2 недели — проверка. Комплекс можно делать и отдельно',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _dislike,
              onChanged: (v) => setState(() {
                _dislike = v ?? false;
                if (_dislike) _learn = false;
              }),
              title: const Text(
                'Не ставить это упражнение месяц',
                style: TextStyle(fontSize: 14),
              ),
              subtitle: const Text(
                'В плане его заменит похожее. Вернуть — в «Самочувствии» после тренировки',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 10),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
    ),
  );
}

class _Numbered extends StatelessWidget {
  const _Numbered({required this.n, required this.text});

  final int n;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 22, child: Text('$n', style: figureStyle(size: 14))),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
      ],
    ),
  );
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text, this.muted = true});

  final IconData icon;
  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            icon,
            size: 16,
            color: muted
                ? const Color(0xFFFFB547)
                : Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: muted ? AppColors.textSecondary : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    ),
  );
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.original,
    required this.option,
    required this.onTap,
  });

  final Exercise original;
  final Exercise option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final overlap = (muscleOverlap(original, option) * 100).round();
    final easier = option.difficulty < original.difficulty;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.raised,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (easier) 'проще',
                        difficultyLabels[option.difficulty].toLowerCase(),
                        'те же мышцы на $overlap %',
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                LucideIcons.repeat,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
