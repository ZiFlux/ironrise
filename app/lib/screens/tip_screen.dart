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

  /// Порядок вариантов: перемешан по id совета — стабильно, но верный ответ
  /// не всегда первый.
  static List<int> _order(Tip tip) {
    int hash(String v) =>
        v.codeUnits.fold(7, (h, c) => (h * 31 + c) & 0x7fffffff);
    return List.generate(tip.question.options.length, (i) => i)
      ..sort((a, b) => hash('${tip.id}#$a').compareTo(hash('${tip.id}#$b')));
  }

  @override
  Widget build(BuildContext context) {
    final question = tip.question;
    final answered = answer != null;
    final correct = answer == question.correct;
    final accent = Theme.of(context).colorScheme.primary;
    final fact = tip.kind == TipKind.fact;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (fact ? accent : AppColors.textSecondary).withValues(
                  alpha: 0.14,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    fact ? LucideIcons.flaskConical : LucideIcons.lightbulb,
                    size: 14,
                    color: fact ? accent : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    tip.kind.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: fact ? accent : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (tip.figure case final figure?) ...[
          const SizedBox(height: 14),
          Text(figure, style: figureStyle(size: 44, color: accent)),
        ],
        const SizedBox(height: 10),
        Text(
          tip.title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 10),
        Text(
          tip.text,
          style: const TextStyle(
            fontSize: 16,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        if (tip.source case final source?) ...[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  LucideIcons.bookOpen,
                  size: 14,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  source,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.circleHelp, size: 16, color: accent),
                    const SizedBox(width: 8),
                    const Text(
                      'Проверь себя',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  question.text,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (!answered && reward != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    reward!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                for (final i in _order(tip))
                  _Option(
                    text: question.options[i],
                    state: !answered
                        ? _OptionState.open
                        : i == question.correct
                        ? _OptionState.correct
                        : i == answer
                        ? _OptionState.wrong
                        : _OptionState.idle,
                    onTap: answered ? null : () => onAnswer(i),
                  ),
                if (answered)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 6),
                    child: Row(
                      children: [
                        Icon(
                          correct ? LucideIcons.partyPopper : LucideIcons.info,
                          size: 16,
                          color: correct ? accent : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            correct ? 'Верно!' : 'Не совсем — правильный ответ отмечен галочкой',
                            style: TextStyle(
                              fontSize: 14,
                              color: correct ? accent : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
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
        color: AppColors.raised,
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
