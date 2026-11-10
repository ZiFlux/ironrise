import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../game/body_part.dart';
import '../game/training_format.dart';
import '../state/providers.dart';
import '../theme.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hero = ref.watch(heroProvider);
    if (hero == null) return const SizedBox.shrink();
    final notifier = ref.read(heroProvider.notifier);
    final body = hero.body;

    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(title: const Text('Ник'), trailing: Text(hero.nickname)),
                ListTile(title: const Text('Цель'), trailing: Text(hero.goal.label)),
                ListTile(title: const Text('Формат'), trailing: Text(hero.format.label)),
                ListTile(
                  title: const Text('Дни'),
                  trailing: Text(hero.trainingDays.map((d) => weekdayShort[d]).join(' ')),
                ),
                ListTile(
                  title: const Text('Комплекция'),
                  trailing: Text([
                    if (body.sex != null) body.sex!.label,
                    if (body.heightCm != null) '${body.heightCm} см',
                    if (body.weightKg != null) '${body.weightKg} кг',
                  ].join(', ').ifEmpty('не указана')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const ListTile(
            leading: Icon(Icons.watch_outlined),
            title: Text('Часы и датчики пульса'),
            subtitle: Text('Подключение появится в следующих версиях'),
            enabled: false,
          ),

          if (kDebugMode) ...[
            const SizedBox(height: 24),
            const Text('РЕЖИМ РАЗРАБОТЧИКА',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12, letterSpacing: 1)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in BodyPart.values)
                  ActionChip(
                    avatar: Icon(p.icon, color: p.color, size: 18),
                    label: Text('+100 ${p.label}'),
                    onPressed: () => notifier.debugAddXp(p, 100),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.local_fire_department, size: 18),
                  label: const Text('Серия +5'),
                  onPressed: () => notifier.debugSetStreak(hero.streakDays + 5),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                await notifier.reset();
                if (context.mounted) context.go('/onboarding');
              },
              child: const Text('Удалить героя и пройти онбординг заново'),
            ),
          ],
        ],
      ),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
