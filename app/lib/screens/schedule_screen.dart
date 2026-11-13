import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/schedule.dart';
import '../game/training_format.dart';
import '../net/api_client.dart';
import '../state/account_state.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../widgets/schedule_picker.dart';
import '../widgets/status_toast.dart';

/// Смена формата и дней тренировок — раз в 7 дней (PLAN 4.3).
class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  late TrainingFormat _format;
  late Set<int> _days;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final hero = ref.read(heroProvider)!;
    _format = hero.format;
    _days = hero.trainingDays.toSet();
  }

  Future<void> _save() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Сменить график?'),
        content: const Text(
          'Следующий раз сменить его можно будет через 7 дней',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Сменить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    final days = _days.toList()..sort();
    try {
      if (ref.read(accountProvider).signedIn) {
        final hero = await ref.read(apiProvider).put('/v1/me/schedule', {
          'trainingFormat': _format.name,
          'scheduleDays': days,
        });
        await ref.read(heroProvider.notifier).applyServer(hero);
      } else {
        await ref
            .read(heroProvider.notifier)
            .changeScheduleLocally(_format, days);
      }
      if (!mounted) return;
      showStatus('График обновлён', kind: StatusKind.success);
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      showStatusError(
        e.status == 409
            ? 'Сменить график пока нельзя: не чаще раза в неделю'
            : e.message,
        network: e.isNetwork,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hero = ref.watch(heroProvider);
    if (hero == null) return const SizedBox.shrink();
    final next = hero.nextScheduleChangeAt;
    final allowed = canChangeSchedule(next, DateTime.now());
    final changed =
        _format != hero.format || !_sameDays(_days, hero.trainingDays);
    final enoughDays = _days.length >= minTrainingDaysPerWeek;

    return Scaffold(
      appBar: AppBar(title: const Text('График тренировок')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    allowed
                        ? LucideIcons.calendarCheck
                        : LucideIcons.calendarClock,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      allowed
                          ? 'График можно менять раз в неделю — чтобы его нельзя было подстроить '
                                'под пропуск и сохранить серию'
                          : 'Следующая смена — с ${_date(next!)}. График можно менять раз в неделю',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          IgnorePointer(
            ignoring: !allowed,
            child: Opacity(
              opacity: allowed ? 1 : 0.5,
              child: SchedulePicker(
                format: _format,
                days: _days,
                onChanged: (f, d) => setState(() {
                  _format = f;
                  _days = d;
                }),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: allowed && changed && enoughDays && !_saving
                ? _save
                : null,
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Сохранить график'),
          ),
        ],
      ),
    );
  }

  static bool _sameDays(Set<int> a, List<int> b) =>
      a.length == b.length && a.containsAll(b);

  static const _months = [
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];

  /// «19 ноября, 14:30».
  static String _date(DateTime d) {
    final t = d.toLocal();
    return '${t.day} ${_months[t.month - 1]}, ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}
