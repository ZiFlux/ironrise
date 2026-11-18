import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../avatar/avatar_view.dart';
import '../game/aura.dart';
import '../game/cardio.dart';
import '../net/api_client.dart';
import '../state/training_sound.dart';
import '../state/account_state.dart';
import '../state/aura_state.dart';
import '../state/heart_rate_state.dart';
import '../state/health_state.dart';
import '../state/consent_state.dart';
import '../game/game_config.dart';
import '../game/anti_fraud.dart' show PulseSample;
import '../state/providers.dart';
import '../theme.dart';
import '../widgets/aura_flame.dart';
import '../widgets/sign_in_gate.dart';
import '../widgets/status_toast.dart';

/// Ауры для дуэлей: выбрать одну, прокачивать особыми тренировками 2 раза в неделю.
class AuraScreen extends ConsumerWidget {
  const AuraScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(accountProvider).signedIn) {
      return const SignInGate(
        title: 'Ауры',
        icon: LucideIcons.wandSparkles,
        text:
            'Аура вспыхивает в дуэли один раз за бой: ярость, стойкость, скорость '
            'или фокус. Прокачивается особыми тренировками дважды в неделю.',
      );
    }
    final info = ref.watch(auraProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ауры')),
      body: info.when(
        data: (a) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            // Главное — сколько тренировок ауры осталось на неделе; правила ниже мельче.
            Row(
              children: [
                Text(
                  '${a.sessionsThisWeek} из ${a.perWeek}',
                  style: figureStyle(size: 20),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'тренировок ауры на этой неделе',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Вспыхивает раз за бой — при здоровье ниже 65 % или за 3 раунда '
              'до конца. Тренировка — не чаще раза в день, с пульсом с часов '
              'или датчика.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            if (!a.ready) ...[_LockedCard(info: a), const SizedBox(height: 12)],
            for (final p in a.auras)
              _AuraCard(
                progress: p,
                equipped: a.equipped == p.kind,
                canTrain: a.canTrain,
                limitLabel: !a.ready
                    ? 'Закрыто'
                    : a.trainedToday
                    ? 'Завтра'
                    : 'Лимит недели',
              ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(auraProvider),
            child: const Text('Не удалось загрузить — повторить'),
          ),
        ),
      ),
    );
  }
}

/// Ауры ещё закрыты: сначала неделя обычных тренировок с пульсом.
class _LockedCard extends StatelessWidget {
  const _LockedCard({required this.info});

  final AuraInfo info;

  @override
  Widget build(BuildContext context) {
    final left = [
      if (info.daysLeft > 0) '${info.daysLeft} дн.',
      if (info.workoutsLeft > 0) '${info.workoutsLeft} трен. с пульсом',
    ].join(' и ещё ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              LucideIcons.lock,
              size: 20,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ауры откроются через $left',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'За неделю обычных тренировок и кардио с часами или датчиком мы '
                    'узнаем твой пульс на упражнениях. По нему и оценим тренировку '
                    'ауры — честно для тебя, а не по общей планке.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final _compact = ButtonStyle(
  minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
  padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 4)),
);

class _AuraCard extends ConsumerWidget {
  const _AuraCard({
    required this.progress,
    required this.equipped,
    required this.canTrain,
    required this.limitLabel,
  });

