import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../avatar/avatar_look.dart';
import '../avatar/avatar_view.dart';
import '../game/aura.dart';
import '../game/combat.dart';
import '../game/duel.dart';
import '../game/duel_flavor.dart';
import '../net/api_client.dart';
import '../state/fight_state.dart';
import '../state/heart_rate_state.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../widgets/aura_flame.dart';
import '../widgets/info_bubble.dart';
import '../widgets/status_toast.dart';

/// Бой по раундам (docs/COMBAT.md): перед раундом — цепочка из 5 действий,
/// потом шаги проигрываются по очереди. Считает всё сервер.
class FightScreen extends ConsumerStatefulWidget {
  const FightScreen({super.key});

  @override
  ConsumerState<FightScreen> createState() => _FightScreenState();
}

class _FightScreenState extends ConsumerState<FightScreen> {
  final List<CombatAction> _chain = [];
  bool _sending = false;

  /// Шаги раунда, которые проигрываются сейчас, и сколько уже показано.
  List<CombatStep> _playing = const [];
  int _shown = 0;
  Timer? _timer;

  static const _stepPause = Duration(milliseconds: 1100);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _go() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final next = await ref
          .read(fightProvider.notifier)
          .playRound(List.of(_chain));
      if (!mounted) return;
      setState(() {
        _chain.clear();
        _playing = next.lastSteps;
        _shown = 0;
      });
      _timer?.cancel();
      _timer = Timer.periodic(_stepPause, (t) {
        if (!mounted) return t.cancel();
        if (_shown >= _playing.length) return t.cancel();
        setState(() => _shown++);
        _flashIfAura();
      });
      setState(() => _shown = 1);
      _flashIfAura();
    } on ApiException catch (e) {
      if (mounted) showStatusError(e.message, network: e.isNetwork);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Моя аура включилась на показанном шаге — вспышка и вибрация на часах (п. 83).
  void _flashIfAura() {
    if (_shown < 1 || _shown > _playing.length) return;
    final mine = _playing[_shown - 1].auraOf(attacker: true);
    if (mine != null && mine.start) flashAuraOnWatch(mine.kind.name);
  }

  void _skip() {
    _timer?.cancel();
    setState(() => _shown = _playing.length);
  }

  @override
  Widget build(BuildContext context) {
    final fight = ref.watch(fightProvider);
    final hero = ref.watch(heroProvider);
    if (fight == null || hero == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Бой')),
        body: Center(
          child: TextButton(
            onPressed: () => context.go('/duels'),
            child: const Text('К дуэлям'),
          ),
        ),
      );
    }
    final playing = _shown < _playing.length;
    final step = _shown > 0 && _shown <= _playing.length
        ? _playing[_shown - 1]
        : null;
    // Пока идёт показ — здоровье по показанному шагу, потом — итог раунда.
    final hpA = playing && step != null ? step.hpA : fight.hpA;
    final hpD = playing && step != null ? step.hpD : fight.hpD;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          fight.finished
              ? 'Бой окончен'
              : 'Раунд ${fight.round + (playing ? 0 : 1)} из ${fight.rules.rounds}',
        ),
        leading: IconButton(
          tooltip: 'К дуэлям',
          onPressed: () => context.go('/duels'),
          icon: const Icon(LucideIcons.arrowLeft),
        ),
        actions: [
          // Облако встаёт под нажатым элементом: нужен контекст самой кнопки,
          // а не экрана (иначе оно уезжает за нижний край и не видно).
          Builder(
            builder: (button) => IconButton(
              tooltip: 'Кто кого бьёт',
              onPressed: () => showInfoBubble(
                button,
                title: 'Кто кого бьёт',
                text: combatMatchupText,
              ),
              icon: const Icon(LucideIcons.circleHelp, size: 20),
            ),
          ),
        ],
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
                      child: _Side(
                        fighter: fight.attacker,
                        look: hero.look,
                        hp: hpA,
                        max: fight.powerA,
                        player: true,
                        aura: playing
                            ? step?.auraOf(attacker: true)?.kind
                            : null,
                        auraKey: step == null ? 0 : step.round * 10 + step.step,
                        // Шаг для анимации: что сделал, сколько получил.
                        act: playing ? step?.a : null,
                        took: playing ? step?.toA ?? 0 : 0,
                        crit: playing && step?.outD == 'crit',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Side(
                        fighter: fight.defender,
                        look: fight.defender.lookOrStarter,
                        hp: hpD,
                        max: fight.powerD,
                        player: false,
                        aura: playing
                            ? step?.auraOf(attacker: false)?.kind
                            : null,
                        auraKey: step == null ? 0 : step.round * 10 + step.step,
                        act: playing ? step?.d : null,
                        took: playing ? step?.toD ?? 0 : 0,
                        crit: playing && step?.outA == 'crit',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (step != null && (playing || !fight.finished))
                _StepLine(step: step, fight: fight),
              const SizedBox(height: 8),
              if (playing)
                Align(
                  child: TextButton(
                    onPressed: _skip,
                    child: const Text('Пропустить'),
                  ),
                )
              else if (fight.finished)
                _Result(
                  fight: fight,
                  onDone: () {
                    ref.read(fightProvider.notifier).close();
                    context.go('/duels');
                  },
                )
              else
                _Planner(
                  rules: fight.rules,
                  chain: _chain,
                  sending: _sending,
                  onAdd: (a) => setState(() => _chain.add(a)),
                  onRemove: (i) => setState(() => _chain.removeAt(i)),
                  onClear: () => setState(_chain.clear),
                  onGo: _go,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({
    required this.fighter,
    required this.look,
    required this.hp,
    required this.max,
    required this.player,
    this.aura,
    this.auraKey = 0,
    this.act,
    this.took = 0,
    this.crit = false,
  });

  /// Действие бойца на показанном шаге (значок над героем) и полученный урон
  /// (встряска и «−9», крит — крупнее и красным).
  final String? act;
  final int took;
  final bool crit;

  /// Аура, горящая на показанном шаге: пламя вокруг героя.
  final AuraKind? aura;
  final int auraKey;

  final Fighter fighter;
  final AvatarLook look;
  final int hp;
  final int max;
  final bool player;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
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
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: max == 0 ? 0 : hp / max),
            duration: const Duration(milliseconds: 350),
            builder: (_, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 8,
              color: player ? accent : const Color(0xFFE5484D),
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
          child: Stack(
            fit: StackFit.expand,
            children: [
              _Shake(
                trigger: took > 0 ? auraKey : null,
                strength: crit ? 10 : 6,
                child: AuraHero(
                  // Длительная аура (ярость, стойкость) — одна анимация на весь срок.
                  key: ValueKey(
                    aura == null
                        ? 'none'
                        : (aura!.burst ? 'a$auraKey' : aura!.name),
                  ),
                  kind: aura,
                  burst: aura?.burst ?? false,
                  level: fighter.auraLevel,
                  child: player
                      ? avatar
                      : Transform.flip(flipX: true, child: avatar),
                ),
              ),
              if (CombatAction.byName(act) case final a?)
                Align(
                  alignment: Alignment.topCenter,
                  child: _ActBadge(key: ValueKey('b$auraKey'), action: a),
                ),
              if (took > 0)
                Align(
                  alignment: const Alignment(0, -0.2),
                  child: _DamagePop(
                    key: ValueKey('d$auraKey'),
                    damage: took,
                    crit: crit,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Шаг: что сделал каждый и чем кончилось.
class _StepLine extends StatelessWidget {
  const _StepLine({required this.step, required this.fight});

  final CombatStep step;
  final FightView fight;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    String side(String act, String out, int dmg) {
      final o = outcomeLabel(out);
      return '${stepActionLabel(act)}${o.isEmpty ? '' : ' — $o'}${dmg > 0 ? ', −$dmg' : ''}';
    }

    final event = step.eventId == null ? null : duelEventById(step.eventId!);
    final who = step.eventOwnerIsAttacker ? fight.attacker : fight.defender;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (attacker, f) in [
          (true, fight.attacker),
          (false, fight.defender),
        ])
          if (step.auraOf(attacker: attacker) case (:final kind, start: true))
            Text(
              '${f.name}: ${kind.label}! ${kind.effect.split(': ').last}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: kind.color,
              ),
            ),
        if (event != null)
          Text(
            event.phrase(who.name, female: who.isFemale),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        Text(
          'Шаг ${step.step + 1}',
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: Text(
                side(step.a, step.outA, step.toD),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: step.toD > 0 ? accent : AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                side(step.d, step.outD, step.toA),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: step.toA > 0
                      ? const Color(0xFFE5484D)
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

IconData _icon(CombatAction a) => switch (a) {
  CombatAction.body => LucideIcons.handFist,
  CombatAction.legs => LucideIcons.footprints,
  CombatAction.heavy => LucideIcons.hammer,
  CombatAction.grab => LucideIcons.grab,
  CombatAction.block => LucideIcons.shield,
  CombatAction.evade => LucideIcons.undo2,
};

/// Выбор цепочки: 5 ячеек и 6 действий. Тап по действию — в первую пустую ячейку,
/// тап по ячейке — убрать.
class _Planner extends StatelessWidget {
  const _Planner({
    required this.rules,
    required this.chain,
    required this.sending,
    required this.onAdd,
    required this.onRemove,
    required this.onClear,
    required this.onGo,
  });

  final CombatRules rules;
  final List<CombatAction> chain;
  final bool sending;
  final ValueChanged<CombatAction> onAdd;
  final ValueChanged<int> onRemove;
  final VoidCallback onClear;
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Твои ${rules.steps} действий на раунд — соперник выбирает свои одновременно',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < rules.steps; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: _Slot(
                  action: i < chain.length ? chain[i] : null,
                  index: i,
                  onTap: i < chain.length ? () => onRemove(i) : null,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.2,
          children: [
            for (final a in CombatAction.values)
              _ActionButton(
                action: a,
                enabled: !sending && rules.allows(chain, a),
                onTap: () => onAdd(a),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: chain.isEmpty || sending ? null : onClear,
                child: const Text(
                  'Сбросить',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: chain.length == rules.steps && !sending
                    ? onGo
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  minimumSize: const Size(0, 44),
                ),
                icon: sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.swords, size: 18),
                label: const Text('В бой', maxLines: 1),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.action, required this.index, this.onTap});

  final CombatAction? action;
  final int index;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final a = action;
    return Semantics(
      button: onTap != null,
      label: a == null
          ? 'Шаг ${index + 1}, пусто'
          : 'Шаг ${index + 1}: ${a.label}, убрать',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: MediaQuery.textScalerOf(context).scale(52),
          decoration: BoxDecoration(
            color: a == null ? Colors.transparent : AppColors.raised,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.hairline, width: 1.5),
          ),
          child: a == null
              ? Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_icon(a), size: 18),
                    const SizedBox(height: 2),
                    Text(
                      a.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.action,
    required this.enabled,
    required this.onTap,
  });

  final CombatAction action;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: action.hint,
    child: OutlinedButton.icon(
      onPressed: enabled ? onTap : null,
      onLongPress: () =>
          showInfoBubble(context, title: action.label, text: action.hint),
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.raised,
        padding: const EdgeInsets.symmetric(horizontal: 6),
      ),
      icon: Icon(_icon(action), size: 16),
      label: Text(
        action.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13),
      ),
    ),
  );
}

class _Result extends StatelessWidget {
  const _Result({required this.fight, required this.onDone});

  final FightView fight;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final won = fight.won == true;
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
                Text('+${fight.coins ?? 0}', style: figureStyle(size: 17)),
              ],
            ),
            if (fight.ladderNote case final note?) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(LucideIcons.trophy, size: 16, color: accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      note,
                      style: TextStyle(
                        fontSize: 14,
                        color: accent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 6),
            Text(
              won
                  ? 'Сила решает, но и выбор помог. Сила растёт только от тренировок.'
                  : 'Поражение ничего не отнимает. Попробуй другие цепочки — ИИ подстраивается под привычки — и тренируйся: сила главнее.',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onDone, child: const Text('К дуэлям')),
          ],
        ),
      ),
    );
  }
}

