import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Подтверждение, которое не нажать сразу: кнопка оживает через [delay].
/// Для необратимого по ошибке — например, «Завершить» тренировку вместо
/// «Упражнение» рядом. true — подтвердили, false/null — передумали.
Future<bool> confirmWithDelay(
  BuildContext context, {
  required String title,
  required String message,
  required String confirm,
  String cancel = 'Продолжить',
  Duration delay = const Duration(seconds: 3),
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _DelayedConfirm(
        title: title,
        message: message,
        confirm: confirm,
        cancel: cancel,
        delay: delay,
      ),
    ) ??
    false;

class _DelayedConfirm extends StatefulWidget {
  const _DelayedConfirm({
    required this.title,
    required this.message,
    required this.confirm,
    required this.cancel,
    required this.delay,
  });

  final String title;
  final String message;
  final String confirm;
  final String cancel;
  final Duration delay;

  @override
  State<_DelayedConfirm> createState() => _DelayedConfirmState();
}

class _DelayedConfirmState extends State<_DelayedConfirm> {
  late int _left = widget.delay.inSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (_left > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() => _left--);
        if (_left <= 0) t.cancel();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppColors.surface,
    title: Text(widget.title),
    content: Text(widget.message),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: Text(widget.cancel),
      ),
      FilledButton(
        onPressed: _left > 0 ? null : () => Navigator.pop(context, true),
        child: Text(_left > 0 ? '${widget.confirm} · $_left' : widget.confirm),
      ),
    ],
  );
}
