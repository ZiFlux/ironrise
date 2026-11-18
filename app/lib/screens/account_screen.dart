import '../l10n/tr.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/nickname.dart';
import '../net/api_client.dart';
import '../state/account_state.dart';
import '../theme.dart';
import '../widgets/format.dart';
import '../widgets/sign_up_card.dart';
import '../widgets/status_toast.dart';

/// Аккаунт: регистрация, вход и состояние синхронизации тренировок.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key, this.login = false});

  /// Открыть сразу на «Войти», а не на «Регистрации».
  final bool login;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Аккаунт'))),
      body: account.signedIn
          ? _SignedIn(account: account)
          : _SignInForm(account: account, login: login),
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
        ? tr('Синхронизация…')
        : account.error ??
              (synced == null
                  ? tr('Ещё не синхронизировано')
                  : tr('Синхронизировано {p1}{p2}', {
                      'p1': syncedWhen(synced),
                      'p2': account.lastReason == null
                          ? ''
                          : ' · ${account.lastReason!.label}',
                    }));
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
                    tr('Ждут отправки: {pending}', {
                      'pending': account.pending,
                    }),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
                if (account.rejected > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    tr(
                      'Сервер не принял: {rejected}. Опыт за них не начислен',
                      {'rejected': account.rejected},
                    ),
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
        Text(
          tr(
            'Опыт, серию, монеты, покупки и дуэли считает сервер: после синхронизации они берутся оттуда',
          ),
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: 16),
        Card(
          child: SwitchListTile(
            value: account.autoSync,
            onChanged: notifier.setAutoSync,
            title: Text(tr('Автосинхронизация')),
            subtitle: Text(
              account.autoSync
                  ? tr(
                      'При входе, после тренировок и покупок, каждые {inMinutes} минут, пока приложение открыто, и при сворачивании',
                      {'inMinutes': autoSyncEvery.inMinutes},
                    )
                  : tr(
                      'Выключена: тренировки отправляются при входе, остальное — кнопкой ниже',
                    ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: account.syncing ? null : notifier.sync,
          icon: const Icon(LucideIcons.refreshCw, size: 18),
          label: Text(tr('Синхронизировать')),
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: notifier.logout, child: Text(tr('Выйти'))),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => _deleteAccount(context, ref),
          child: Text(tr('Удалить аккаунт')),
        ),
      ],
    );
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (password == null || !context.mounted) return;
    try {
      await ref.read(accountProvider.notifier).deleteAccount(password);
      if (context.mounted) context.go('/onboarding');
    } on ApiException catch (e) {
      if (!context.mounted) return;
      showStatusError(
        e.status == 401 ? tr('Неверный пароль') : e.message,
        network: e.isNetwork,
      );
    }
  }
}

class _SignInForm extends ConsumerStatefulWidget {
  const _SignInForm({required this.account, this.login = false});

  final bool login;

  final AccountState account;

