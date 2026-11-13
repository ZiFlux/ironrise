import 'package:flutter/material.dart';

import '../game/exercise_catalog.dart';
import '../theme.dart';
import '../widgets/exercise_picker.dart';
import '../widgets/warmup_card.dart';

/// База знаний: силовые (техника, мышцы, сложность, варианты) и разминка.
class ExerciseLibraryScreen extends StatelessWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('База знаний'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Силовые'),
              Tab(text: 'Разминка'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ExerciseBrowser(
                showInfoButton: false,
                showDifficulty: true,
                onTap: (e) => showExerciseDetails(context, e),
              ),
            ),
            const _WarmupList(),
          ],
        ),
      ),
    );
  }
}

class _WarmupList extends StatelessWidget {
  const _WarmupList();

  @override
  Widget build(BuildContext context) {
    const moves = ExerciseCatalog.warmups;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: moves.length + 1,
      separatorBuilder: (_, i) =>
          i == 0 ? const SizedBox(height: 8) : const Divider(height: 1),
      itemBuilder: (context, i) {
        if (i == 0) {
          return const Text(
            'Разминка подбирается перед каждой тренировкой под её упражнения: '
            'лёгкое кардио и суставы, которые будут работать',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          );
        }
        final m = moves[i - 1];
        return InkWell(
          onTap: () => showWarmupDetails(context, m),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.name, style: const TextStyle(fontSize: 15)),
                        Text(
                          [
                            warmupAmount(m),
                            m.gear.label.toLowerCase(),
                            ...m.targets.map((p) => p.label.toLowerCase()),
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
