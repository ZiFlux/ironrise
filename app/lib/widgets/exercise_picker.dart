import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/body_part.dart';
import '../game/exercise_catalog.dart';
import '../game/exercise_guide.dart';
import '../game/muscles.dart';
import '../game/game_config.dart';
import '../state/favorites_state.dart';
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
      // Тянется и закрывается свайпом вниз и за полоску, и за содержимое, когда
      // оно прокручено к началу (раньше свайп уходил в прокрутку, п. 71).
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (context, scroll) =>
            _ExerciseDetails(exercise: exercise, scroll: scroll),
      ),
    );

const _sheetShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
);

/// Поиск + фильтр + список. Общий для выбора упражнения и справочника.
class ExerciseBrowser extends ConsumerStatefulWidget {
  const ExerciseBrowser({
    super.key,
    required this.onTap,
    this.initialPart,
    this.alreadyAdded = const {},
    this.scrollController,
    this.showInfoButton = true,
    this.showDifficulty = false,
  });

  final ValueChanged<Exercise> onTap;
  final BodyPart? initialPart;
  final Set<String> alreadyAdded;
  final ScrollController? scrollController;

  /// Кнопка «i» рядом с упражнением открывает карточку. В справочнике карточку
  /// открывает само нажатие, поэтому кнопка там не нужна.
  final bool showInfoButton;

  /// Фильтр по сложности — в базе знаний; при выборе упражнения он лишний.
  final bool showDifficulty;

  @override
  ConsumerState<ExerciseBrowser> createState() => _ExerciseBrowserState();
}

class _ExerciseBrowserState extends ConsumerState<ExerciseBrowser> {
  late BodyPart? _part = widget.initialPart;
  bool _favoritesOnly = false;
  int? _difficulty;
  String _query = '';

  List<Exercise> _visible(Set<String> favorites) {
    final byPart = _part == null
        ? ExerciseCatalog.all
        : ExerciseCatalog.forPart(_part!);
    final q = _query.trim().toLowerCase();
    final list = byPart
        .where((e) => !_favoritesOnly || favorites.contains(e.id))
        .where((e) => _difficulty == null || e.difficulty == _difficulty)
        .where((e) => q.isEmpty || e.name.toLowerCase().contains(q))
        .toList();
    // Избранные — наверх, порядок внутри групп сохраняется.
    return [
      ...list.where((e) => favorites.contains(e.id)),
      ...list.where((e) => !favorites.contains(e.id)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(favoritesProvider);
    final visible = _visible(favorites);
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
          favoritesOnly: _favoritesOnly,
          onSelected: (part) => setState(() {
            _part = part;
            _favoritesOnly = false;
          }),
          onFavorites: () => setState(() {
            _favoritesOnly = true;
            _part = null;
          }),
        ),
        if (widget.showDifficulty) ...[
          const SizedBox(height: 6),
          _DifficultyFilter(
            selected: _difficulty,
            onSelected: (d) => setState(() => _difficulty = d),
          ),
        ],
        const SizedBox(height: 8),
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _favoritesOnly && favorites.isEmpty
                          ? 'Отмечай упражнения звёздочкой — они будут здесь'
                          : 'Ничего не нашлось',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14,
                      ),
                    ),
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
                    favorite: favorites.contains(visible[i].id),
                    onFavorite: () => ref
                        .read(favoritesProvider.notifier)
                        .toggle(visible[i].id),
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
  const _PartFilter({
    required this.selected,
    required this.favoritesOnly,
    required this.onSelected,
    required this.onFavorites,
  });

  final BodyPart? selected;
  final bool favoritesOnly;
  final ValueChanged<BodyPart?> onSelected;
  final VoidCallback onFavorites;

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
          _chip('★ Избранное', favoritesOnly, onFavorites),
          _chip(
            'Все',
            selected == null && !favoritesOnly,
            () => onSelected(null),
          ),
          for (final part in _strengthParts)
            _chip(part.label, selected == part, () => onSelected(part)),
        ],
      ),
    );
  }

  Widget _chip(String label, bool isSelected, VoidCallback onTap) =>
      _filterChip(label, isSelected, onTap);
}

Widget _filterChip(String label, bool isSelected, VoidCallback onTap) =>
    Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
      ),
    );

class _DifficultyFilter extends StatelessWidget {
  const _DifficultyFilter({required this.selected, required this.onSelected});

  final int? selected;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 36,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        _filterChip(
          'Любая сложность',
          selected == null,
          () => onSelected(null),
        ),
        for (var d = 1; d <= 3; d++)
          _filterChip(difficultyLabels[d], selected == d, () => onSelected(d)),
      ],
    ),
  );
}

class _StarButton extends StatelessWidget {
  const _StarButton({required this.favorite, required this.onTap});

  final bool favorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: favorite ? 'Убрать из избранного' : 'В избранное',
    onPressed: onTap,
    icon: Icon(
      LucideIcons.star,
      size: 18,
      color: favorite ? const Color(0xFFFFC94D) : AppColors.textMuted,
      fill: favorite ? 1 : 0,
    ),
  );
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    required this.exercise,
    required this.added,
    required this.onTap,
    required this.onInfo,
    required this.favorite,
    required this.onFavorite,
  });

  final Exercise exercise;
  final bool added;
  final bool favorite;
  final VoidCallback onFavorite;
  final VoidCallback onTap;
  final VoidCallback? onInfo;

  @override
  Widget build(BuildContext context) {
    final parts = [
      ...exercise.shares.keys.map((p) => p.label.toLowerCase()),
      difficultyLabels[exercise.difficulty].toLowerCase(),
      exercise.gear.label.toLowerCase(),
    ].join(' · ');
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
              _StarButton(favorite: favorite, onTap: onFavorite),
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

class _ExerciseDetails extends ConsumerWidget {
  const _ExerciseDetails({required this.exercise, this.scroll});

  final Exercise exercise;
  final ScrollController? scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorite = ref.watch(favoritesProvider).contains(exercise.id);
    // Варианты того же движения: проще и сложнее — путь прогрессии.
    final family = ExerciseCatalog.all
        .where((e) => e.pattern == exercise.pattern && e.id != exercise.id)
        .toList();
    final easier = family
        .where((e) => e.difficulty < exercise.difficulty)
        .toList();
    final harder = family
        .where((e) => e.difficulty > exercise.difficulty)
        .toList();
    final shares = exercise.shares.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final kind = [
      difficultyLabels[exercise.difficulty],
      exercise.gear.label.toLowerCase(),
      exercise.usesWeight ? 'с отягощением' : 'свой вес',
      exercise.unit == ExerciseUnit.seconds ? 'на время' : 'на повторы',
    ].join(' · ');
    final muscles = (exerciseMuscles[exercise.id] ?? const {}).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final guide = exerciseGuides[exercise.id];
    return SafeArea(
      child: SingleChildScrollView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: _Grabber()),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    exercise.name,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                _StarButton(
                  favorite: favorite,
                  onTap: () =>
                      ref.read(favoritesProvider.notifier).toggle(exercise.id),
                ),
              ],
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
            if (easier.isNotEmpty || harder.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'Варианты движения',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              for (final (label, list) in [
                ('Проще', easier),
                ('Сложнее', harder),
              ])
                if (list.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$label: ',
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                          TextSpan(text: list.map((e) => e.name).join(', ')),
                        ],
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
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