  @override
  ConsumerState<_SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends ConsumerState<_SignInForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  late bool _register = !widget.login;
  bool _busy = false;
  bool _showPassword = false;
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
        ? tr('Проверьте e-mail')
        : _register && password.length < 8
        ? tr('Пароль — не меньше 8 символов')
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
          0 => tr('Сервер недоступен. Проверьте сеть'),
          401 => tr('Неверный e-mail или пароль'),
          403 when e.isBanned => tr('Аккаунт заблокирован: {banReason}', {
            'banReason': e.banReason,
          }),
          409 when e.message == 'Email is taken' => tr(
            'Этот e-mail уже зарегистрирован',
          ),
          409 || 400 when nicknameServerError(e.message) != null => tr(
            '{p1}. Сменить ник: Профиль → Настройки',
            {'p1': nicknameServerError(e.message)},
          ),
          409 => tr('Такой e-mail или ник уже заняты'),
          400 => tr('Сервер не принял данные: {e}', {'e': e}),
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
    final accent = Theme.of(context).colorScheme.primary;
    // Регистрация и вход — одна форма; переключение ссылкой под кнопкой,
    // как привыкли в других приложениях, а не переключателем сверху.
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          _register ? tr('Сохрани героя') : tr('С возвращением'),
          style: const TextStyle(fontFamily: displayFont, fontSize: 26),
        ),
        const SizedBox(height: 6),
        Text(
          _register
              ? tr('Аккаунт за минуту — только e-mail и пароль')
              : tr('Опыт и серия загрузятся с сервера'),
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        if (_register) ...[
          const SizedBox(height: 16),
          SignUpPerksGrid(perks: signUpPerks.take(4).toList()),
        ],
        const SizedBox(height: 20),
        // Поля — одна группа автозаполнения, без подсказок и автозамены:
        // иначе на части клавиатур символ в пароле («-») закрывал клавиатуру.
        AutofillGroup(
          child: Column(
            children: [
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  hintText: 'E-mail',
                  prefixIcon: Icon(LucideIcons.mail, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: !_showPassword,
                keyboardType: TextInputType.visiblePassword,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: [
                  _register
                      ? AutofillHints.newPassword
                      : AutofillHints.password,
                ],
                decoration: InputDecoration(
                  hintText: _register
                      ? tr('Пароль, от 8 символов')
                      : tr('Пароль'),
                  prefixIcon: const Icon(LucideIcons.lock, size: 18),
                  suffixIcon: IconButton(
                    tooltip: _showPassword
                        ? tr('Скрыть пароль')
                        : tr('Показать пароль'),
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                    icon: Icon(
                      _showPassword ? LucideIcons.eyeOff : LucideIcons.eye,
                      size: 18,
                    ),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        // Ошибка формы или причина, по которой сессия закрылась (например, блокировка).
        if ((_error ?? widget.account.error) case final error?) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                LucideIcons.circleAlert,
                size: 16,
                color: Color(0xFFE5484D),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  error,
                  style: const TextStyle(
                    color: Color(0xFFE5484D),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
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
              : Text(_register ? tr('Создать аккаунт') : tr('Войти')),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              _register ? tr('Уже есть аккаунт?') : tr('Ещё нет аккаунта?'),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            TextButton(
              onPressed: () => setState(() {
                _register = !_register;
                _error = null;
              }),
              style: TextButton.styleFrom(foregroundColor: accent),
              child: Text(_register ? tr('Войти') : tr('Создать')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _register
              ? tr(
                  'Герой сохранится на сервере и будет доступен с другого телефона.{p1}',
                  {
                    'p1': pending > 0
                        ? tr(
                            ' Тренировки с этого телефона ({pending}) сервер пересчитает и перенесёт',
                            {'pending': pending},
                          )
                        : '',
                  },
                )
              : tr('Данные на этом телефоне заменятся данными с сервера'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

/// Удаление необратимо, поэтому просим пароль ещё раз.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(tr('Удалить аккаунт')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(
              'Аккаунт, герой, тренировки, пульс, друзья и покупки удалятся с сервера и телефона. Вернуть их не получится',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(labelText: tr('Пароль')),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('Отмена')),
        ),
        TextButton(
          onPressed: _password.text.isEmpty
              ? null
              : () => Navigator.pop(context, _password.text),
          child: Text(tr('Удалить навсегда')),
        ),
      ],
    );
  }
}

/// «в 14:05» сегодня, «вчера в 14:05», иначе «12 ноября в 14:05».
String syncedWhen(DateTime t) {
  final now = DateTime.now();
  final hm =
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(t.year, t.month, t.day)).inDays;
  return switch (days) {
    0 => tr('в {hm}', {'hm': hm}),
    1 => tr('вчера в {hm}', {'hm': hm}),
    _ => tr('{p1} в {hm}', {'p1': formatDate(t), 'hm': hm}),
  };
}
