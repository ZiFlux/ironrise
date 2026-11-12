import 'package:flutter/material.dart';

import '../theme.dart';

/// Отклик на нажатие: элемент чуть сжимается под пальцем и пружинит обратно.
/// Оборачивает уже нажимаемые карточки и плашки — сам нажатие не обрабатывает,
/// только слушает касание, поэтому InkWell и onTap внутри работают как раньше.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.scale = 0.95});

  final Widget child;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _set(true),
    onPointerUp: (_) => _set(false),
    onPointerCancel: (_) => _set(false),
    child: AnimatedScale(
      scale: _down ? widget.scale : 1,
      duration: _down ? AppMotion.fast : const Duration(milliseconds: 260),
      curve: _down ? Curves.easeOut : Curves.easeOutBack,
      child: widget.child,
    ),
  );
}

/// Счётчик заходов на вкладку: меняется при каждом переключении вкладок внизу.
/// FadeSlideIn, увидев новый заход, проигрывает появление заново.
class TabVisit extends InheritedWidget {
  const TabVisit({super.key, required this.visit, required super.child});

  final int visit;

  static int of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TabVisit>()?.visit ?? 0;

  @override
  bool updateShouldNotify(TabVisit oldWidget) => visit != oldWidget.visit;
}

/// Появление: блок проявляется и поднимается снизу. [index] задаёт очередь —
/// блоки выезжают один за другим. Повторяется при каждом заходе на вкладку,
/// но сам блок не пересоздаётся (его состояние сохраняется).
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  static const _step = 60; // мс между соседними блоками
  static const _own = 420; // мс на появление одного блока
  static const _maxDelayed =
      8; // дальше — без задержки, чтобы длинные списки не ждали
  static const _rise = 24.0; // на сколько dp блок поднимается

  late final AnimationController _c;
  late final Animation<double> _t;
  int? _visit;

  @override
  void initState() {
    super.initState();
    final delay = _step * widget.index.clamp(0, _maxDelayed);
    final total = delay + _own;
    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: total),
    );
    _t = CurvedAnimation(
      parent: _c,
      curve: Interval(delay / total, 1, curve: AppMotion.curve),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visit = TabVisit.of(context);
    if (visit != _visit) {
      _visit = visit;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _t,
    builder: (_, child) => Opacity(
      opacity: _t.value,
      child: Transform.translate(
        offset: Offset(0, _rise * (1 - _t.value)),
        child: child,
      ),
    ),
    child: widget.child,
  );
}

/// Число, которое при изменении меняется с анимацией (монеты, сила, серия).
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({super.key, required this.value, required this.style});

  final int value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 280),
    switchInCurve: AppMotion.curve,
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween(begin: 0.8, end: 1.0).animate(animation),
        child: child,
      ),
    ),
    child: Text('$value', key: ValueKey(value), style: style),
  );
}
