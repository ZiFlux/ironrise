import 'package:flutter/material.dart';

/// Вкладка «на один экран»: на обычном телефоне всё помещается без прокрутки,
/// гибкие части (Expanded) растягиваются на свободное место. Если места не хватает —
/// маленький телефон или крупный системный шрифт — гибкие части сжимаются до своего
/// минимума, и появляется прокрутка вместо обрезанных и наехавших друг на друга блоков.
///
/// Внутри не должно быть списков с собственной прокруткой (ListView) — для них
/// интуитивная высота не определена.
class FitScreen extends StatelessWidget {
  const FitScreen({super.key, required this.child});

  /// Обычно Column с Expanded-частями; минимум Expanded задаётся ConstrainedBox внутри.
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    // Всегда отзывается на оттягивание — даже когда всё помещается: так работает
    // «потяни вниз — синхронизация» (оболочка вкладок в router.dart).
    physics: const AlwaysScrollableScrollPhysics(
      parent: ClampingScrollPhysics(),
    ),
    slivers: [SliverFillRemaining(hasScrollBody: false, child: child)],
  );
}

/// Гибкая часть с минимальной высотой: растёт на свободное место, но не меньше [minHeight].
class FlexibleMin extends StatelessWidget {
  const FlexibleMin({
    super.key,
    required this.minHeight,
    required this.child,
    this.flex = 1,
  });

  final double minHeight;
  final int flex;
  final Widget child;

  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: child,
    ),
  );
}
