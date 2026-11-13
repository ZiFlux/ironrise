import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme.dart';
import 'guide.dart';

/// Заглушка для разделов, которые работают только с аккаунтом (рейтинг, дуэли):
/// объясняет, зачем аккаунт, и ведёт на регистрацию или вход.
class SignInGate extends StatelessWidget {
  const SignInGate({
    super.key,
    required this.title,
    required this.icon,
    required this.text,
  });

  final String title;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(icon, size: 56, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  '$title — только для зарегистрированных',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                GuideTarget(
                  id: 'gate.register',
                  child: FilledButton.icon(
                    icon: const Icon(LucideIcons.userPlus),
                    label: const Text('Зарегистрироваться'),
                    onPressed: () => context.push('/profile/account'),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(LucideIcons.logIn),
                  label: const Text('Войти'),
                  onPressed: () => context.push('/profile/account?login=1'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
