import 'package:flutter/material.dart';

import '../theme.dart';

/// Отклик на нажатие: элемент чуть сжимается под пальцем и пружинит обратно.
/// Оборачивает уже нажимаемые карточки и плашки — сам нажатие не обрабатывает,
/// только слушает касание, поэтому InkWell и onTap внутри работают как раньше.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.scale = 0.97});

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

/// Появление при открытии экрана: проявляется и чуть поднимается.
/// [index] задаёт очередь: блоки выезжают один за другим, а не все разом.
/// Без таймеров — задержка заложена в кривую, поэтому ничего не «висит» после ухода с экрана.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  static const _step = 50; // мс между соседними блоками
  static const _own = 320; // мс на появление одного блока
  static const _maxDelayed = 8; // дальше — без задержки, чтобы длинные списки не ждали

  @override
  Widget build(BuildContext context) {
    final delay = _step * index.clamp(0, _maxDelayed);
    final total = delay + _own;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: AppMotion.curve),
      builder: (_, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: c),
      ),
      child: child,
    );
  }
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
      child: ScaleTransition(scale: Tween(begin: 0.8, end: 1.0).animate(animation), child: child),
    ),
    child: Text('$value', key: ValueKey(value), style: style),
  );
}
