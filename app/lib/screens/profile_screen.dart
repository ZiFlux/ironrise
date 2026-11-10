import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/body_part.dart';
import '../game/training_format.dart';
import '../state/hero.dart';
import '../state/providers.dart';
import '../state/settings.dart';
import '../theme.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hero = ref.watch(heroProvider);
    if (hero == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _HeroInfo(hero: hero),
          const SizedBox(height: 24),
          const _SectionLabel('Цвет интерфейса'),
          const _AccentPicker(),
          const SizedBox(height: 24),
          const Card(
            child: ListTile(
              leading: Icon(LucideIcons.watch, size: 18, color: AppColors.textSecondary),
              title: Text('Часы и датчики пульса'),
              subtitle: Text('Подключение появится в следующих версиях',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 32),
            const _SectionLabel('Режим разработчика'),
            _DebugTools(hero: hero),
          ],
        ],
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
        child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
      if (body.weightKg != null) '${body.weightKg} кг',
    ].join(', ');
    final rows = [
      ('Ник', hero.nickname),
      ('Цель', hero.goal.label),
      ('Формат', hero.format.label),
      ('Дни', hero.trainingDays.map((d) => weekdayShort[d]).join(' ')),
      ('Комплекция', bodyText.isEmpty ? 'не указана' : bodyText),
    ];
    return Card(
      child: Column(
        children: [
          for (final (label, value) in rows)
            SizedBox(
              height: 44,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(label, style: const TextStyle(color: AppColors.textSecondary)),
                    const Spacer(),
                    Text(value),
                  ],
                ),
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
  const _AccentSwatch({required this.option, required this.selected, required this.onTap});

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
                  decoration: BoxDecoration(color: option.color, shape: BoxShape.circle),
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
                  decoration: BoxDecoration(color: part.color, shape: BoxShape.circle),
                ),
                label: Text('${part.label} +100'),
                onPressed: () => notifier.debugAddXp(part, 100),
              ),
            ActionChip(
              avatar: const Icon(LucideIcons.flame, size: 16),
              label: const Text('Серия +5'),
              onPressed: () => notifier.debugSetStreak(hero.streakDays + 5),
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
