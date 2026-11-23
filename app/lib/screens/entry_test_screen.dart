import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/entry_test.dart';
import '../state/entry_test_state.dart';
import '../state/providers.dart';
import '../state/training_sound.dart';
import '../theme.dart';

/// Входная тренировка (п. 116, TRAINING_SYSTEM.md 13.3): 6 упражнений без инвентаря,
/// ~12–14 минут. По ней — уровень подготовки и стартовые ступени упражнений.
class EntryTestScreen extends ConsumerStatefulWidget {
  const EntryTestScreen({super.key});

  @override
  ConsumerState<EntryTestScreen> createState() => _EntryTestScreenState();
}

enum _Phase { intro, ready, running, input, rest, done }

class _EntryTestScreenState extends ConsumerState<EntryTestScreen> {
  _Phase _phase = _Phase.intro;
  int _index = 0;
  final _values = <EntryTestItem, int?>{};
  bool _knee = false;
  final _count = TextEditingController();

  /// Конец отсчёта (60 с, отдых) или начало секундомера планки.
  DateTime? _mark;
  Timer? _ticker;
  bool _saving = false;
  EntryTestResult? _result;

  EntryTestItem get _item => EntryTestItem.values[_index];

  @override
  void dispose() {
    _ticker?.cancel();
    _count.dispose();
    super.dispose();
  }

