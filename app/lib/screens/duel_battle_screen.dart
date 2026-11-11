import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../avatar/avatar_look.dart';
import '../avatar/avatar_view.dart';
import '../game/duel.dart';
import '../game/game_config.dart';
import '../state/duel_state.dart';
import '../state/providers.dart';
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
    int hpOf({required bool attacker}) {
      for (final h in hits.reversed) {
        if (h.byAttacker != attacker) return h.targetHpAfter;
      }
      return attacker ? duel.attacker.power : duel.defender.power;
    }

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
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 44,
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
              AnimatedSwitcher(
                duration: AppMotion.enter,
                child: done
                    ? _ResultPanel(
                        duel: duel,
                        advice: DuelAdvice.forPlayer(duel.attacker),
                      )
                    : Align(
                        child: TextButton(
                          onPressed: () => _skip(duel.hits.length),
                          child: const Text('Пропустить'),
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
  });

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
            child: isPlayer
                ? avatar
                : Transform.flip(flipX: true, child: avatar),
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

  @override
  Widget build(BuildContext context) {
    final who = hit.byAttacker ? duel.attacker.name : duel.defender.name;
    final accent = Theme.of(context).colorScheme.primary;
    final (text, color) = switch (hit.kind) {
      HitKind.miss => ('$who промахивается', AppColors.textMuted),
      HitKind.hit => (
        '$who: ${hit.part.label.toLowerCase()}, −${hit.damage}',
        AppColors.textPrimary,
      ),
      HitKind.crit => (
        'Крит! $who: ${hit.part.label.toLowerCase()}, −${hit.damage}',
        accent,
      ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: hit.part.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.duel, required this.advice});

  final DuelResult duel;
  final String advice;

  @override
  Widget build(BuildContext context) {
    final won = duel.attackerWon;
    final accent = Theme.of(context).colorScheme.primary;
    final coins = won ? GameConfig.duelWinCoins : GameConfig.duelLossCoins;
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
                Text(
                  won ? 'Победа' : 'Поражение',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: won ? accent : AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
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
              'Осталось здоровья: у тебя $hpA%, у соперника $hpD%',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
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