  final AuraProgress progress;
  final bool equipped;
  final bool canTrain;
  final String limitLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = progress.kind;
    final hero = ref.watch(heroProvider);
    final open = progress.level > 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: equipped ? kind.color : Colors.transparent,
          width: equipped ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              height: 104,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hero != null)
                    AuraHero(
                      kind: open ? kind : null,
                      level: progress.level,
                      child: AvatarView(
                        levels: hero.avatarLevels,
                        look: hero.look,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(auraIcon(kind), size: 16, color: kind.color),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          kind.label,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        open ? 'ур. ${progress.level}' : 'закрыта',
                        style: figureStyle(
                          size: 13,
                          color: open ? kind.color : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    kind.effect,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    progress.toNext == null
                        ? 'Максимальный уровень'
                        : open
                        ? 'До уровня ${progress.level + 1}: ${progress.toNext} трен.'
                        : 'Откроется после первой тренировки',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Две кнопки в ряд, ниже обычных — карточка не растягивается.
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: FilledButton.tonal(
                          style: _compact,
                          onPressed: canTrain
                              ? () => context.push('/duels/auras/${kind.name}')
                              : null,
                          child: Text(
                            canTrain ? 'Тренировка' : limitLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (open) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            style: _compact,
                            onPressed: () => ref
                                .read(auraProvider.notifier)
                                .equip(equipped ? null : kind),
                            child: Text(
                              equipped ? 'Снять' : 'Выбрать',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Тренировка ауры: комплекс по таймеру — работа, отдых, следующий круг.
class AuraTrainingScreen extends ConsumerStatefulWidget {
  const AuraTrainingScreen({super.key, required this.kind});

  final AuraKind kind;

  @override
  ConsumerState<AuraTrainingScreen> createState() => _AuraTrainingState();
}

typedef _Step = ({String title, int seconds, bool rest, String how});

class _AuraTrainingState extends ConsumerState<AuraTrainingScreen> {
  late final List<_Step> _steps = [
    for (var r = 0; r < AuraKind.rounds; r++)
      for (final (i, m) in widget.kind.moves.indexed) ...[
        (title: m.name, seconds: m.seconds, rest: false, how: m.how),
        if (r < AuraKind.rounds - 1 || i < widget.kind.moves.length - 1)
          (
            title: 'Отдых',
            seconds: AuraKind.restSeconds,
            rest: true,
            how: 'Походи и выровняй дыхание',
          ),
      ],
  ];

  /// Сервер засчитывает тренировку ауры от 6 минут; берём с запасом.
  static const _minDuration = Duration(seconds: 370);

  Timer? _timer;
  DateTime? _startedAt;
  DateTime? _finishedAt;
  int _index = -1;

  /// Конец текущего шага по часам: таймер не отстаёт, если экран гас.
  DateTime _stepEnd = DateTime.now();

  /// «Заминка»: шаги пропущены и до 6 минут не хватает — ждём и отправляем.
  DateTime? _holdUntil;
  bool _saving = false;
  String? _error;
  bool _canRetry = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int _secondsUntil(DateTime t) {
    final ms = t.difference(DateTime.now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms + 999) ~/ 1000;
  }

  void _start() {
    final now = DateTime.now();
    _startedAt = now;
    // Часы начинают передавать пульс — он подтверждает тренировку ауры.
    ref.read(heartRateProvider.notifier).startWatch();
    setState(() {
      _index = 0;
      _stepEnd = now.add(Duration(seconds: _steps[0].seconds));
    });
    TrainingSound.start();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => _tick());
  }

  void _tick() {
    if (!mounted || _saving || _error != null) return;
    final now = DateTime.now();
    final hold = _holdUntil;
    if (hold != null) {
      if (!now.isBefore(hold)) {
        _holdUntil = null;
        _complete();
      } else {
        setState(() {});
      }
      return;
    }
    // Догоняем все шаги, которые закончились, пока приложение было в фоне.
    final before = _index;
    while (!now.isBefore(_stepEnd) && _index + 1 < _steps.length) {
      _index++;
      _stepEnd = _stepEnd.add(Duration(seconds: _steps[_index].seconds));
    }
    // Сигнал на смену шага: старт упражнения или начало отдыха (п. 72).
    if (_index != before) {
      _steps[_index].rest ? TrainingSound.rest() : TrainingSound.start();
    }
    if (!now.isBefore(_stepEnd)) {
      _complete();
    } else {
      setState(() {});
    }
  }

  void _skip() {
    _stepEnd = DateTime.now();
    _tick();
  }

  void _complete() {
    final start = _startedAt ?? DateTime.now();
    final enough = start.add(_minDuration);
    if (DateTime.now().isBefore(enough)) {
      setState(() => _holdUntil = enough);
      return;
    }
    _timer?.cancel();
    _finishedAt = DateTime.now();
    _submit();
  }

  /// Пульс покрывает тренировку настолько, что сервер её примет.
  static bool _covers(List<PulseSample> pulse, DateTime start, DateTime end) {
    if (pulse.length < 2) return false;
    final total = end.difference(start).inSeconds;
    final covered = pulse.last.at.difference(pulse.first.at).inSeconds;
    return total > 0 && covered / total >= GameConfig.minPulseCoverage;
  }

  Future<void> _submit() async {
    final end = _finishedAt ?? DateTime.now();
    final start = _startedAt ?? end;
    setState(() {
      _saving = true;
      _error = null;
    });
    final hr = ref.read(heartRateProvider.notifier);
    final health = ref.read(healthProvider.notifier);
    var pulse = hr.samplesBetween(start, end);
    try {
      await hr.stopWatch();
      // Живого пульса мало (часы без нашего приложения, Samsung Health) — берём
      // записанный в Health Connect, как у кардио. Без согласия — не трогаем.
      if (ref.read(healthConsentProvider).allowsPulse &&
          !_covers(pulse, start, end)) {
        final stored = await health.heartRateBetween(start, end);
        if (stored.length > pulse.length) pulse = stored;
      }
      final sent = await ref
          .read(auraProvider.notifier)
          .train(widget.kind, startedAt: start, finishedAt: end, pulse: pulse);
      // Без сети тренировка в очереди и уйдёт сама, когда появится связь (п. 114).
      showStatus(
        sent ? 'Аура «${widget.kind.label}» прокачана' : 'Нет сети — тренировка сохранена и засчитается, когда появится связь',
        kind: sent ? StatusKind.success : StatusKind.offline,
      );
      if (mounted) context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _canRetry =
            e.isNetwork ||
            e.status >= 500 ||
            (e.status == 422 &&
                (e.message.contains('coverage') ||
                    e.message.contains('no_pulse')));
        _error = switch (e.status) {
          422 when e.message.contains('6-40') =>
            'Тренировка короче 6 минут — не засчитана',
          422 when e.message.contains('no_consent') => 'Без согласия на данные о пульсе ауру не засчитать — включите его в настройках',
          422 when e.message.contains('coverage') =>
            'Пульс записан только на часть тренировки — держите часы или датчик '
                'включёнными до конца. Если пульс идёт через Samsung Health, '
                'подождите минуту и нажмите «Повторить»',
          422 when e.message.contains('low') => 'Пульс слишком спокойный для ауры: нужен средний от 85 или пик от 110',
          422 =>
            'Нет пульса с часов или датчика — тренировка ауры не засчитана',
          409 when e.message.contains('locked') =>
            'Ауры ещё закрыты: сначала неделя тренировок с пульсом',
          409 => 'Тренировка ауры уже была — следующая завтра',
          _ => 'Нет связи с сервером — попробуйте ещё раз',
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _canRetry = true;
        _error = 'Не удалось сохранить тренировку — попробуйте ещё раз';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final hero = ref.watch(heroProvider);
    final started = _index >= 0;
    final step = started ? _steps[_index] : null;
    final next = started && _index + 1 < _steps.length
        ? _steps[_index + 1]
        : null;
    return Scaffold(
      appBar: AppBar(title: Text('Аура: ${kind.label}')),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Пока идёт работа — аура горит.
                    if (hero != null)
                      AuraHero(
                        kind: started && _holdUntil == null && !step!.rest
                            ? kind
                            : null,
                        level:
                            ref
                                .watch(auraProvider)
                                .value
                                ?.auras
                                .where((a) => a.kind == kind)
                                .firstOrNull
                                ?.level ??
                            1,
                        child: AvatarView(
                          levels: hero.avatarLevels,
                          look: hero.look,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (!started) ...[
                // Описание прокручивается на маленьком экране; кнопка — всегда видна.
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          kind.trainingTitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        for (final m in kind.moves)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${m.name} — ${m.seconds} с',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  m.how,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          '${AuraKind.rounds} круга, отдых ${AuraKind.restSeconds} с · '
                          '~${(kind.totalSeconds / 60).round()} мин. Наденьте часы: '
                          'без пульса тренировка не засчитается',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _start, child: const Text('Начать')),
              ] else if (_error != null) ...[
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    if (_canRetry)
                      FilledButton(
                        onPressed: _submit,
                        child: const Text('Повторить'),
                      ),
                    OutlinedButton(
                      onPressed: () => context.pop(),
                      child: const Text('Выйти'),
                    ),
                  ],
                ),
              ] else if (_holdUntil != null) ...[
                const Text(
                  'Заминка',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${_secondsUntil(_holdUntil!)}',
                  textAlign: TextAlign.center,
                  style: figureStyle(size: 56),
                ),
                const Text(
                  'Аура засчитывается от 6 минут. Походите и восстановите '
                  'дыхание — тренировка отправится сама',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ] else ...[
                Text(
                  step!.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: step.rest ? AppColors.textSecondary : kind.color,
                  ),
                ),
                Text(
                  '${_secondsUntil(_stepEnd)}',
                  textAlign: TextAlign.center,
                  style: figureStyle(size: 56),
                ),
                // Как делать: сейчас — текущее, на отдыхе — следующее упражнение.
                Text(
                  step.rest && next != null ? next.how : step.how,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                // Пульс (п. 107): аура засчитывается только при повышенном пульсе.
                _AuraPulse(rest: step.rest, color: kind.color),
                const SizedBox(height: 4),
                Text(
                  next == null ? 'Последнее' : 'Дальше: ${next.title}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 12),
                if (_saving)
                  const Center(child: CircularProgressIndicator())
                else
                  TextButton(onPressed: _skip, child: const Text('Дальше')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Живой пульс в тренировке ауры: в движении — «поднят» или «ускорься»
/// (порог — нижняя граница кардио-зоны), на отдыхе — просто значение.
class _AuraPulse extends ConsumerWidget {
  const _AuraPulse({required this.rest, required this.color});

  final bool rest;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bpm = ref.watch(heartRateProvider).bpm;
    final hero = ref.watch(heroProvider);
    final zone = hero == null
        ? CardioScoring.zoneLowerBound()
        : CardioScoring.zoneLowerBound(
            resting: hero.restingHeartRate,
            max: hero.maxHeartRate,
          );
    final (text, tone) = switch (bpm) {
      null => (
        'Нет пульса — без него аура не засчитается',
        AppColors.textMuted,
      ),
      _ when rest => ('Отдых — пульс можно отпустить', AppColors.textSecondary),
      final b when b >= zone => ('Пульс поднят — так держать', color),
      _ => ('Ускорься: пульс должен быть от $zone', AppColors.textSecondary),
    };
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          LucideIcons.heartPulse,
          size: 18,
          color: bpm == null ? AppColors.textMuted : const Color(0xFFFF6B5E),
        ),
        const SizedBox(width: 6),
        Text(bpm?.toString() ?? '—', style: figureStyle(size: 20)),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: tone),
          ),
        ),
      ],
    );
  }
}
