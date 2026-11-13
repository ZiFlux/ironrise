import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../avatar/avatar_view.dart';
import '../game/aura.dart';
import '../net/api_client.dart';
import '../state/account_state.dart';
import '../state/aura_state.dart';
import '../state/heart_rate_state.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../widgets/aura_flame.dart';
import '../widgets/sign_in_gate.dart';
import '../widgets/status_toast.dart';

/// Ауры для дуэлей: выбрать одну, прокачивать особыми тренировками 2 раза в неделю.
class AuraScreen extends ConsumerWidget {
  const AuraScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(accountProvider).signedIn) {
      return const SignInGate(
        title: 'Ауры',
        icon: LucideIcons.flame,
        text:
            'Аура вспыхивает в дуэли один раз за бой: ярость, стойкость, скорость '
            'или фокус. Прокачивается особыми тренировками дважды в неделю.',
      );
    }
    final info = ref.watch(auraProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ауры')),
      body: info.when(
        data: (a) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            Text(
              'Аура срабатывает в дуэли один раз: когда здоровья меньше 65 % '
              'или осталось 3 раунда. Тренировок ауры на этой неделе: '
              '${a.sessionsThisWeek} из ${a.perWeek}, не чаще раза в день — '
              'отдельно от основных. Засчитываются с пульсом с часов или датчика.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            for (final p in a.auras)
              _AuraCard(
                progress: p,
                equipped: a.equipped == p.kind,
                canTrain: a.canTrain,
                limitLabel: a.trainedToday ? 'Завтра' : 'Лимит недели',
              ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(auraProvider),
            child: const Text('Не удалось загрузить — повторить'),
          ),
        ),
      ),
    );
  }
}

class _AuraCard extends ConsumerWidget {
  const _AuraCard({
    required this.progress,
    required this.equipped,
    required this.canTrain,
    required this.limitLabel,
  });

  final AuraProgress progress;
  final bool equipped;
  final bool canTrain;
  final String limitLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = progress.kind;
    final hero = ref.watch(heroProvider);
    final open = progress.level > 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: equipped ? kind.color : AppColors.hairline,
          width: equipped ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              height: 104,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hero != null)
                    AuraHero(
                      kind: open ? kind : null,
                      child: AvatarView(
                        levels: hero.avatarLevels,
                        look: hero.look,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.flame, size: 16, color: kind.color),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          kind.label,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        open ? 'ур. ${progress.level}' : 'закрыта',
                        style: figureStyle(
                          size: 13,
                          color: open ? kind.color : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    kind.effect,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    progress.toNext == null
                        ? 'Максимальный уровень'
                        : open
                        ? 'До уровня ${progress.level + 1}: ${progress.toNext} трен.'
                        : 'Откроется после первой тренировки',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      FilledButton.tonal(
                        onPressed: canTrain
                            ? () => context.push('/duels/auras/${kind.name}')
                            : null,
                        child: Text(canTrain ? 'Тренировка' : limitLabel),
                      ),
                      if (open)
                        OutlinedButton(
                          onPressed: () => ref
                              .read(auraProvider.notifier)
                              .equip(equipped ? null : kind),
                          child: Text(equipped ? 'Снять' : 'Выбрать'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Тренировка ауры: комплекс по таймеру — работа, отдых, следующий круг.
class AuraTrainingScreen extends ConsumerStatefulWidget {
  const AuraTrainingScreen({super.key, required this.kind});

  final AuraKind kind;

  @override
  ConsumerState<AuraTrainingScreen> createState() => _AuraTrainingState();
}

typedef _Step = ({String title, int seconds, bool rest});

class _AuraTrainingState extends ConsumerState<AuraTrainingScreen> {
  late final List<_Step> _steps = [
    for (var r = 0; r < AuraKind.rounds; r++)
      for (final (i, m) in widget.kind.moves.indexed) ...[
        (title: m.name, seconds: m.seconds, rest: false),
        if (r < AuraKind.rounds - 1 || i < widget.kind.moves.length - 1)
          (title: 'Отдых', seconds: AuraKind.restSeconds, rest: true),
      ],
  ];

  Timer? _timer;
  DateTime? _startedAt;
  int _index = -1;
  int _left = 0;
  bool _saving = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _startedAt = DateTime.now();
    // Часы начинают передавать пульс — он подтверждает тренировку ауры.
    ref.read(heartRateProvider.notifier).startWatch();
    setState(() {
      _index = 0;
      _left = _steps[0].seconds;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (_left > 1) {
      setState(() => _left--);
      return;
    }
    if (_index + 1 < _steps.length) {
      setState(() {
        _index++;
        _left = _steps[_index].seconds;
      });
    } else {
      _timer?.cancel();
      _finish();
    }
  }

  void _skip() => setState(() => _left = 1);

  Future<void> _finish() async {
    setState(() => _saving = true);
    final end = DateTime.now();
    final hr = ref.read(heartRateProvider.notifier);
    final pulse = hr.samplesBetween(_startedAt ?? end, end);
    await hr.stopWatch();
    try {
      await ref
          .read(auraProvider.notifier)
          .train(
            widget.kind,
            startedAt: _startedAt ?? end,
            finishedAt: end,
            pulse: pulse,
          );
      showStatus(
        'Аура «${widget.kind.label}» прокачана',
        kind: StatusKind.success,
      );
      if (mounted) context.pop();
    } on ApiException catch (e) {
      showStatusError(switch (e.status) {
        422 when e.message.contains('6-40') =>
          'Тренировка короче 6 минут — не засчитана',
        422 => 'Нет пульса с часов — тренировка ауры не засчитана',
        409 => 'Тренировка ауры уже была — следующая завтра',
        _ => 'Нет связи с сервером — попробуйте ещё раз',
      }, network: e.isNetwork);
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final hero = ref.watch(heroProvider);
    final started = _index >= 0;
    final step = started ? _steps[_index] : null;
    final next = started && _index + 1 < _steps.length
        ? _steps[_index + 1]
        : null;
    return Scaffold(
      appBar: AppBar(title: Text('Аура: ${kind.label}')),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Пока идёт работа — аура горит.
                    if (hero != null)
                      AuraHero(
                        kind: started && !step!.rest ? kind : null,
                        child: AvatarView(
                          levels: hero.avatarLevels,
                          look: hero.look,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (!started) ...[
                // Описание прокручивается на маленьком экране; кнопка — всегда видна.
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          kind.trainingTitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          [
                            for (final m in kind.moves)
                              '${m.name} — ${m.seconds} с',
                          ].join('\n'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${AuraKind.rounds} круга, отдых ${AuraKind.restSeconds} с · '
                          '~${(kind.totalSeconds / 60).round()} мин. Наденьте часы: '
                          'без пульса тренировка не засчитается',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _start, child: const Text('Начать')),
              ] else ...[
                Text(
                  step!.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: step.rest ? AppColors.textSecondary : kind.color,
                  ),
                ),
                Text(
                  '$_left',
                  textAlign: TextAlign.center,
                  style: figureStyle(size: 56),
                ),
                Text(
                  next == null ? 'Последнее' : 'Дальше: ${next.title}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 12),
                if (_saving)
                  const Center(child: CircularProgressIndicator())
                else
                  TextButton(onPressed: _skip, child: const Text('Дальше')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
