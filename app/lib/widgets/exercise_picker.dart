import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/body_part.dart';
import '../game/exercise_catalog.dart';
import '../game/exercise_guide.dart';
import '../game/muscles.dart';
import '../game/game_config.dart';
import '../theme.dart';

/// Выбор упражнения из справочника с поиском и фильтром по части тела.
Future<Exercise?> showExercisePicker(
  BuildContext context, {
  BodyPart? initialPart,
  Set<String> alreadyAdded = const {},
}) => showModalBottomSheet<Exercise>(
  context: context,
  isScrollControlled: true,
  backgroundColor: AppColors.surface,
  shape: _sheetShape,
  builder: (_) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.75,
    maxChildSize: 0.92,
    builder: (context, scroll) => Column(
      children: [
        const _Grabber(),
        const _SheetTitle('Упражнение'),
        Expanded(
          child: ExerciseBrowser(
            initialPart: initialPart,
            alreadyAdded: alreadyAdded,
            scrollController: scroll,
            onTap: (e) => Navigator.pop(context, e),
          ),
        ),
      ],
    ),
  ),
);

/// Карточка упражнения: доли нагрузки и опыт за подход.
Future<void> showExerciseDetails(BuildContext context, Exercise exercise) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: _sheetShape,
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: _ExerciseDetails(exercise: exercise),
      ),
    );

const _sheetShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
);

/// Поиск + фильтр + список. Общий для выбора упражнения и справочника.
class ExerciseBrowser extends StatefulWidget {
  const ExerciseBrowser({
    super.key,
    required this.onTap,
    this.initialPart,
    this.alreadyAdded = const {},
    this.scrollController,
    this.showInfoButton = true,
  });

  final ValueChanged<Exercise> onTap;
  final BodyPart? initialPart;
  final Set<String> alreadyAdded;
  final ScrollController? scrollController;

  /// Кнопка «i» рядом с упражнением открывает карточку. В справочнике карточку
  /// открывает само нажатие, поэтому кнопка там не нужна.
  final bool showInfoButton;

  @override
  State<ExerciseBrowser> createState() => _ExerciseBrowserState();
}

class _ExerciseBrowserState extends State<ExerciseBrowser> {
  late BodyPart? _part = widget.initialPart;
  String _query = '';

  List<Exercise> get _visible {
    final byPart = _part == null
        ? ExerciseCatalog.all
        : ExerciseCatalog.forPart(_part!);
    final q = _query.trim().toLowerCase();
    return q.isEmpty
        ? byPart
        : byPart.where((e) => e.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Поиск',
              prefixIcon: const Icon(LucideIcons.search, size: 18),
              isDense: true,
              filled: true,
              fillColor: AppColors.raised,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        _PartFilter(
          selected: _part,
          onSelected: (part) => setState(() => _part = part),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: visible.isEmpty
              ? const Center(
                  child: Text(
                    'Ничего не нашлось',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                  ),
                )
              : ListView.separated(
                  controller: widget.scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 0, 8, 24),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) => _ExerciseRow(
                    exercise: visible[i],
                    added: widget.alreadyAdded.contains(visible[i].id),
                    onTap: () => widget.onTap(visible[i]),
                    onInfo: widget.showInfoButton
                        ? () => showExerciseDetails(context, visible[i])
                        : null,
                  ),
                ),
        ),
      ],
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.raised,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
      ),
    ),
  );
}

class _PartFilter extends StatelessWidget {
  const _PartFilter({required this.selected, required this.onSelected});

  final BodyPart? selected;
  final ValueChanged<BodyPart?> onSelected;

  static const _strengthParts = [
    BodyPart.chest,
    BodyPart.back,
    BodyPart.arms,
    BodyPart.legs,
    BodyPart.core,
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
          for (final part in _strengthParts)
            _chip(part.label, selected == part, () => onSelected(part)),
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
  const _ExerciseRow({
    required this.exercise,
    required this.added,
    required this.onTap,
    required this.onInfo,
  });

  final Exercise exercise;
  final bool added;
  final VoidCallback onTap;
  final VoidCallback? onInfo;

  @override
  Widget build(BuildContext context) {
    final parts = exercise.shares.keys
        .map((p) => p.label.toLowerCase())
        .join(' · ');
    return InkWell(
      onTap: added ? null : onTap,
      // Длинное название переносится на вторую строку — строка растёт, а не обрезается.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: exercise.mainPart.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: TextStyle(
                        fontSize: 15,
                        color: added
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      parts,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (added)
                const Text(
                  'добавлено',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              if (onInfo != null)
                IconButton(
                  onPressed: onInfo,
                  tooltip: 'Подробнее',
                  icon: const Icon(
                    LucideIcons.info,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                )
              else
                const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseDetails extends StatelessWidget {
  const _ExerciseDetails({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final shares = exercise.shares.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final kind = [
      exercise.usesWeight ? 'с отягощением' : 'свой вес',
      exercise.unit == ExerciseUnit.seconds ? 'на время' : 'на повторы',
    ].join(' · ');
    final muscles = (exerciseMuscles[exercise.id] ?? const {}).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final guide = exerciseGuides[exercise.id];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: _Grabber()),
            const SizedBox(height: 16),
            Text(
              exercise.name,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              kind,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),
            const Text(
              'Нагрузка и опыт за подход',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            for (final MapEntry(key: part, value: share) in shares)
              _ShareBar(part: part, share: share),
            const SizedBox(height: 8),
            const Text(
              'Опыт указан для подтверждённой тренировки. Отстающая часть получает ×1,5, без часов ×0,5',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            if (muscles.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'Целевые мышцы',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (i, MapEntry(key: m, value: share))
                      in muscles.indexed)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      side: BorderSide(
                        color: i == 0
                            ? m.part.color.withValues(alpha: 0.6)
                            : AppColors.hairline,
                      ),
                      backgroundColor: AppColors.raised,
                      label: Text(
                        '${m.label} · ${(share * 100).round()}%',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                ],
              ),
            ],
            if (guide != null) ...[
              const SizedBox(height: 20),
              const Text(
                'Техника',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              for (final (i, step) in guide.steps.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 22,
                        child: Text('${i + 1}', style: figureStyle(size: 14)),
                      ),
                      Expanded(
                        child: Text(step, style: const TextStyle(fontSize: 14)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      LucideIcons.triangleAlert,
                      size: 16,
                      color: Color(0xFFFFB547),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      guide.mistake,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
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

class _ShareBar extends StatelessWidget {
  const _ShareBar({required this.part, required this.share});

  final BodyPart part;
  final double share;

  @override
  Widget build(BuildContext context) {
    final xp = (GameConfig.baseXpPerSet * share).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(part.label, style: const TextStyle(fontSize: 14)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: share,
                minHeight: 6,
                color: part.color,
                backgroundColor: AppColors.raised,
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '${(share * 100).round()}%',
              textAlign: TextAlign.right,
              style: figureStyle(size: 14),
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              '+$xp XP',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
