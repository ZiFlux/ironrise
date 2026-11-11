import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../avatar/avatar_look.dart';
import '../avatar/avatar_view.dart';
import '../game/duel.dart';
import '../state/duel_state.dart';
import '../state/providers.dart';
import '../theme.dart';

/// Дуэли (экран 9). Пока без сервера — против ботов, подобранных по силе.
class DuelsScreen extends ConsumerWidget {
  const DuelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hero = ref.watch(heroProvider);
    if (hero == null) return const SizedBox.shrink();
    ref.watch(duelProvider);
    final results = ref.read(duelProvider.notifier).today;
    final me = playerFighter(hero);
    final bots = DuelBots.forDay(me, DateTime.now());
    final accent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Дуэли')),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(LucideIcons.zap, size: 18, color: accent),
                      const SizedBox(width: 8),
                      Text('${me.power}', style: figureStyle(size: 20, color: accent)),
                      const SizedBox(width: 8),
                      const Text('твоя сила',
                          style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                      const Spacer(),
                      Text('боёв ${results.length} из ${bots.length}',
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final bot in bots)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _BotCard(
                      bot: bot,
                      myPower: me.power,
                      result: results[bot.id],
                      onFight: () async {
                        final r = await ref.read(duelProvider.notifier).fight(bot);
                        if (r != null && context.mounted) context.go('/duels/battle');
                      },
                    ),
                  ),
                ),
              const Text(
                'Новые соперники каждый день. Бои с друзьями появятся вместе с сервером',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotCard extends StatelessWidget {
  const _BotCard({
    required this.bot,
    required this.myPower,
    required this.result,
    required this.onFight,
  });

  final Fighter bot;
  final int myPower;
  final bool? result;
  final VoidCallback onFight;

  String get _strength {
    final ratio = bot.power / myPower;
    if (ratio < 0.93) return 'слабее';
    if (ratio > 1.07) return 'сильнее';
    return 'на равных';
  }

  @override
  Widget build(BuildContext context) {
    final look = AvatarLook.starter(bot.isFemale ? AvatarSex.female : AvatarSex.male);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
        child: Row(
          children: [
            SizedBox(width: 48, child: AvatarView(levels: bot.levels, look: look)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bot.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text('сила ${bot.power} · $_strength',
                      style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                ],
              ),
            ),
            switch (result) {
              null => FilledButton(
                  onPressed: onFight,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(88, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('В бой'),
                ),
              true => const _ResultTag('Победа', true),
              false => const _ResultTag('Поражение', false),
            },
          ],
        ),
      ),
    );
  }
}

class _ResultTag extends StatelessWidget {
  const _ResultTag(this.text, this.won);

  final String text;
  final bool won;

  @override
  Widget build(BuildContext context) {
    final color = won ? Theme.of(context).colorScheme.primary : AppColors.textMuted;
    return Text(text, style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w500));
  }
}
