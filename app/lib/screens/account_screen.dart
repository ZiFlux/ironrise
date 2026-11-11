import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../net/api_client.dart';
import '../state/account_state.dart';
import '../theme.dart';

/// Аккаунт: регистрация, вход и состояние синхронизации тренировок.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Аккаунт')),
      body: account.signedIn
          ? _SignedIn(account: account)
          : _SignInForm(account: account),
    );
  }
}

class _SignedIn extends ConsumerWidget {
  const _SignedIn({required this.account});

  final AccountState account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(accountProvider.notifier);
    final synced = account.lastSyncedAt;
    final status = account.syncing
        ? 'Синхронизация…'
        : account.error ??
              (synced == null
                  ? 'Ещё не синхронизировано'
                  : 'Синхронизировано в ${_time(synced)}');
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.email!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      account.error == null
                          ? LucideIcons.cloudCheck
                          : LucideIcons.cloudOff,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        status,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (account.pending > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Ждут отправки: ${account.pending}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
                if (account.rejected > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Сервер не принял: ${account.rejected}. Опыт за них не начислен',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Опыт и серию считает сервер: после синхронизации они берутся оттуда. '
          'Монеты, магазин и дуэли пока хранятся на телефоне',
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: account.syncing ? null : notifier.sync,
          icon: const Icon(LucideIcons.refreshCw, size: 18),
          label: const Text('Синхронизировать'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: notifier.logout, child: const Text('Выйти')),
      ],
    );
  }

  static String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _SignInForm extends ConsumerStatefulWidget {
  const _SignInForm({required this.account});

  final AccountState account;

  @override
  ConsumerState<_SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends ConsumerState<_SignInForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    final problem = !email.contains('@')
        ? 'Проверьте e-mail'
        : _register && password.length < 8
        ? 'Пароль — не меньше 8 символов'
        : null;
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final notifier = ref.read(accountProvider.notifier);
    try {
      _register
          ? await notifier.register(email, password)
          : await notifier.login(email, password);
    } on ApiException catch (e) {
      setState(
        () => _error = switch (e.status) {
          0 => 'Сервер недоступен. Проверьте сеть',
          401 => 'Неверный e-mail или пароль',
          409 => 'Такой e-mail или ник уже заняты',
          400 => 'Сервер не принял данные: $e',
          _ => e.message,
        },
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = widget.account.pending;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Регистрация')),
            ButtonSegment(value: false, label: Text('Вход')),
          ],
          selected: {_register},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() {
            _register = s.first;
            _error = null;
          }),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(hintText: 'E-mail'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: true,
          autofillHints: [
            _register ? AutofillHints.newPassword : AutofillHints.password,
          ],
          decoration: InputDecoration(
            hintText: _register ? 'Пароль, от 8 символов' : 'Пароль',
          ),
          onSubmitted: (_) => _submit(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(color: Color(0xFFE5484D), fontSize: 13),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_register ? 'Создать аккаунт' : 'Войти'),
        ),
        const SizedBox(height: 16),
        Text(
          _register
              ? 'Герой сохранится на сервере и будет доступен с другого телефона.'
                    '${pending > 0 ? ' Тренировки с этого телефона ($pending) сервер пересчитает и перенесёт' : ''}'
              : 'Опыт и серия загрузятся с сервера и заменят данные на этом телефоне',
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: 8),
        const Text(
          'Сервер: $apiBaseUrl',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
  }
}
