import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme.dart';

/// Итог действия: от него зависят иконка и её цвет.
enum StatusKind {
  success(LucideIcons.circleCheck),
  error(LucideIcons.circleAlert),
  offline(LucideIcons.wifiOff),
  reward(LucideIcons.coins),
  info(LucideIcons.info);

  const StatusKind(this.icon);
  final IconData icon;
}

const _errorColor = Color(0xFFFF6B5E);

/// Корень приложения: плашка рисуется поверх всех экранов (см. main.dart).
final statusOverlayKey = GlobalKey<OverlayState>();

OverlayEntry? _current;

/// Плашка статуса сверху по центру, под заголовком экрана: «Образ сохранён»,
/// «Нет связи с сервером». Сама скрывается, по тапу — сразу; новая заменяет старую.
void showStatus(
  String text, {
  StatusKind kind = StatusKind.info,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(milliseconds: 2600),
}) {
  final overlay = statusOverlayKey.currentState;
  if (overlay == null) return;
  _current?.remove();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _StatusToast(
      text: text,
      kind: kind,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
      onGone: () {
        if (_current == entry) _current = null;
        if (entry.mounted) entry.remove();
      },
    ),
  );
  _current = entry;
  overlay.insert(entry);
}

/// Ошибка сервера одной строкой: без сети — своя иконка.
void showStatusError(String text, {bool network = false}) => showStatus(
  network ? 'Нет связи с сервером' : text,
  kind: network ? StatusKind.offline : StatusKind.error,
);

class _StatusToast extends StatefulWidget {
  const _StatusToast({
    required this.text,
    required this.kind,
    required this.actionLabel,
    required this.onAction,
    required this.duration,
    required this.onGone,
  });

  final String text;
  final StatusKind kind;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;
  final VoidCallback onGone;

  @override
  State<_StatusToast> createState() => _StatusToastState();
}

class _StatusToastState extends State<_StatusToast>
    with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    reverseDuration: const Duration(milliseconds: 180),
  )..forward();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, _hide);
  }

  Future<void> _hide() async {
    _timer?.cancel();
    if (!mounted) return;
    await _anim.reverse();
    widget.onGone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final iconColor = switch (widget.kind) {
      StatusKind.success || StatusKind.reward => accent,
      StatusKind.error => _errorColor,
      StatusKind.offline || StatusKind.info => AppColors.textSecondary,
    };
    final curved = CurvedAnimation(parent: _anim, curve: AppMotion.curve);
    final top = MediaQuery.paddingOf(context).top + 64;

    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, -0.4),
                end: Offset.zero,
              ).animate(curved),
              child: Semantics(
                liveRegion: true,
                child: Material(
                  color: AppColors.raised,
                  elevation: 8,
                  shadowColor: Colors.black,
                  shape: StadiumBorder(
                    side: BorderSide(color: iconColor.withValues(alpha: 0.35)),
                  ),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: _hide,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 18, 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(widget.kind.icon, size: 20, color: iconColor),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              widget.text,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (widget.actionLabel != null) ...[
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () {
                                widget.onAction?.call();
                                _hide();
                              },
                              child: Text(
                                widget.actionLabel!,
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
