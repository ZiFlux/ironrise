import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/goal_path.dart';
import '../state/rest_state.dart';
import '../game/body_part.dart';
import '../net/api_client.dart';
import '../net/app_log.dart';
import '../game/cardio.dart';
import '../game/program.dart';
import '../game/session_builder.dart';
import '../game/training_format.dart';
import '../state/account_state.dart';
import '../state/calendar_export.dart';
import '../state/hero.dart';
import '../state/local_data.dart';
import '../state/program_state.dart';
import '../state/providers.dart';
import '../state/settings.dart';
import '../state/tips_state.dart';
import '../state/server_game.dart';
import '../theme.dart';
import '../widgets/beta_channel.dart';
import '../widgets/consent_prompt.dart';
import '../widgets/goals_picker.dart';
import '../widgets/guide.dart';
import '../widgets/screen_hint.dart';
import 'account_screen.dart' show syncedWhen;
import 'devices_screen.dart';
import '../widgets/format.dart';
import '../widgets/motion.dart';
import '../widgets/nickname_dialog.dart';
import '../widgets/status_toast.dart';

/// Настройки и конфиденциальность: всё, что не про самого игрока.
/// Вход — шестерёнка в профиле игрока.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hero = ref.watch(heroProvider);
    if (hero == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки и конфиденциальность')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _HeroInfo(hero: hero),
          const SizedBox(height: 24),
          // Сначала подключения — их ищут чаще всего; юридическое — в самом низу.
          const _SectionLabel('Подключения'),
          Card(
            child: Column(
              children: [
                _NavTile(
                  icon: LucideIcons.cloud,
                  title: 'Аккаунт и синхронизация',
                  subtitle: _accountLine(ref.watch(accountProvider)),
                  path: '/profile/account',
                ),
                const Divider(height: 1),
                _NavTile(
                  icon: LucideIcons.watch,
                  title: 'Часы и телефон',
                  subtitle: devicesSummary(ref),
                  path: '/profile/devices',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Сообщество'),
          const BetaChannelTile(),
          const SizedBox(height: 24),
          const _SectionLabel('Где тренируешься'),
          const _EquipmentPicker(),
          // Средним — попробовать ритм опытных: силовые и разгрузочные.
          if (trainingLevelOf(hero, ref.watch(programProvider)) ==
              TrainingLevel.intermediate) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ритм опытных'),
              subtitle: const Text(
                'Каждая 4-я тренировка силовая, после 4 недель — разгрузочная неделя',
              ),
              value: ref.watch(programProvider).rhythmTrial,
              onChanged: (on) =>
                  ref.read(programProvider.notifier).setRhythmTrial(on),
            ),
          ],
          const _RestTile(),
          // Тренировки в календарь телефона — он синхронизируется на часы.
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Тренировки в календарь'),
            subtitle: const Text(
              'Событие с временем начала и конца — видно и на часах',
            ),
            value: ref.watch(calendarExportProvider),
            onChanged: (on) async {
              final ok = await ref
                  .read(calendarExportProvider.notifier)
                  .setEnabled(on);
              if (!ok) showStatusError('Нужен доступ к календарю');
            },
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Пульсовые зоны'),
          _HeartZones(hero: hero),
          const SizedBox(height: 24),
          const _SectionLabel('Цвет интерфейса'),
          const _AccentPicker(),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                await ScreenHint.resetAll(ref);
                await TabGuide.resetAll(ref);
                if (context.mounted) {
                  showStatus(
                    'Подсказки снова появятся на экранах',
                    kind: StatusKind.success,
                  );
                }
              },
              icon: const Icon(LucideIcons.lightbulb, size: 18),
              label: const Text('Показать подсказки снова'),
            ),
          ),
          const SizedBox(height: 12),
          const _SectionLabel('Данные и конфиденциальность'),
          const _DataSection(),
          const SizedBox(height: 8),
          const _LogsToggle(),
          if (kDebugMode) ...[
            const SizedBox(height: 32),
            const _SectionLabel('Режим разработчика'),
            _DebugTools(hero: hero),
          ],
        ].indexed.map((e) => FadeSlideIn(index: e.$1, child: e.$2)).toList(),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
    ),
  );
}

class _HeroInfo extends StatelessWidget {
  const _HeroInfo({required this.hero});

  final HeroProfile hero;