/// Встряска при попадании: короткая, крит — сильнее.
class _Shake extends StatelessWidget {
  const _Shake({required this.trigger, required this.child, this.strength = 6});

  final int? trigger;
  final double strength;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (trigger == null) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(trigger),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      builder: (_, t, c) => Transform.translate(
        offset: Offset(math.sin(t * math.pi * 4) * strength * (1 - t), 0),
        child: c,
      ),
      child: child,
    );
  }
}

/// Значок действия над бойцом: появляется и чуть подрастает.
class _ActBadge extends StatelessWidget {
  const _ActBadge({super.key, required this.action});

  final CombatAction action;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0.6, end: 1),
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeOutBack,
    builder: (_, s, c) => Transform.scale(scale: s, child: c),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.raised.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon(action), size: 14),
          const SizedBox(width: 4),
          Text(action.label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    ),
  );
}

/// «−9» вылетает вверх и тает; крит — крупнее и красным.
class _DamagePop extends StatelessWidget {
  const _DamagePop({super.key, required this.damage, required this.crit});

  final int damage;
  final bool crit;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 900),
    curve: Curves.easeOut,
    builder: (_, t, c) => Transform.translate(
      offset: Offset(0, -40 * t),
      child: Opacity(opacity: (1 - t * t).clamp(0, 1), child: c),
    ),
    child: Text(
      '−$damage',
      style: TextStyle(
        fontSize: crit ? 30 : 22,
        fontWeight: FontWeight.w800,
        color: crit ? const Color(0xFFFF4D4D) : AppColors.textPrimary,
        shadows: const [Shadow(blurRadius: 6, color: Colors.black)],
      ),
    ),
  );
}
