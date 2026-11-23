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
import '../l10n/tr.dart';
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
      appBar: AppBar(title: Text(tr('Настройки'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        // Порядок: аккаунт → герой → тренировки → пульс → вид → сообщество →
        // данные. Связанное — в одной карточке, а не россыпью переключателей.
        children: [
          const _AccountCard(),
          const SizedBox(height: 24),
          _SectionLabel(tr('Герой')),
          _HeroInfo(hero: hero),
          const SizedBox(height: 24),
          _SectionLabel(tr('Тренировки')),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      tr('Где тренируешься'),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 14),
                  child: SizedBox(
                    width: double.infinity,
                    child: _EquipmentPicker(),
                  ),
                ),
                const Divider(height: 1),
                const _RestTile(),
                // Средним — попробовать ритм опытных: силовые и разгрузочные.
                if (trainingLevelOf(hero, ref.watch(programProvider)) ==
                    TrainingLevel.intermediate) ...[
                  const Divider(height: 1),
                  SwitchListTile(
                    title: Text(tr('Ритм опытных')),
                    subtitle: Text(
                      tr(
                        'Каждая 4-я тренировка силовая, после 4 недель — разгрузочная неделя',
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                    value: ref.watch(programProvider).rhythmTrial,
                    onChanged: (on) =>
                        ref.read(programProvider.notifier).setRhythmTrial(on),
                  ),
                ],
                const Divider(height: 1),
                // Тренировки в календарь телефона — он синхронизируется на часы.
                SwitchListTile(
                  title: Text(tr('Тренировки в календарь')),
                  subtitle: Text(
                    tr('Событие с временем начала и конца — видно и на часах'),
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                  value: ref.watch(calendarExportProvider),
                  onChanged: (on) async {
                    final ok = await ref
                        .read(calendarExportProvider.notifier)
                        .setEnabled(on);
                    if (!ok) showStatusError(tr('Нужен доступ к календарю'));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionLabel(tr('Пульс')),
          Card(
            clipBehavior: Clip.antiAlias,
            child: _NavTile(
              icon: LucideIcons.watch,
              title: tr('Часы и телефон'),
              subtitle: devicesSummary(ref),
              path: '/profile/devices',
            ),
          ),
          const SizedBox(height: 8),
          _HeartZones(hero: hero),
          const SizedBox(height: 24),
          _SectionLabel(tr('Внешний вид')),
          const _AccentPicker(),
          const SizedBox(height: 8),
          const _LanguageTile(),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                await ScreenHint.resetAll(ref);
                await TabGuide.resetAll(ref);
                if (context.mounted) {
                  showStatus(
                    tr('Подсказки снова появятся на экранах'),
                    kind: StatusKind.success,
                  );
                }
              },
              icon: const Icon(LucideIcons.lightbulb, size: 18),
              label: Text(tr('Показать подсказки снова')),
            ),
          ),
          const SizedBox(height: 16),
          _SectionLabel(tr('Сообщество')),
          const BetaChannelTile(),
          const SizedBox(height: 24),
          _SectionLabel(tr('Данные и конфиденциальность')),
          const _DataSection(),
          const SizedBox(height: 8),
          const _LogsToggle(),
          if (kDebugMode) ...[
            const SizedBox(height: 32),
            _SectionLabel(tr('Режим разработчика')),
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
      if (body.heightCm != null)
        tr('{heightCm} см', {'heightCm': body.heightCm}),
      if (body.weightKg != null)
        tr('{p1} кг', {'p1': formatWeight(body.weightKg!)}),
    ].join(', ');
    // Формат и дни меняются на отдельном экране (раз в неделю).
    void schedule() => context.push('/profile/settings/schedule');
    final rows = <(String, String, VoidCallback?)>[
      (tr('Ник'), hero.nickname, () => showNicknameDialog(context)),
      (
        hero.extraGoals.isEmpty ? tr('Цель') : tr('Цели'),
        [hero.goal, ...hero.extraGoals].map((g) => g.label).join(', '),
        () => showGoalsSheet(context),
      ),
      (tr('Формат'), hero.format.label, schedule),
      (
        tr('Дни'),
        hero.trainingDays.map((d) => weekdayShort[d]).join(' '),
        schedule,
      ),
      (tr('Комплекция'), bodyText.isEmpty ? tr('не указана') : bodyText, null),
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
                      // Подпись — не шире 40% строки; значение прижато вправо,
                      // а не к подписи (Flexible делил место поровну).
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * 0.4,
                        ),
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
            helperText: tr('от {min} до {max}', {'min': min, 'max': max}),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('Отмена')),
          ),
          TextButton(
            onPressed: () {
              final v = int.tryParse(controller.text);
              if (v != null && v >= min && v <= max) Navigator.pop(context, v);
            },
            child: Text(tr('Сохранить')),
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
        title: Text(tr('Опыт тренировок')),
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
            tr('Возраст'),
            body.age == null ? tr('не указан') : '${body.age}',
            () => _edit(
              context,
              ref,
              title: tr('Возраст'),
              hint: tr('лет'),
              current: body.age,
              min: 18,
              max: 90,
              apply: (v) => body.copyWith(age: v),
            ),
          ),
          row(
            tr('Пульс покоя'),
            body.restingHeartRate == null
                ? tr('не указан')
                : tr('{restingHeartRate} уд/мин', {
                    'restingHeartRate': body.restingHeartRate,
                  }),
            () => _edit(
              context,
              ref,
              title: tr('Пульс покоя'),
              hint: tr('утром, лёжа, уд/мин'),
              current: body.restingHeartRate,
              min: 35,
              max: 110,
              apply: (v) => body.copyWith(restingHeartRate: v),
            ),
          ),
          // Опыт и самопроверка задают уровень: сколько упражнений и насколько сложных.
          row(
            tr('Опыт тренировок'),
            body.experience?.label ?? tr('не указан'),
            () => _pickExperience(context, ref, body),
          ),
          row(
            tr('Отжиманий за подход'),
            body.pushUps == null ? tr('не указано') : '${body.pushUps}',
            () => _edit(
              context,
              ref,
              title: tr('Отжиманий за подход'),
              hint: tr('сколько раз подряд'),
              current: body.pushUps,
              min: 0,
              max: 150,
              apply: (v) => body.copyWith(pushUps: v),
            ),
          ),
          row(
            tr('Подтягиваний за подход'),
            body.pullUps == null ? tr('не указано') : '${body.pullUps}',
            () => _edit(
              context,
              ref,
              title: tr('Подтягиваний за подход'),
              hint: tr('сколько раз подряд'),
              current: body.pullUps,
              min: 0,
              max: 60,
              apply: (v) => body.copyWith(pullUps: v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Text(
              tr(
                'Макс. пульс {maxHeartRate}, зона 2 для кардио — от {zone} уд/мин{p3}',
                {
                  'maxHeartRate': hero.maxHeartRate,
                  'zone': zone,
                  'p3': body.age == null || body.restingHeartRate == null
                      ? tr('. Пока по средним значениям')
                      : '',
                },
              ),
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
          side: BorderSide(color: selected ? option.color : Colors.transparent),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Два цвета стиля: кнопки и магия (ауры, уровни, сила).
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final c in [option.color, option.magic])
                      Container(
                        width: 18,
                        height: 18,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
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
        tr('Лиги работают с аккаунтом: войди в «Аккаунт и синхронизация»'),
      );
      return;
    }
    try {
      await ref.read(apiProvider).post('/v1/dev/league', {'shift': shift});
      ref.invalidate(serverLeagueProvider);
      showStatus(
        tr('Готово: открой вкладку «Рейтинг»'),
        kind: StatusKind.success,
      );
    } on ApiException catch (e) {
      showStatusError(
        e.status == 404
            ? tr('Это доступно только на сервере разработки')
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
        e.status == 404
            ? tr('На этом сервере выдача монет выключена')
            : e.message,
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
              label: Text(tr('Серия +5')),
              onPressed: () => notifier.debugSetStreak(hero.streakDays + 5),
            ),
            ActionChip(
              avatar: const Icon(LucideIcons.coins, size: 16),
              label: Text(tr('Монеты +1000')),
              onPressed: () => _grantCoins(context, ref),
            ),
            ActionChip(
              avatar: const Icon(LucideIcons.chevronsUp, size: 16),
              label: Text(tr('Лига выше')),
              onPressed: () => _shiftLeague(context, ref, 1),
            ),
            ActionChip(
              avatar: const Icon(LucideIcons.chevronsDown, size: 16),
              label: Text(tr('Лига ниже')),
              onPressed: () => _shiftLeague(context, ref, -1),
            ),
            ActionChip(
              avatar: const Icon(LucideIcons.lightbulb, size: 16),
              label: Text(tr('Новый совет дня')),
              onPressed: () => ref.read(tipsProvider.notifier).debugNext(),
            ),
            ActionChip(
              avatar: const Icon(LucideIcons.layers, size: 16),
              label: Text(
                ref.watch(programProvider).phase == ProgramPhase.start
                    ? tr('Фаза «База»')
                    : tr('Фаза «Старт»'),
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
          child: Text(tr('Удалить героя и пройти онбординг заново')),
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
          const WellbeingConsentTile(),
          const Divider(height: 1),
          ListTile(
            onTap: () => context.push('/privacy'),
            leading: const Icon(
              LucideIcons.shieldCheck,
              size: 18,
              color: AppColors.textSecondary,
            ),
            title: Text(tr('Политика конфиденциальности')),
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
              applicationLegalese: tr(
                'IronRise использует открытые библиотеки на условиях их лицензий',
              ),
            ),
            leading: const Icon(
              LucideIcons.scrollText,
              size: 18,
              color: AppColors.textSecondary,
            ),
            title: Text(tr('Лицензии открытых библиотек')),
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
            title: Text(tr('Удалить мои данные')),
            subtitle: Text(
              signedIn
                  ? tr('Через удаление аккаунта')
                  : tr('Герой, тренировки и настройки на телефоне'),
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
        title: Text(tr('Удалить все данные')),
        content: Text(
          tr(
            'Герой, уровни, тренировки и покупки исчезнут с телефона. Вернуть их не получится',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('Отмена')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('Удалить')),
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
      title: Text(tr('Отправлять отчёты об ошибках')),
      subtitle: Text(
        tr(
          'Технический журнал приложения: ошибки и сбои связи. Помогает быстро чинить баги, тренировки и пульс в него не попадают',
        ),
        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
      ),
    ),
  );
}

/// «почта · синхр. в 14:05» или «почта · автосинхр. выключена».
/// Аккаунт — первым: со входом это почта и синхронизация, без него —
/// приглашение с кнопкой, а не серая строка «не подключён» в списке.
class _AccountCard extends ConsumerWidget {
  const _AccountCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider);
    final accent = Theme.of(context).colorScheme.primary;
    if (account.signedIn) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: _NavTile(
          icon: LucideIcons.circleUser,
          title: tr('Аккаунт'),
          subtitle: _accountLine(account),
          path: '/profile/account',
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: [
            Icon(LucideIcons.cloudOff, size: 20, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('Аккаунт не создан'), style: TextStyle(fontSize: 15)),
                  SizedBox(height: 2),
                  Text(
                    tr('Прогресс только на этом телефоне'),
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Крупный шрифт — кнопка ужимается, а не выталкивает текст за край.
            Flexible(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onPressed: () => context.push('/profile/account'),
                child: Text(
                  tr('Создать'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _accountLine(AccountState a) {
  if (!a.signedIn) return tr('Не подключён — данные только на телефоне');
  final synced = a.lastSyncedAt;
  final sync = a.syncing
      ? tr('синхронизация…')
      : !a.autoSync
      ? tr('автосинхронизация выключена')
      : synced == null
      ? tr('ещё не синхронизировано')
      : tr('синхр. {p1}', {'p1': syncedWhen(synced)});
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
      title: Text(tr('Отдых между подходами')),
      subtitle: Text(
        own == null
            ? tr('По цели — {p1}', {'p1': restLabel(current)})
            : tr('Свой — {p1}', {'p1': restLabel(current)}),
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
              Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text(
                  tr(
                    'Таймер отдыха после подхода. Пульс ещё высокий — приложение подскажет подождать',
                  ),
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
              for (final choice in restChoices)
                ListTile(
                  title: Text(
                    choice == null
                        ? tr('По цели ({p1})', {
                            'p1': restLabel(
                              restFor(ref.read(heroProvider)?.goal),
                            ),
                          })
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

/// Язык интерфейса: как в системе или выбранный.
class _LanguageTile extends ConsumerWidget {
  const _LanguageTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chosen = ref.watch(languageProvider);
    final options = <(AppLanguage?, String)>[
      (null, tr('Как в системе ({p1})', {'p1': systemLanguage().label})),
      for (final l in AppLanguage.values) (l, l.label),
    ];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: const Icon(
          LucideIcons.languages,
          size: 18,
          color: AppColors.textSecondary,
        ),
        title: Text(tr('Язык')),
        subtitle: Text(
          options.firstWhere((o) => o.$1 == chosen).$2,
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
                for (final (lang, label) in options)
                  ListTile(
                    title: Text(label),
                    trailing: lang == chosen
                        ? Icon(
                            LucideIcons.check,
                            size: 18,
                            color: Theme.of(sheet).colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(sheet);
                      ref.read(languageProvider.notifier).select(lang);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
