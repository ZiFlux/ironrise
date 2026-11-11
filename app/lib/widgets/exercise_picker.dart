import 'package:flutter/material.dart';

import '../game/body_part.dart';
import '../game/exercise_catalog.dart';
import '../theme.dart';

/// Выбор упражнения из справочника с фильтром по части тела.
Future<Exercise?> showExercisePicker(
  BuildContext context, {
  BodyPart? initialPart,
  Set<String> alreadyAdded = const {},
}) =>
    showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _ExercisePicker(initialPart: initialPart, alreadyAdded: alreadyAdded),
    );

class _ExercisePicker extends StatefulWidget {
  const _ExercisePicker({required this.initialPart, required this.alreadyAdded});

  final BodyPart? initialPart;
  final Set<String> alreadyAdded;

  @override
  State<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<_ExercisePicker> {
  late BodyPart? _part = widget.initialPart;

  List<Exercise> get _visible => _part == null
      ? ExerciseCatalog.all
      : ExerciseCatalog.forPart(_part!);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      builder: (context, scroll) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: AppColors.raised, borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Упражнение', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
            ),
          ),
          _PartFilter(selected: _part, onSelected: (part) => setState(() => _part = part)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              itemCount: _visible.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) => _ExerciseRow(
                exercise: _visible[i],
                added: widget.alreadyAdded.contains(_visible[i].id),
                onTap: () => Navigator.pop(context, _visible[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PartFilter extends StatelessWidget {
  const _PartFilter({required this.selected, required this.onSelected});

  final BodyPart? selected;
  final ValueChanged<BodyPart?> onSelected;

  static const _strengthParts = [
    BodyPart.chest, BodyPart.back, BodyPart.arms, BodyPart.legs, BodyPart.core,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _chip('Все', selected == null, () => onSelected(null)),
          for (final part in _strengthParts) _chip(part.label, selected == part, () => onSelected(part)),
        ],
      ),
    );
  }

  Widget _chip(String label, bool isSelected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: isSelected,
          onSelected: (_) => onTap(),
          showCheckmark: false,
        ),
      );
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.exercise, required this.added, required this.onTap});

  final Exercise exercise;
  final bool added;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final parts = exercise.shares.keys.map((p) => p.label.toLowerCase()).join(' · ');
    return InkWell(
      onTap: added ? null : onTap,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: exercise.mainPart.color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(exercise.name,
                      style: TextStyle(
                        fontSize: 15,
                        color: added ? AppColors.textMuted : AppColors.textPrimary,
                      )),
                  Text(parts, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
            if (added) const Text('добавлено', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
