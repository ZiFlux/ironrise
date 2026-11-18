import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/game_config.dart';
import '../game/tips.dart';
import '../state/tips_state.dart';
import '../theme.dart';
import '../widgets/status_toast.dart';

/// Советы дня: 3–5 коротких советов, по каждому вопрос. Листаются страницами,
/// после ответа — следующий; в конце итог опроса и монеты.
class TipScreen extends ConsumerStatefulWidget {
  const TipScreen({super.key});

  @override
  ConsumerState<TipScreen> createState() => _TipScreenState();
}

class _TipScreenState extends ConsumerState<TipScreen> {
  late int _page = _firstOpen();
  late final _pages = PageController(initialPage: _page);

  /// Открываем первый неотвеченный совет; всё отвечено — итог.
  int _firstOpen() {
    final daily = ref.read(tipsProvider);
    if (daily == null) return 0;
    final i = daily.tips.indexWhere((t) => !daily.answered(t));
    return i < 0 ? daily.tips.length : i;
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _answer(Tip tip, int option) async {
    await ref.read(tipsProvider.notifier).answer(tip, option);
    if (!mounted) return;
    final after = ref.read(tipsProvider);
    if (after != null && after.done && (after.coins ?? 0) > 0) {
      showStatus(
        'Опрос пройден: +${after.coins} монет',
        kind: StatusKind.reward,
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted || !_pages.hasClients) return;
    await _pages.nextPage(duration: AppMotion.enter, curve: AppMotion.curve);
  }

  @override
  Widget build(BuildContext context) {
    final daily = ref.watch(tipsProvider);
    if (daily == null) return const SizedBox.shrink();
    final accent = Theme.of(context).colorScheme.primary;
    final total = daily.tips.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _page >= total
              ? 'Советы дня · итог'
              : 'Советы дня · ${min(_page + 1, total)} из $total',
        ),
      ),
      body: Column(
        children: [
          // Полоски прогресса: верно, неверно, ещё нет.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                for (final (i, t) in daily.tips.indexed) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: !daily.answered(t)
                            ? (i == _page
                                  ? AppColors.textMuted
                                  : AppColors.raised)
                            : daily.correct(t)
                            ? accent
                            : const Color(0xFFFF6B5E),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pages,
              onPageChanged: (p) => setState(() => _page = p),
              children: [
                for (final tip in daily.tips)
                  _TipPage(
                    tip: tip,
                    answer: daily.answers[tip.id],
                    reward: daily.done
                        ? null
                        : 'За верный ответ — +${GameConfig.tipCoinsPerAnswer}, '
                              'за все верные ещё +${GameConfig.tipQuizBonus}',
                    onAnswer: (o) => _answer(tip, o),
                  ),
                _Summary(daily: daily),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TipPage extends StatelessWidget {
  const _TipPage({
    required this.tip,
    required this.answer,
    required this.reward,
    required this.onAnswer,
  });

  final Tip tip;
  final int? answer;
  final String? reward;
  final ValueChanged<int> onAnswer;

  @override
  Widget build(BuildContext context) {
    final question = tip.question;
    final answered = answer != null;
    final correct = answer == question.correct;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(
          tip.title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        Text(
          tip.text,
          style: const TextStyle(
            fontSize: 16,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          question.text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        if (!answered && reward != null) ...[
          const SizedBox(height: 4),
          Text(
            reward!,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
        const SizedBox(height: 12),
        for (final (i, option) in question.options.indexed)
          _Option(
            text: option,
            state: !answered
                ? _OptionState.open
                : i == question.correct
                ? _OptionState.correct
                : i == answer
                ? _OptionState.wrong
                : _OptionState.idle,
            onTap: answered ? null : () => onAnswer(i),
          ),
        if (answered) ...[
          const SizedBox(height: 12),
          Text(
            correct ? 'Верно' : 'Не совсем — правильный ответ отмечен',
            style: TextStyle(
              fontSize: 14,
              color: correct
                  ? Theme.of(context).colorScheme.primary
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// Итог опроса: сколько верных и сколько монет.
class _Summary extends StatelessWidget {
  const _Summary({required this.daily});

  final DailyTips daily;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final left = daily.tips.length - daily.answeredCount;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            daily.done ? LucideIcons.trophy : LucideIcons.listChecks,
            size: 40,
            color: daily.done ? accent : AppColors.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            daily.done
                ? 'Верно ${daily.correctCount} из ${daily.tips.length}'
                : 'Осталось ответить: $left',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            !daily.done
                ? 'Вернись к пропущенным советам — листай назад'
                : (daily.coins ?? 0) > 0
                ? '+${daily.coins} монет. Завтра — новая подборка'
                : 'Монеты за сегодня уже получены. Завтра — новая подборка',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

enum _OptionState { open, idle, correct, wrong }

class _Option extends StatelessWidget {
  const _Option({required this.text, required this.state, required this.onTap});

  final String text;
  final _OptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final border = switch (state) {
      _OptionState.correct => accent,
      _OptionState.wrong => AppColors.textMuted,
      _ => Colors.transparent,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(text, style: const TextStyle(fontSize: 15)),
                ),
                if (state == _OptionState.correct)
                  Icon(LucideIcons.check, size: 18, color: accent),
                if (state == _OptionState.wrong)
                  const Icon(
                    LucideIcons.x,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
