import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../game/body_part.dart';
import '../game/hero_milestones.dart';
import '../game/muscles.dart';
import 'avatar_look.dart';
import 'avatar_view.dart';
import 'body_frame.dart';

/// Поза, которая лучше всего показывает самую развитую мышцу.
AvatarPose poseFor(MusclePoints muscles) {
  if (muscles.isEmpty) return AvatarPose.doubleBiceps;
  final balance = MuscleMath.balance(muscles);
  final top =
      MuscleMath.grotesque(muscles) ??
      balance.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  return switch (top.part) {
    BodyPart.back => AvatarPose.latSpread,
    BodyPart.core || BodyPart.legs => AvatarPose.handsBehindHead,
    _ => AvatarPose.doubleBiceps,
  };
}

/// Герой на главном экране раз в 10–20 секунд встаёт в позу и показывает мышцы
/// (п. 31 бэклога). Чаще — позу своей сильной мышцы, иногда — другие.
/// При «уменьшить движение» в системе стоит спокойно.
class PosingAvatar extends StatefulWidget {
  const PosingAvatar({
    super.key,
    required this.levels,
    required this.look,
    this.muscles = const {},
    this.withLamp = false,
    this.focus = const {},
  });

  /// Мышцы, которые качаются сейчас: позу выбираем по ним, а не за всё время.
  final MusclePoints focus;

  final Map<BodyPart, num> levels;
  final AvatarLook look;
  final MusclePoints muscles;
  final bool withLamp;

  @override
  State<PosingAvatar> createState() => _PosingAvatarState();
}

class _PosingAvatarState extends State<PosingAvatar>
    with SingleTickerProviderStateMixin {
  static const _in = Duration(milliseconds: 650);
  static const _hold = Duration(milliseconds: 2400);

  final _rng = Random();
  late final _anim = AnimationController(vsync: this, duration: _in);
  Timer? _timer;
  AvatarPose _pose = AvatarPose.doubleBiceps;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(Duration(seconds: 10 + _rng.nextInt(11)), _strike);
  }

  Future<void> _strike() async {
    if (!mounted) return;
    // Вкладка скрыта (TickerMode выключен) — не позируем: иначе поза ждала бы
    // и начиналась ровно при переходе на вкладку, отнимая кадры у перехода.
    if (MediaQuery.of(context).disableAnimations || !TickerMode.of(context)) {
      return _schedule();
    }
    final favourite = poseFor(
      widget.focus.isNotEmpty ? widget.focus : widget.muscles,
    );
    // Поза победы — только после вехи героя (средний уровень 5).
    final victory = heroLevel(widget.levels) >= victoryPoseLevel;
    final others = AvatarPose.values
        .where(
          (p) =>
              p != AvatarPose.relaxed &&
              p != favourite &&
              (p != AvatarPose.victory || victory),
        )
        .toList();
    setState(
      () => _pose = _rng.nextDouble() < 0.75
          ? favourite
          : others[_rng.nextInt(others.length)],
    );
    await _anim.animateTo(1, curve: Curves.easeOutBack);
    await Future<void>.delayed(_hold);
    if (!mounted) return;
    await _anim.animateBack(0, curve: Curves.easeInOut);
    if (mounted) _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, _) => AvatarView(
      levels: widget.levels,
      look: widget.look,
      muscles: widget.muscles,
      withLamp: widget.withLamp,
      pose: _pose,
      poseT: _anim.value,
    ),
  );
}
