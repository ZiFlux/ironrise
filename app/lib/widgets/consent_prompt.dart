import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../state/consent_state.dart';
import '../theme.dart';

/// Текст согласия на пульс — один и тот же в онбординге, вопросе и настройках.
const healthConsentTitle = 'Согласен на обработку данных о пульсе';
const healthConsentDetails =
    'Пульс — данные о здоровье. Он нужен, чтобы проверять, что тренировка была '
    'на самом деле. Без согласия тренировки засчитываются без проверки пульсом, '
    'а пульс не собирается и не отправляется';

/// Один раз спрашивает согласие у тех, кто начал до появления вопроса в онбординге.
class ConsentPrompt extends ConsumerStatefulWidget {
  const ConsentPrompt({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ConsentPrompt> createState() => _ConsentPromptState();
}

class _ConsentPromptState extends ConsumerState<ConsentPrompt> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ref.read(healthConsentProvider).asked) return;
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) => const _ConsentSheet(),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ConsentSheet extends ConsumerWidget {
  const _ConsentSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> answer(bool granted) async {
      await ref.read(healthConsentProvider.notifier).set(granted);
      if (context.mounted) Navigator.pop(context);
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(
                  LucideIcons.heartPulse,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Данные о пульсе',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              healthConsentDetails,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => context.push('/privacy'),
                child: const Text('Политика конфиденциальности'),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => answer(true),
              child: const Text('Согласен'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => answer(false),
              child: const Text('Без пульса'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Переключатель согласия для настроек.
class HealthConsentTile extends ConsumerWidget {
  const HealthConsentTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consent = ref.watch(healthConsentProvider);
    return SwitchListTile(
      value: consent.allowsPulse,
      onChanged: (v) => ref.read(healthConsentProvider.notifier).set(v),
      secondary: const Icon(
        LucideIcons.heartPulse,
        size: 18,
        color: AppColors.textSecondary,
      ),
      title: const Text('Данные о пульсе'),
      subtitle: Text(
        consent.allowsPulse
            ? 'Согласие дано: пульс проверяет тренировки'
            : 'Нет согласия: тренировки без проверки пульсом',
        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
    );
  }
}