  @override
  Widget build(BuildContext context) {
    final body = hero.body;
    final bodyText = [
      if (body.sex != null) body.sex!.label,
      if (body.heightCm != null) '${body.heightCm} см',
      if (body.weightKg != null) '${formatWeight(body.weightKg!)} кг',
    ].join(', ');
    // Формат и дни меняются на отдельном экране (раз в неделю).
    void schedule() => context.push('/profile/settings/schedule');
    final rows = <(String, String, VoidCallback?)>[
      ('Ник', hero.nickname, () => showNicknameDialog(context)),
      (
        hero.extraGoals.isEmpty ? 'Цель' : 'Цели',
        [hero.goal, ...hero.extraGoals].map((g) => g.label).join(', '),
        () => showGoalsSheet(context),
      ),
      ('Формат', hero.format.label, schedule),
      (
        'Дни',
        hero.trainingDays.map((d) => weekdayShort[d]).join(' '),
        schedule,
      ),
      ('Комплекция', bodyText.isEmpty ? 'не указана' : bodyText, null),
    ];
    return Card(
      child: Column(
        children: [
          for (final (label, value, onTap) in rows)
            InkWell(
              onTap: onTap,
              // Крупный шрифт — строка выше, подпись ужимается, а не вылезает (п. 78).
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          value,
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (onTap != null) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          LucideIcons.chevronRight,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Возраст и пульс покоя: от них считаются зона кардио и проверка пульса.
class _HeartZones extends ConsumerWidget {
  const _HeartZones({required this.hero});

  final HeroProfile hero;

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String hint,
    required int? current,
    required int min,
    required int max,
    required BodyStats Function(int) apply,
  }) async {
    final controller = TextEditingController(text: current?.toString() ?? '');
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: hint,
            helperText: 'от $min до $max',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              final v = int.tryParse(controller.text);
              if (v != null && v >= min && v <= max) Navigator.pop(context, v);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (value == null) return;
    await ref.read(heroProvider.notifier).setBody(apply(value));
  }

  Future<void> _pickExperience(
    BuildContext context,
    WidgetRef ref,
    BodyStats body,
  ) async {
    final picked = await showDialog<Experience>(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Опыт тренировок'),
        children: [
          for (final e in Experience.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, e),
              child: Text(e.label),
            ),
        ],
      ),
    );
    if (picked == null) return;
    await ref
        .read(heroProvider.notifier)
        .setBody(body.copyWith(experience: picked));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final body = hero.body;
    final zone = CardioScoring.zoneLowerBound(
      resting: hero.restingHeartRate,
      max: hero.maxHeartRate,
    );
    Widget row(String label, String value, VoidCallback onTap) => InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(width: 8),
              Text(value),
              const SizedBox(width: 8),
              const Icon(
                LucideIcons.pencil,
                size: 14,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row(
            'Возраст',
            body.age == null ? 'не указан' : '${body.age}',
            () => _edit(
              context,
              ref,
              title: 'Возраст',
              hint: 'лет',
              current: body.age,
              min: 18,
              max: 90,
              apply: (v) => body.copyWith(age: v),
            ),
          ),
          row(
            'Пульс покоя',
            body.restingHeartRate == null
                ? 'не указан'
                : '${body.restingHeartRate} уд/мин',
            () => _edit(
              context,
              ref,
              title: 'Пульс покоя',
              hint: 'утром, лёжа, уд/мин',
              current: body.restingHeartRate,
              min: 35,
              max: 110,
              apply: (v) => body.copyWith(restingHeartRate: v),
            ),
          ),
          // Опыт и самопроверка задают уровень: сколько упражнений и насколько сложных.
          row(
            'Опыт тренировок',
            body.experience?.label ?? 'не указан',
            () => _pickExperience(context, ref, body),
          ),
          row(
            'Отжиманий за подход',
            body.pushUps == null ? 'не указано' : '${body.pushUps}',
            () => _edit(
              context,
              ref,
              title: 'Отжиманий за подход',
              hint: 'сколько раз подряд',
              current: body.pushUps,
              min: 0,
              max: 150,
              apply: (v) => body.copyWith(pushUps: v),
            ),
          ),
          row(
            'Подтягиваний за подход',
            body.pullUps == null ? 'не указано' : '${body.pullUps}',
            () => _edit(
              context,
              ref,
              title: 'Подтягиваний за подход',
              hint: 'сколько раз подряд',
              current: body.pullUps,
              min: 0,
              max: 60,
              apply: (v) => body.copyWith(pullUps: v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Text(
              'Макс. пульс ${hero.maxHeartRate}, зона 2 для кардио — от $zone уд/мин'
              '${body.age == null || body.restingHeartRate == null ? '. Пока по средним значениям' : ''}',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccentPicker extends ConsumerWidget {
  const _AccentPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(accentProvider);
    return Row(
      children: [
        for (final option in AccentOption.values) ...[
          Expanded(
            child: _AccentSwatch(
              option: option,
              selected: option == selected,
              onTap: () => ref.read(accentProvider.notifier).select(option),
            ),
          ),
          if (option != AccentOption.values.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final AccentOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: option.label,
      child: Material(
        color: selected ? AppColors.raised : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? option.color : AppColors.hairline),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: option.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 6),
                Text(option.label, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DebugTools extends ConsumerWidget {
  const _DebugTools({required this.hero});

  static const _devCoins = 1000;

  /// Показать смену лиги и плашку итога недели, не дожидаясь понедельника.
  Future<void> _shiftLeague(
    BuildContext context,
    WidgetRef ref,
    int shift,
  ) async {
    if (!ref.read(accountProvider).signedIn) {
      showStatus(
        'Лиги работают с аккаунтом: войдите в «Аккаунт и синхронизация»',
      );
      return;
    }
    try {
      await ref.read(apiProvider).post('/v1/dev/league', {'shift': shift});
      ref.invalidate(serverLeagueProvider);
      showStatus(
        'Готово: откройте вкладку «Рейтинг»',
        kind: StatusKind.success,
      );
    } on ApiException catch (e) {
      showStatusError(
        e.status == 404
            ? 'Это доступно только на сервере разработки'
            : e.message,
        network: e.isNetwork,
      );
    }
  }

  /// С аккаунтом монеты считает сервер: выдаёт сервер разработки, без аккаунта — телефон.
  Future<void> _grantCoins(BuildContext context, WidgetRef ref) async {
    if (!ref.read(accountProvider).signedIn) {
      await ref.read(heroProvider.notifier).addCoins(_devCoins);
      return;
    }
    try {
      await ref.read(apiProvider).post('/v1/dev/coins', {'amount': _devCoins});
      await ref.read(accountProvider.notifier).sync();
    } on ApiException catch (e) {
      if (!context.mounted) return;
      showStatusError(
        e.status == 404 ? 'На этом сервере выдача монет выключена' : e.message,
        network: e.isNetwork,
      );
    }
  }

  final HeroProfile hero;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(heroProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final part in BodyPart.values)
              ActionChip(
                avatar: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: part.color,
                    shape: BoxShape.circle,
                  ),
                ),
                label: Text('${part.label} +100'),
                onPressed: () => notifier.debugAddXp(part, 100),
              ),
            ActionChip(
              avatar: const Icon(LucideIcons.flame, size: 16),
              label: const Text('Серия +5'),
              onPressed: () => notifier.debugSetStreak(hero.streakDays + 5),
            ),
            ActionChip(
              avatar: const Icon(LucideIcons.coins, size: 16),
              label: const Text('Монеты +1000'),
              onPressed: () => _grantCoins(context, ref),
            ),
            ActionChip(
              avatar: const Icon(LucideIcons.chevronsUp, size: 16),
              label: const Text('Лига выше'),
              onPressed: () => _shiftLeague(context, ref, 1),
            ),
            ActionChip(
              avatar: const Icon(LucideIcons.chevronsDown, size: 16),
              label: const Text('Лига ниже'),
              onPressed: () => _shiftLeague(context, ref, -1),
            ),
            ActionChip(
              avatar: const Icon(LucideIcons.lightbulb, size: 16),
              label: const Text('Новый совет дня'),
              onPressed: () => ref.read(tipsProvider.notifier).debugNext(),
            ),
            ActionChip(
              avatar: const Icon(LucideIcons.layers, size: 16),
              label: Text(
                ref.watch(programProvider).phase == ProgramPhase.start
                    ? 'Фаза «База»'
                    : 'Фаза «Старт»',
              ),
              onPressed: () =>
                  ref.read(programProvider.notifier).debugTogglePhase(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () async {
            await notifier.reset();
            if (context.mounted) context.go('/onboarding');
          },
          child: const Text('Удалить героя и пройти онбординг заново'),
        ),
      ],
    );
  }
}

/// Политика конфиденциальности и удаление данных (требование Google Play).
/// Строка-переход в списке настроек.
class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.path,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String path;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: () => context.push(path),
    leading: Icon(icon, size: 18, color: AppColors.textSecondary),
    title: Text(title),
    subtitle: Text(
      subtitle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
    ),
    trailing: const Icon(
      LucideIcons.chevronRight,
      size: 18,
      color: AppColors.textMuted,
    ),
  );
}

class _DataSection extends ConsumerWidget {
  const _DataSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(accountProvider).signedIn;
    return Card(
      child: Column(
        children: [
          const HealthConsentTile(),
          const Divider(height: 1),
          ListTile(
            onTap: () => context.push('/privacy'),
            leading: const Icon(
              LucideIcons.shieldCheck,
              size: 18,
              color: AppColors.textSecondary,
            ),
            title: const Text('Политика конфиденциальности'),
            trailing: const Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: AppColors.textMuted,
            ),
          ),
          const Divider(height: 1),
          ListTile(
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'IronRise',
              applicationLegalese: 'IronRise использует открытые библиотеки на условиях их лицензий',
            ),
            leading: const Icon(
              LucideIcons.scrollText,
              size: 18,
              color: AppColors.textSecondary,
            ),
            title: const Text('Лицензии открытых библиотек'),
            trailing: const Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: AppColors.textMuted,
            ),
          ),
          const Divider(height: 1),
          ListTile(
            onTap: signedIn
                ? () => context.push('/profile/account')
                : () => _confirmWipe(context, ref),
            leading: const Icon(
              LucideIcons.trash2,
              size: 18,
              color: AppColors.textSecondary,
            ),
            title: const Text('Удалить мои данные'),
            subtitle: Text(
              signedIn
                  ? 'Через удаление аккаунта'
                  : 'Герой, тренировки и настройки на телефоне',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmWipe(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Удалить все данные'),
        content: const Text(
          'Герой, уровни, тренировки и покупки исчезнут с телефона. Вернуть их не получится',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(localDataProvider).wipe();
    if (context.mounted) context.go('/onboarding');
  }
}

/// Зал или дом с гантелями: от этого зависят упражнения программы.
class _EquipmentPicker extends ConsumerWidget {
  const _EquipmentPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(programProvider).equipment;
    return SegmentedButton<Equipment>(
      segments: [
        for (final e in Equipment.values)
          ButtonSegment(value: e, label: Text(e.label)),
      ],
      selected: {current},
      onSelectionChanged: (v) =>
          ref.read(programProvider.notifier).setEquipment(v.first),
    );
  }
}

/// Отчёты об ошибках для разработчика: что сломалось и где, без личных данных.
class _LogsToggle extends StatefulWidget {
  const _LogsToggle();

  @override
  State<_LogsToggle> createState() => _LogsToggleState();
}

class _LogsToggleState extends State<_LogsToggle> {
  bool _on = AppLog.enabled;

  @override
  Widget build(BuildContext context) => Card(
    child: SwitchListTile(
      value: _on,
      onChanged: (v) async {
        setState(() => _on = v);
        await AppLog.setEnabled(v);
      },
      title: const Text('Отправлять отчёты об ошибках'),
      subtitle: const Text(
        'Технический журнал приложения: ошибки и сбои связи. Помогает быстро чинить баги, '
        'тренировки и пульс в него не попадают',
        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
      ),
    ),
  );
}

/// «почта · синхр. в 14:05» или «почта · автосинхр. выключена».
String _accountLine(AccountState a) {
  if (!a.signedIn) return 'Не подключён — данные только на телефоне';
  final synced = a.lastSyncedAt;
  final sync = a.syncing
      ? 'синхронизация…'
      : !a.autoSync
      ? 'автосинхронизация выключена'
      : synced == null
      ? 'ещё не синхронизировано'
      : 'синхр. ${syncedWhen(synced)}';
  return '${a.email} · $sync';
}

/// Отдых между подходами (п. 107): по главной цели или свой.
class _RestTile extends ConsumerWidget {
  const _RestTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final own = ref.watch(restSettingProvider);
    ref.watch(heroProvider);
    final current = restOf(ref);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Отдых между подходами'),
      subtitle: Text(
        own == null
            ? 'По цели — ${restLabel(current)}'
            : 'Свой — ${restLabel(current)}',
        style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      ),
      trailing: const Icon(
        LucideIcons.chevronRight,
        size: 18,
        color: AppColors.textMuted,
      ),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.surface,
        builder: (sheet) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text(
                  'Таймер отдыха после подхода. Пульс ещё высокий — приложение подскажет подождать',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
              for (final choice in restChoices)
                ListTile(
                  title: Text(
                    choice == null
                        ? 'По цели (${restLabel(restFor(ref.read(heroProvider)?.goal))})'
                        : restLabel(Duration(seconds: choice)),
                  ),
                  trailing: choice == own
                      ? Icon(
                          LucideIcons.check,
                          size: 18,
                          color: Theme.of(sheet).colorScheme.primary,
                        )
                      : null,
                  onTap: () {
                    ref.read(restSettingProvider.notifier).set(choice);
                    Navigator.pop(sheet);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
