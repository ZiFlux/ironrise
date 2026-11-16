import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'motion.dart';

/// Облако-сводка рядом с элементом (п. 127): заголовок, пара строк и, по желанию,
/// кнопка «Подробнее». Закрывается нажатием мимо, кнопкой «назад» или само через 8 с.
/// [anchor] — контекст нажатого элемента: облако встаёт под ним (или над, если снизу тесно).
Future<void> showInfoBubble(
  BuildContext anchor, {
  String? title,
  required String text,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final box = anchor.findRenderObject() as RenderBox?;
  final overlay = Overlay.of(anchor, rootOverlay: true);
  final overlayBox = overlay.context.findRenderObject() as RenderBox?;
  if (box == null || overlayBox == null || !box.hasSize) return Future.value();
  final rect = box.localToGlobal(Offset.zero, ancestor: overlayBox) & box.size;
  return Navigator.of(anchor, rootNavigator: true).push(
    _BubbleRoute(
      target: rect,
      title: title,
      text: text,
      actionLabel: actionLabel,
      onAction: onAction,
    ),
  );
}

class _BubbleRoute extends PopupRoute<void> {
  _BubbleRoute({
    required this.target,
    required this.title,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final Rect target;
  final String? title;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Color? get barrierColor => Colors.black26;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Закрыть';

  @override
  Duration get transitionDuration => AppMotion.fast;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final accent = Theme.of(context).colorScheme.primary;
    final screen = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    const margin = 12.0;
    final width = math.min(320.0, screen.width - 2 * margin);
    final below = target.bottom + 8;
    // Под элементом, если снизу есть хотя бы треть экрана, иначе — над ним.
    final showBelow = screen.height - pad.bottom - below > screen.height / 3;
    final left = (target.center.dx - width / 2).clamp(
      margin,
      screen.width - width - margin,
    );
    final bubble = Material(
      color: AppColors.raised,
      elevation: 8,
      shadowColor: Colors.black,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
            if (actionLabel != null && onAction != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onAction!();
                  },
                  child: Text(actionLabel!, style: TextStyle(color: accent)),
                ),
              )
            else
              const SizedBox(height: 4),
          ],
        ),
      ),
    );
    return _AutoClose(
      child: Stack(
        children: [
          Positioned(
            left: left,
            width: width,
            top: showBelow ? below : null,
            bottom: showBelow ? null : screen.height - target.top + 8,
            child: FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                alignment: showBelow
                    ? Alignment.topCenter
                    : Alignment.bottomCenter,
                scale: Tween(begin: 0.92, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: AppMotion.curve),
                ),
                child: Semantics(liveRegion: true, child: bubble),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Облако не висит вечно: само закрывается через 8 секунд.
class _AutoClose extends StatefulWidget {
  const _AutoClose({required this.child});

  final Widget child;

  @override
  State<_AutoClose> createState() => _AutoCloseState();
}

class _AutoCloseState extends State<_AutoClose> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 8), () {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route != null && route.isCurrent) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Элемент, который что-то значит и потому нажимается (п. 127): проседает под
/// пальцем, даёт волну и читается экранным диктором как кнопка.
/// [onTap] получает контекст самого элемента — для облака рядом с ним.
class Tappable extends StatelessWidget {
  const Tappable({
    super.key,
    required this.onTap,
    required this.child,
    this.semantics,
    this.radius = 10,
  });

  final void Function(BuildContext context) onTap;
  final Widget child;
  final String? semantics;
  final double radius;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semantics,
    child: Pressable(
      scale: 0.97,
      child: Material(
        type: MaterialType.transparency,
        child: Builder(
          builder: (inner) => InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: () => onTap(inner),
            child: child,
          ),
        ),
      ),
    ),
  );
}