  void _tick(void Function() onEnd, {Duration? until}) {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      if (until != null && DateTime.now().isAfter(_mark!)) {
        _ticker?.cancel();
        onEnd();
      } else if (_item == EntryTestItem.plank &&
          _phase == _Phase.running &&
          _elapsed.inSeconds >= plankMaxSeconds) {
        _ticker?.cancel();
        _stopPlank();
      } else {
        setState(() {});
      }
    });
  }

  Duration get _left {
    final l = _mark!.difference(DateTime.now());
    return l.isNegative ? Duration.zero : l;
  }

  Duration get _elapsed => DateTime.now().difference(_mark!);

  void _go() {
    TrainingSound.start();
    setState(() {
      _phase = _Phase.running;
      _mark = _item.timed
          ? DateTime.now().add(const Duration(seconds: 60))
          : DateTime.now();
    });
    if (_item.timed) {
      _tick(() {
        TrainingSound.rest();
        HapticFeedback.heavyImpact();
        setState(() => _phase = _Phase.input);
      }, until: Duration.zero);
    } else if (_item == EntryTestItem.plank) {
      _tick(() {});
    }
  }

  void _stopPlank() {
    _ticker?.cancel();
    TrainingSound.rest();
    final seconds = _elapsed.inSeconds.clamp(0, plankMaxSeconds);
    _values[_item] = seconds;
    _next();
  }

  void _saveCount() {
    final n = int.tryParse(_count.text.trim());
    if (n == null || n < 0 || n > 300) return;
    _values[_item] = n;
    _next();
  }

  void _noBar() {
    _values[EntryTestItem.pullUps] = null;
    _finish();
  }

  /// Дальше: отдых, затем следующее упражнение (или итог).
  void _next() {
    _count.clear();
    if (_index == EntryTestItem.values.length - 1) {
      _finish();
      return;
    }
    final rest = _item.restAfter;
    setState(() {
      _phase = _Phase.rest;
      _mark = DateTime.now().add(rest);
    });
    _tick(_afterRest, until: Duration.zero);
  }

  void _afterRest() {
    _ticker?.cancel();
    TrainingSound.start();
    setState(() {
      _index++;
      _phase = _Phase.ready;
    });
  }

  Future<void> _finish() async {
    _ticker?.cancel();
    setState(() => _saving = true);
    final result = EntryTestResult(
      at: DateTime.now(),
      pushUps: _values[EntryTestItem.pushUps] ?? 0,
      kneePushUps: _knee,
      squats60: _values[EntryTestItem.squats60] ?? 0,
      crunches60: _values[EntryTestItem.crunches60] ?? 0,
      burpees60: _values[EntryTestItem.burpees60] ?? 0,
      plankSec: _values[EntryTestItem.plank] ?? 0,
      pullUps: _values[EntryTestItem.pullUps],
    );
    final previous = ref.read(entryTestProvider).firstOrNull;
    await ref.read(entryTestProvider.notifier).save(result);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _result = result;
      _previous = previous;
      _phase = _Phase.done;
    });
  }

  EntryTestResult? _previous;

  Future<void> _later() async {
    await ref.read(entryTestProvider.notifier).skip();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Входная тренировка'),
        automaticallyImplyLeading: _phase == _Phase.intro,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: switch (_phase) {
            _Phase.intro => _intro(accent),
            _Phase.done => _done(accent),
            _ => _exercise(accent),
          },
        ),
      ),
    );
  }

  Widget _intro(Color accent) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: ListView(
          children: [
            const Text(
              '12 минут — и план будет по силам',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text(
              'Шесть упражнений дома, без инвентаря. Это не тест на максимум: '
              'останавливайся, как только техника ломается. По результатам подберём '
              'уровень и упражнения, а через месяц сравним результаты.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
            for (final item in EntryTestItem.values)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  item.timed ? LucideIcons.timer : LucideIcons.dumbbell,
                  color: accent,
                ),
                title: Text(item.title),
              ),
            const SizedBox(height: 8),
            const Text(
              'Нужно немного места на полу и коврик. Плохо стало — остановись, '
              'тест можно закончить в любой момент. +50 монет за прохождение.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
      FilledButton(
        onPressed: () => setState(() => _phase = _Phase.ready),
        child: const Text('Начать'),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _later,
        style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
        child: const Text('Позже — план пока будет по анкете'),
      ),
    ],
  );

  Widget _exercise(Color accent) {
    final item = _item;
    final resting = _phase == _Phase.rest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          value: (_index + (resting ? 1 : 0)) / EntryTestItem.values.length,
        ),
        const SizedBox(height: 16),
        Text(
          resting
              ? 'Отдых · дальше: ${EntryTestItem.values[_index + 1].title}'
              : '${_index + 1} из ${EntryTestItem.values.length} · ${item.title}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          resting ? EntryTestItem.values[_index + 1].how : item.how,
          style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        const Spacer(),
        if (_phase == _Phase.running || resting)
          Center(
            child: Text(
              resting || item.timed
                  ? '${_left.inSeconds}'
                  : '${_elapsed.inSeconds} с',
              style: TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.w700,
                color: resting ? AppColors.textSecondary : accent,
              ),
            ),
          ),
        if (_phase == _Phase.input) _countInput(),
        const Spacer(),
        ..._actions(item, resting),
      ],
    );
  }

  Widget _countInput() => Column(
    children: [
      if (_item == EntryTestItem.pushUps)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Отжимания были с колен'),
          value: _knee,
          onChanged: (v) => setState(() => _knee = v),
        ),
      TextField(
        controller: _count,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700),
        decoration: InputDecoration(hintText: '0', suffixText: _item.unit),
        onSubmitted: (_) => _saveCount(),
      ),
    ],
  );

  List<Widget> _actions(EntryTestItem item, bool resting) {
    if (resting) {
      return [
        OutlinedButton(
          onPressed: _afterRest,
          child: const Text('Пропустить отдых'),
        ),
      ];
    }
    return switch (_phase) {
      _Phase.ready => [
        FilledButton(
          onPressed: item.timed || item == EntryTestItem.plank
              ? _go
              : () => setState(() => _phase = _Phase.input),
          child: Text(
            item.timed
                ? 'Старт — 60 секунд'
                : item == EntryTestItem.plank
                ? 'Старт секундомера'
                : 'Готово — ввести результат',
          ),
        ),
        if (item == EntryTestItem.pullUps) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _saving ? null : _noBar,
            child: const Text('Нет турника — закончить'),
          ),
        ],
      ],
      _Phase.running when item == EntryTestItem.plank => [
        FilledButton(onPressed: _stopPlank, child: const Text('Стоп')),
      ],
      _Phase.running => const [],
      _Phase.input => [
        FilledButton(
          onPressed: _saving ? null : _saveCount,
          child: const Text('Дальше'),
        ),
      ],
      _ => const [],
    };
  }

  Widget _done(Color accent) {
    final r = _result!;
    final level = entryLevel(r, ref.read(heroProvider)?.body.sex);
    final prev = _previous;
    String line(EntryTestItem item) {
      final v = r.valueOf(item);
      if (v == null) return '—';
      final was = prev?.valueOf(item);
      final diff = was == null ? '' : ' (было $was)';
      final knee = item == EntryTestItem.pushUps && r.kneePushUps
          ? ' с колен'
          : '';
      return '$v ${item.unit}$knee$diff';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            children: [
              Icon(LucideIcons.trophy, size: 48, color: accent),
              const SizedBox(height: 12),
              Text(
                'Уровень: ${level.label}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                prev == null
                    ? 'План и упражнения подобраны под твой результат. Через месяц '
                          'повторим тест и сравним результаты.'
                    : 'Сравнение с прошлым разом — в скобках. Так держать!',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              for (final item in EntryTestItem.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.title),
                  trailing: Text(
                    line(item),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              const SizedBox(height: 8),
              const Text(
                '+50 монет придут с синхронизацией',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        FilledButton(
          onPressed: () => context.go('/'),
          child: const Text('Готово'),
        ),
      ],
    );
  }
}
