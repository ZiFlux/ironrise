import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../avatar/avatar_view.dart';
import '../game/duel.dart';
import '../net/api_client.dart';
import '../state/account_state.dart';
import '../state/duel_state.dart';
import '../state/providers.dart';
import '../state/server_game.dart';
import '../theme.dart';
import '../widgets/fit_screen.dart';

/// Дуэли (экран 9). С аккаунтом — боты дня и друзья через сервер,
/// без аккаунта — локальные боты.
class DuelsScreen extends ConsumerStatefulWidget {
  const DuelsScreen({super.key});

  @override
  ConsumerState<DuelsScreen> createState() => _DuelsScreenState();
}

class _DuelsScreenState extends ConsumerState<DuelsScreen> {
  bool _friendsTab = false;

  Future<void> _open(Future<DuelResult?> Function() fight) async {
    try {
      final r = await fight();
      if (r != null && mounted) context.go('/duels/battle');
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.isNetwork ? 'Нет связи с сервером' : e.message),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hero = ref.watch(heroProvider);
    if (hero == null) return const SizedBox.shrink();
    final me = playerFighter(hero);
    final duels = ref.read(duelProvider.notifier);

    if (!ref.watch(accountProvider).signedIn) {
      ref.watch(duelProvider);
      final bots = DuelBots.forDay(me, DateTime.now());
      return _Page(
        body: _FighterList(
          me: me,
          fighters: bots,
          results: duels.today,
          counter: 'боёв ${duels.today.length} из ${bots.length}',
          footer: 'Новые соперники каждый день. Войди в аккаунт, чтобы драться с друзьями',
          onFight: (bot) => _open(() => duels.fight(bot)),
        ),
      );
    }

    final friends = ref.watch(serverFriendsProvider);
    final incoming = friends.value?.incoming.length ?? 0;
    return _Page(
      actions: [
        IconButton(
          tooltip: 'Друзья',
          onPressed: () => context.go('/duels/friends'),
          icon: Badge(
            isLabelVisible: incoming > 0,
            label: Text('$incoming'),
            child: const Icon(LucideIcons.userPlus, size: 20),
          ),
        ),
        const SizedBox(width: 8),
      ],
      header: SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false, label: Text('Боты дня')),
          ButtonSegment(value: true, label: Text('Друзья')),
        ],
        selected: {_friendsTab},
        showSelectedIcon: false,
        onSelectionChanged: (s) => setState(() => _friendsTab = s.first),
      ),
      body: _friendsTab
          ? friends.when(
              data: (d) => d.friends.isEmpty
                  ? _Empty(onFind: () => context.go('/duels/friends'))
                  : _FighterList(
                      me: me,
                      fighters: d.friends,
                      results: d.results,
                      counter: 'осталось боёв: ${d.fightsLeft}',
                      footer: 'С каждым другом — один бой в день. Друг может быть не в сети',
                      scrollable: true,
                      onFight: (f) => _open(() => duels.fightFriendOnServer(f)),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  _Retry(onRetry: () => ref.invalidate(serverFriendsProvider)),
            )
          : ref
                .watch(serverBotsProvider)
                .when(
                  data: (d) => _FighterList(
                    me: me,
                    fighters: d.bots,
                    results: d.results,
                    counter: 'боёв ${d.results.length} из ${d.bots.length}',
                    footer: 'Новые соперники каждый день',
                    onFight: (bot) => _open(() => duels.fightOnServer(bot)),
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      _Retry(onRetry: () => ref.invalidate(serverBotsProvider)),
                ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.body, this.header, this.actions});

  final Widget body;
  final Widget? header;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Дуэли'), actions: actions),
    body: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header != null) ...[header!, const SizedBox(height: 8)],
            Expanded(child: body),
          ],
        ),
      ),
    ),
  );
}

class _Retry extends StatelessWidget {
  const _Retry({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Нет связи с сервером',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: onRetry, child: const Text('Повторить')),
      ],
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onFind});

  final VoidCallback onFind;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(LucideIcons.users, size: 40, color: AppColors.textMuted),
        const SizedBox(height: 12),
        const Text(
          'Пока нет друзей',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        const Text(
          'Найди друга по нику и вызови на дуэль',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onFind,
          style: FilledButton.styleFrom(minimumSize: const Size(200, 48)),
          icon: const Icon(LucideIcons.userPlus, size: 18),
          label: const Text('Найти друзей'),
        ),
      ],
    ),
  );
}

/// Сила игрока и соперники. Ботов всегда 4 — они делят экран без прокрутки;
/// друзей может быть много, тогда список прокручивается внутри.
class _FighterList extends StatelessWidget {
  const _FighterList({
    required this.me,
    required this.fighters,
    required this.results,
    required this.counter,
    required this.footer,
    required this.onFight,
    this.scrollable = false,
  });

  final Fighter me;
  final List<Fighter> fighters;
  final Map<String, bool> results;
  final String counter;
  final String footer;
  final void Function(Fighter) onFight;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    Widget card(Fighter f) => _FighterCard(
      fighter: f,
      myPower: me.power,
      result: results[f.id],
      onFight: () => onFight(f),
    );
    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(LucideIcons.zap, size: 18, color: accent),
                const SizedBox(width: 8),
                Text(
                  '${me.power}',
                  style: figureStyle(size: 20, color: accent),
                ),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    'твоя сила',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    counter,
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (scrollable)
          Expanded(
            child: ListView.separated(
              itemCount: fighters.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              // Крупный системный шрифт — карточка выше, иначе текст не влезет.
              itemBuilder: (_, i) => SizedBox(
                height: MediaQuery.textScalerOf(context).scale(72),
                child: card(fighters[i]),
              ),
            ),
          )
        else
          for (final f in fighters)
            FlexibleMin(
              minHeight: MediaQuery.textScalerOf(context).scale(72),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: card(f),
              ),
            ),
        const SizedBox(height: 4),
        Text(
          footer,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
    // Боты (их 4) делят экран; не влезают — прокрутка. Друзья прокручиваются списком.
    return scrollable ? list : FitScreen(child: list);
  }
}

class _FighterCard extends StatelessWidget {
  const _FighterCard({
    required this.fighter,
    required this.myPower,
    required this.result,
    required this.onFight,
  });

  final Fighter fighter;
  final int myPower;
  final bool? result;
  final VoidCallback onFight;

  String get _strength {
    final ratio = fighter.power / myPower;
    if (ratio < 0.93) return 'слабее';
    if (ratio > 1.07) return 'сильнее';
    return 'на равных';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: AvatarView(
                levels: fighter.levels,
                look: fighter.lookOrStarter,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fighter.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'сила ${fighter.power} · $_strength',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
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
    final color = won
        ? Theme.of(context).colorScheme.primary
        : AppColors.textMuted;
    return Text(
      text,
      style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w500),
    );
  }
}
