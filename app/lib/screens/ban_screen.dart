import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/account_state.dart';
import '../theme.dart';
import '../widgets/beta_channel.dart';
import 'account_screen.dart';

/// Почта поддержки — та же, что на сайте.
final _supportMail = Uri.parse(
  'mailto:y.shatov@internet.ru?subject=IronRise: блокировка аккаунта',
);

/// Аккаунт заблокирован администратором: вместо приложения — причина и как
/// связаться. Выйти отсюда можно только входом в другой аккаунт.
/// Свой Navigator: экран живёт поверх роутера, а вход открывается поверх него.
class BanGate extends StatelessWidget {
  const BanGate({super.key});

  @override
  Widget build(BuildContext context) => Navigator(
    onGenerateRoute: (_) =>
        MaterialPageRoute(builder: (_) => const BanScreen()),
  );
}

class BanScreen extends ConsumerWidget {
  const BanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reason = ref.watch(banProvider) ?? '';
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(
                LucideIcons.shieldBan,
                size: 56,
                color: Color(0xFFFF6B5E),
              ),
              const SizedBox(height: 20),
              const Text(
                'Аккаунт заблокирован',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                reason.isEmpty ? 'Причина не указана.' : 'Причина: $reason',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Тренировки, дуэли и рейтинг недоступны. Если считаешь, '
                'что это ошибка, напиши нам — разберёмся.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => openBetaChannel(context),
                icon: const Icon(LucideIcons.send, size: 18),
                label: const Text('Написать в Telegram'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    launchUrl(_supportMail).catchError((_) => false),
                icon: const Icon(LucideIcons.mail, size: 18),
                label: const Text('Написать на почту'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AccountScreen(login: true),
                  ),
                ),
                style: TextButton.styleFrom(foregroundColor: accent),
                child: const Text('Войти в другой аккаунт'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
