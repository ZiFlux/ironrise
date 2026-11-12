import 'dart:async';

import 'package:flutter/widgets.dart';

/// Перестраивает только себя раз в секунду — для часов и обратных отсчётов.
/// Так тикающий таймер не перерисовывает весь экран (и прокрутка не дёргается).
class EverySecond extends StatefulWidget {
  const EverySecond({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  State<EverySecond> createState() => _EverySecondState();
}

class _EverySecondState extends State<EverySecond> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
