import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/goals_state.dart';
import '../state/hero.dart';
import '../state/providers.dart';
import '../theme.dart';
import 'schedule_picker.dart' show ChoiceTile;

/// Выбор целей (п. 100): главная — одна из списка, дополнительные — до двух чипами.
/// Общий для онбординга и настроек.
class GoalsPicker extends StatelessWidget {
  const GoalsPicker({
    super.key,
    required this.goal,
    required this.extra,
    required this.onChanged,
  });

  final Goal? goal;
  final List<Goal> extra;
  final void Function(Goal? goal, List<Goal> extra) onChanged;

  @override
  Widget build(BuildContext context) {
    final main = goal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Главная цель',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        for (final g in Goal.values)
          ChoiceTile(
            selected: main == g,
            title: g.label,
            onTap: () => onChanged(g, [
              for (final e in extra)
                if (e != g) e,
            ]),
          ),
        if (main != null) ...[
          const SizedBox(height: 12),
          Text(
            'Ещё цели — до ${Goal.maxExtra}, по желанию',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          const Text(
            'Главная задаёт план тренировок, дополнительные — советы и напоминания',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final g in Goal.values)
                if (g != main)
                  FilterChip(
                    label: Text(g.label),
                    selected: extra.contains(g),
                    onSelected:
                        extra.contains(g) || extra.length < Goal.maxExtra
                        ? (on) => onChanged(
                            main,
                            on
                                ? [...extra, g]
                                : [
                                    for (final e in extra)
                                      if (e != g) e,
                                  ],
                          )
                        : null,
                  ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Сменить цели из настроек: нижняя панель с [GoalsPicker] и «Сохранить».
Future<void> showGoalsSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: AppColors.surface,
  showDragHandle: true,
  builder: (_) => const _GoalsSheet(),
);

class _GoalsSheet extends ConsumerStatefulWidget {
  const _GoalsSheet();

  @override
  ConsumerState<_GoalsSheet> createState() => _GoalsSheetState();
}

class _GoalsSheetState extends ConsumerState<_GoalsSheet> {
  late Goal? _goal = ref.read(heroProvider)?.goal;
  late List<Goal> _extra = [...?ref.read(heroProvider)?.extraGoals];

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GoalsPicker(
            goal: _goal,
            extra: _extra,
            onChanged: (g, e) => setState(() {
              _goal = g;
              _extra = e;
            }),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _goal == null
                ? null
                : () async {
                    await ref.read(goalsSyncProvider).save(_goal!, _extra);
                    if (context.mounted) Navigator.pop(context);
                  },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    ),
  );
}
