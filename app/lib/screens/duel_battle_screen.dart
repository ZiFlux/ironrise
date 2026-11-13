import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../avatar/avatar_look.dart';
import '../avatar/avatar_view.dart';
import '../game/duel.dart';
import '../game/duel_flavor.dart';
import '../game/game_config.dart';
import '../state/duel_state.dart';
import '../state/providers.dart';
import '../game/duel_breakdown.dart';
import '../game/body_part.dart';
import '../theme.dart';

/// Анимация боя и результат с советом. Исход уже посчитан, экран только проигрывает удары.
class DuelBattleScreen extends ConsumerStatefulWidget {
  const DuelBattleScreen({super.key});

  @override
  ConsumerState<DuelBattleScreen> createState() => _DuelBattleScreenState();
}

class _DuelBattleScreenState extends ConsumerState<DuelBattleScreen> {
  static const _step = Duration(milliseconds: 700);

  Timer? _timer;

  /// Сколько ударов уже показано.
  int _shown = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_step, (_) {
      final total = ref.read(currentDuelProvider)?.hits.length ?? 0;
      if (_shown >= total) {
        _timer?.cancel();
      } else {
        setState(() => _shown++);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _skip(int total) {
    _timer?.cancel();
    setState(() => _shown = total);
  }

  @override
  Widget build(BuildContext context) {
    final duel = ref.watch(currentDuelProvider);
    final hero = ref.watch(heroProvider);
    if (duel == null || hero == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Дуэль')),
        body: Center(
          child: TextButton(
            onPressed: () => context.go('/duels'),
            child: const Text('К дуэлям'),
          ),
        ),
      );
    }

    final hits = duel.hits.take(_shown).toList();
    final last = hits.isEmpty ? null : hits.last;
    final done = _shown >= duel.hits.length;
    // Здоровье с учётом лечения событиями (креатин и т. п.).
    final hp = duel.hpAfter(_shown);
    int hpOf({required bool attacker}) => attacker ? hp.attacker : hp.defender;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Дуэль'),
        leading: IconButton(
          tooltip: 'К дуэлям',
          onPressed: () => context.go('/duels'),
          icon: const Icon(LucideIcons.arrowLeft),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Expanded(
                      child: _FighterPanel(
                        fighter: duel.attacker,
                        look: hero.look,
                        hp: hpOf(attacker: true),
                        isPlayer: true,
                        hitKey: last != null && !last.byAttacker
                            ? _shown
                            : null,
                        hitPart: last != null && !last.byAttacker ? last : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _FighterPanel(
                        fighter: duel.defender,
                        look: duel.defender.lookOrStarter,
                        hp: hpOf(attacker: false),
                        isPlayer: false,
                        hitKey: last != null && last.byAttacker ? _shown : null,
                        hitPart: last != null && last.byAttacker ? last : null,
                      ),
                    ),
                  ],
                ),
              ),
              if (!done) ...[
                SizedBox(
                  // Событие и удар — две строки; с крупным шрифтом выше.
                  height: MediaQuery.textScalerOf(context).scale(64),
                  child: Center(
                    child: last == null
                        ? const Text(
                            'Бой начинается…',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 15,
                            ),
                          )
                        : _HitLine(hit: last, duel: duel),
                  ),
                ),
                Align(
                  child: TextButton(
                    onPressed: () => _skip(duel.hits.length),
                    child: const Text('Пропустить'),
                  ),
                ),
              ] else
                // Итог с разбором: бойцы ужимаются, панель при нехватке места прокручивается.
                Flexible(
                  flex: 3,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: AppMotion.enter,
                    builder: (_, t, child) => Opacity(opacity: t, child: child),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(top: 8),
                      child: _ResultPanel(
                        duel: duel,
                        advice: DuelAdvice.forPlayer(duel.attacker),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FighterPanel extends StatelessWidget {
  const _FighterPanel({
    required this.fighter,
    required this.look,
    required this.hp,
    required this.isPlayer,
    required this.hitKey,
    this.hitPart,
  });

  /// Удар, который сейчас пришёлся по этому бойцу: где вспыхнуть.
  final DuelHit? hitPart;

  final Fighter fighter;
  final AvatarLook look;
  final int hp;
  final bool isPlayer;

  /// Меняется при каждом пропущенном ударе — запускает встряску.
  final int? hitKey;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final max = fighter.power;
    final avatar = AvatarView(levels: fighter.levels, look: look);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          fighter.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text(
          'сила ${fighter.power}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: max == 0 ? 0 : hp / max),
            duration: const Duration(milliseconds: 350),
            builder: (_, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 8,
              color: isPlayer ? accent : const Color(0xFFE5484D),
              backgroundColor: AppColors.raised,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$hp / $max',
          textAlign: TextAlign.center,
          style: figureStyle(size: 13),
        ),
        Expanded(
          child: _Shake(
            trigger: hitKey,
            child: Stack(
              fit: StackFit.expand,
              children: [
                isPlayer ? avatar : Transform.flip(flipX: true, child: avatar),
                if (hitPart case final hit?
                    when hit.kind != HitKind.miss &&
                        hit.kind != HitKind.skip &&
                        hit.damage > 0)
                  _HitFlash(key: ValueKey(hitKey), hit: hit),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Короткая встряска при попадании.
class _Shake extends StatelessWidget {
  const _Shake({required this.trigger, required this.child});

  final int? trigger;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (trigger == null) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(trigger),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      builder: (_, t, c) => Transform.translate(
        offset: Offset(sin(t * pi * 4) * 6 * (1 - t), 0),
        child: c,
      ),
      child: child,
    );
  }
}

class _HitLine extends StatelessWidget {
  const _HitLine({required this.hit, required this.duel});

  final DuelHit hit;
  final DuelResult duel;

  static const _healColor = Color(0xFF5BD68A);

  @override
  Widget build(BuildContext context) {
    final fighter = hit.byAttacker ? duel.attacker : duel.defender;
    final who = fighter.name;
    final accent = Theme.of(context).colorScheme.primary;
    final part = hit.part.label.toLowerCase();
    final boost = hit.boosted ? ' ×1,5' : '';
    final (text, color) = switch (hit.kind) {
      HitKind.miss => ('$who промахивается', AppColors.textMuted),
      HitKind.skip => ('$who пропускает ход', AppColors.textMuted),
      HitKind.hit => (
        '$who: $part, −${hit.damage}$boost',
        AppColors.textPrimary,
      ),
      HitKind.crit => ('Крит! $who: $part, −${hit.damage}$boost', accent),
    };
    final event = hit.eventId == null ? null : duelEventById(hit.eventId!);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (event != null)
          _Line(
            icon: switch (event.kind) {
              DuelEventKind.heal => LucideIcons.heartPlus,
              DuelEventKind.boost => LucideIcons.zap,
              DuelEventKind.skip => LucideIcons.hourglass,
            },
            color: switch (event.kind) {
              DuelEventKind.heal => _healColor,
              DuelEventKind.boost => accent,
              DuelEventKind.skip => AppColors.textSecondary,
            },
            text:
                event.phrase(who, female: fighter.isFemale) +
                (event.kind == DuelEventKind.heal && hit.heal > 0
                    ? ', +${hit.heal}'
                    : ''),
            size: 13,
          ),
        if (event != null) const SizedBox(height: 4),
        _Line(dot: hit.part.color, text: text, color: color, size: 15),
      ],
    );
  }
}

/// Строка под аватарами: иконка события или цветная точка части тела и текст.
class _Line extends StatelessWidget {
  const _Line({
    required this.text,
    required this.color,
    required this.size,
    this.icon,
    this.dot,
  });

  final String text;
  final Color color;
  final double size;
  final IconData? icon;
  final Color? dot;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (icon != null)
        Icon(icon, size: 14, color: color)
      else
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: size,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ],
  );
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.duel, required this.advice});

  final DuelResult duel;
  final String advice;

  @override
  Widget build(BuildContext context) {
    final won = duel.attackerWon;
    final accent = Theme.of(context).colorScheme.primary;
    final coins =
        duel.coins ??
        (won ? GameConfig.duelWinCoins : GameConfig.duelLossCoins);
    final hpA = (duel.attackerHpLeft / duel.attacker.power * 100).round();
    final hpD = (duel.defenderHpLeft / duel.defender.power * 100).round();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    won ? 'Победа' : 'Поражение',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: won ? accent : AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(
                  LucideIcons.coins,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text('+$coins', style: figureStyle(size: 17)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Осталось здоровья: у тебя $hpA%, у соперника $hpD%'
              '${duel.repeat ? '. Повторный бой за сутки — половина монет' : ''}',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 10),
            _Breakdown(breakdown: DuelBreakdown(duel)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.lightbulb, size: 16, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(advice, style: const TextStyle(fontSize: 14)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/duels'),
              child: const Text('К дуэлям'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Урон по частям тела: ты и соперник, плюс короткое «почему».
class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.breakdown});

  final DuelBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final me = breakdown.me;
    final them = breakdown.them;
    final parts = [
      for (final p in BodyPart.values)
        if ((me.damageByPart[p] ?? 0) + (them.damageByPart[p] ?? 0) > 0) p,
    ];
    final max = [
      ...me.damageByPart.values,
      ...them.damageByPart.values,
    ].fold(1, (m, v) => v > m ? v : m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in parts)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                // Ты — полоса растёт к центру слева, соперник — справа.
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FractionallySizedBox(
                      widthFactor: (me.damageByPart[p] ?? 0) / max,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: p.color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 72,
                  child: Text(
                    p.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: (them.damageByPart[p] ?? 0) / max,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: p.color.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'урон: ты ${me.total}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'соперник ${them.total}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
        for (final r in breakdown.reasons)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '· $r',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

/// Вспышка на части тела, куда пришёлся удар: координаты холста аватара 200×400.
class _HitFlash extends StatelessWidget {
  const _HitFlash({super.key, required this.hit});

  final DuelHit hit;

  static List<Offset> spotsOf(BodyPart part) => switch (part) {
    BodyPart.chest => const [Offset(100, 100)],
    BodyPart.back => const [Offset(76, 80), Offset(124, 80)],
    BodyPart.arms => const [Offset(58, 140), Offset(142, 140)],
    BodyPart.legs => const [Offset(86, 290), Offset(114, 290)],
    BodyPart.core => const [Offset(100, 165)],
    BodyPart.cardio => const [Offset(108, 98)],
  };

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 600),
    builder: (_, t, _) => CustomPaint(
      painter: _FlashPainter(
        spots: spotsOf(hit.part),
        color: hit.kind == HitKind.crit
            ? const Color(0xFFFFC94D)
            : hit.part.color,
        t: t,
        crit: hit.kind == HitKind.crit,
      ),
    ),
  );
}

class _FlashPainter extends CustomPainter {
  _FlashPainter({
    required this.spots,
    required this.color,
    required this.t,
    required this.crit,
  });

  final List<Offset> spots;
  final Color color;
  final double t;
  final bool crit;

  @override
  void paint(Canvas canvas, Size size) {
    // Тот же масштаб, что у AvatarPainter: холст 200×400 по центру.
    final scale = min(size.width / 200, size.height / 400);
    final dx = (size.width - 200 * scale) / 2;
    final dy = (size.height - 400 * scale) / 2;
    final fade = 1 - t;
    final radius = (crit ? 30 : 22) * scale * (0.7 + 0.5 * t);
    for (final s in spots) {
      final c = Offset(dx + s.dx * scale, dy + s.dy * scale);
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: 0.75 * fade),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(_FlashPainter old) => old.t != t;
}
