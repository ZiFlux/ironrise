import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/game_config.dart';
import '../state/tips_state.dart';
import '../theme.dart';

/// «Совет дня»: короткий текст и один вопрос по нему.
class TipScreen extends ConsumerWidget {
  const TipScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daily = ref.watch(tipsProvider);
    if (daily == null) return const SizedBox.shrink();
    final tip = daily.tip;
    final question = tip.question;

    return Scaffold(
      appBar: AppBar(title: const Text('Совет дня')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(tip.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          Text(tip.text, style: const TextStyle(fontSize: 16, height: 1.5, color: AppColors.textSecondary)),
          const SizedBox(height: 32),
          Text(question.text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(
            daily.answered ? '' : 'Правильный ответ — +${GameConfig.tipCoins} монет',
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          for (final (i, option) in question.options.indexed)
            _Option(
              text: option,
              state: !daily.answered
                  ? _OptionState.open
                  : i == question.correct
                  ? _OptionState.correct
                  : i == daily.answer
                  ? _OptionState.wrong
                  : _OptionState.idle,
              onTap: daily.answered ? null : () => ref.read(tipsProvider.notifier).answer(i),
            ),
          if (daily.answered) ...[
            const SizedBox(height: 16),
            Text(
              daily.correct
                  ? (daily.rewarded ? 'Верно: +${GameConfig.tipCoins} монет' : 'Верно')
                  : 'Не совсем. Правильный ответ отмечен — завтра будет новый совет',
              style: TextStyle(
                fontSize: 14,
                color: daily.correct ? Theme.of(context).colorScheme.primary : AppColors.textSecondary,
              ),
            ),
          ],
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
      _ => AppColors.hairline,
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
                Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
                if (state == _OptionState.correct) Icon(LucideIcons.check, size: 18, color: accent),
                if (state == _OptionState.wrong) const Icon(LucideIcons.x, size: 18, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
