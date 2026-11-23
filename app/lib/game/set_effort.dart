import 'dart:math' as math;

import 'anti_fraud.dart';
import 'workout.dart';

/// Насколько тяжёлым был подход по пульсу.
enum EffortLevel {
  light('легко'),
  moderate('умеренно'),
  hard('тяжело');

  const EffortLevel(this.label);
  final String label;
}

/// Подход глазами пульса: пик рядом с записью и подъём от отдыха перед ним.
class SetEffort {
  const SetEffort({
    required this.exerciseId,
    required this.setIndex,
    required this.peak,
    required this.rise,
    required this.level,
    this.carryOver = 0,
  });

  final String exerciseId;
  final int setIndex;
  final int peak;

  /// На сколько пульс поднялся над тем, каким он был бы без подхода: от отдыха
  /// перед ним или от спадающего «хвоста» прошлого подхода — что ниже.
  final int rise;
  final EffortLevel level;

  /// Сколько ударов к началу подхода ещё оставалось от прошлого подхода (пульс
  /// спадает 2–3 минуты). Большой — подход начат с неостывшим пульсом.
  final int carryOver;

  /// Подход записан, а пульс не поднялся — запись сомнительна.
  bool get flat => rise < SetEffortAnalysis.flatRise;
}

/// Анализ пульса по подходам (п. 30 бэклога). Во время подхода пульс растёт,
/// на отдыхе падает: сопоставляем эти циклы с моментами записи подходов.
///
/// После подхода пульс ещё 2–3 минуты остаётся повышенным и спадает примерно по
/// экспоненте: ЧСС(t) ≈ покой + (пик − покой)·e^(−t/τ). Скорость спада τ у каждого
/// своя (тренированность, усталость к концу тренировки) — её оцениваем по отдыху
/// между подходами этой же тренировки. Так короткий отдых не путается ни с лёгким
/// подходом (пульс поднялся «мало», потому что не успел упасть), ни с тяжёлым
/// (пик высокий, потому что сложился с хвостом прошлого).
class SetEffortAnalysis {
  const SetEffortAnalysis(this.sets, {this.recoveryTau = defaultTau});

  final List<SetEffort> sets;

  /// Постоянная спада пульса на отдыхе у этого человека в этой тренировке.
  final Duration recoveryTau;

  /// Пик ищем от 60 с до записи и до 20 с после (пульс догоняет нагрузку).
  static const peakBefore = Duration(seconds: 60);
  static const peakAfter = Duration(seconds: 20);

  /// Подъём меньше — пульс на подход не отреагировал.
  static const flatRise = 6;

  /// Доля резерва пульса: выше — тяжело, ниже — легко.
  static const hardReserve = 0.6;
  static const lightReserve = 0.35;

  /// τ по умолчанию: за 3τ ≈ 3,5 минуты пульс почти возвращается к покою.
  static const defaultTau = Duration(seconds: 70);
  static const _minTau = 30;
  static const _maxTau = 180;

  /// Пульс считается восстановившимся — ниже этой доли резерва.
  static const recoveredReserve = 0.4;

  bool get isEmpty => sets.isEmpty;

  List<SetEffort> get flatSets => [
    for (final s in sets)
      if (s.flat) s,
  ];

  /// Подходы, начатые с неостывшим пульсом (хвост прошлого больше трети резерва).
  List<SetEffort> carriedSets(int reserve) => [
    for (final s in sets)
      if (s.carryOver > reserve / 3) s,
  ];

  /// Средний подъём пульса по упражнениям: присед поднимает сильнее сгибаний.
  Map<String, int> get riseByExercise {
    final sum = <String, int>{};
    final count = <String, int>{};
    for (final s in sets) {
      sum[s.exerciseId] = (sum[s.exerciseId] ?? 0) + s.rise;
      count[s.exerciseId] = (count[s.exerciseId] ?? 0) + 1;
    }
    return {for (final id in sum.keys) id: (sum[id]! / count[id]!).round()};
  }

  /// Пульс через [after] после пика [peak] без новой нагрузки.
  static double expectedAfter({
    required int peak,
    required int restingHr,
    required Duration after,
    Duration tau = defaultTau,
  }) =>
      restingHr +
      (peak - restingHr) *
          math.exp(
            -after.inMilliseconds / tau.inMilliseconds.clamp(1, 1 << 30),
          );

  /// Постоянная спада по отрезкам отдыха: от пика подхода до начала следующего.
  /// На каждом отрезке — наклон ln((ЧСС − покой)/(пик − покой)) по времени
  /// (метод наименьших квадратов через ноль), итог — медиана. Мало данных —
  /// [defaultTau].
  static Duration recoveryTauOf(
    List<PulseSample> pulse,
    List<DateTime> setTimes, {
    required int restingHr,
  }) {
    final times = [...setTimes]..sort();
    final taus = <double>[];
    for (var i = 0; i + 1 < times.length; i++) {
      final from = times[i];
      final to = times[i + 1].subtract(peakBefore);
      if (to.difference(from).inSeconds < 40) continue;
      // Пик — около записи подхода; дальше только спад.
      PulseSample? top;
      for (final p in pulse) {
        if (p.at.isBefore(from.subtract(const Duration(seconds: 20))) ||
            p.at.isAfter(from.add(peakAfter))) {
          continue;
        }
        if (top == null || p.bpm > top.bpm) top = p;
      }
      if (top == null || top.bpm - restingHr < 15) continue;
      var sxy = 0.0;
      var sxx = 0.0;
      var n = 0;
      for (final p in pulse) {
        if (!p.at.isAfter(top.at) || p.at.isAfter(to)) continue;
        final excess = p.bpm - restingHr;
        if (excess < 3) continue;
        final t = p.at.difference(top.at).inMilliseconds / 1000;
        final y = math.log(excess / (top.bpm - restingHr));
        sxy += t * y;
        sxx += t * t;
        n++;
      }
      if (n < 4 || sxx == 0) continue;
      final k = sxy / sxx;
      if (k >= 0) continue;
      taus.add((-1 / k).clamp(_minTau.toDouble(), _maxTau.toDouble()));
    }
    if (taus.isEmpty) return defaultTau;
    taus.sort();
    return Duration(seconds: taus[taus.length ~/ 2].round());
  }

  /// null — анализировать нечего: нет пульса или у подходов нет времени.
  static SetEffortAnalysis? of(
    WorkoutSession session,
    List<PulseSample> pulse, {
    required int restingHr,
    required int maxHr,
  }) {
    if (pulse.length < 10) return null;
    final timed = <(String, int, DateTime)>[
      for (final e in session.entries)
        for (final (i, s) in e.sets.indexed)
          if (s.at != null) (e.exercise.id, i, s.at!),
    ]..sort((a, b) => a.$3.compareTo(b.$3));
    if (timed.isEmpty) return null;

    final reserve = (maxHr - restingHr).clamp(20, 200);
    final tau = recoveryTauOf(pulse, [
      for (final t in timed) t.$3,
    ], restingHr: restingHr);
    final out = <SetEffort>[];
    DateTime? previous;
    ({int bpm, DateTime at})? previousPeak;
    for (final (id, index, at) in timed) {
      // Окно пика не залезает на хвост прошлого подхода.
      var peakFrom = at.subtract(peakBefore);
      final afterPrevious = previous?.add(peakAfter);
      if (afterPrevious != null && afterPrevious.isAfter(peakFrom)) {
        peakFrom = afterPrevious;
      }
      final peakWindow = pulse.where(
        (p) => !p.at.isBefore(peakFrom) && !p.at.isAfter(at.add(peakAfter)),
      );
      if (peakWindow.isEmpty) continue;
      final top = peakWindow.reduce((a, b) => a.bpm >= b.bpm ? a : b);
      final peak = top.bpm;
      // Отдых перед подходом: от прошлой записи (+30 с) до начала окна пика.
      final restFrom =
          previous?.add(const Duration(seconds: 30)) ??
          at.subtract(const Duration(minutes: 3));
      final restWindow = pulse.where(
        (p) =>
            !p.at.isBefore(restFrom) &&
            p.at.isBefore(at.subtract(peakBefore ~/ 2)),
      );
      final baseline = restWindow.isEmpty
          ? restingHr
          : restWindow.map((p) => p.bpm).reduce((a, b) => a < b ? a : b);
      // Каким был бы пульс в момент пика без подхода: хвост прошлого спадает дальше.
      var withoutSet = baseline.toDouble();
      var carry = 0;
      final prevPeak = previousPeak;
      // Хвост учитываем, только если пульс к подходу ещё снижался: на плато
      // (пульс уже не падает) отдых закончен, и считать нечего.
      final rest = restWindow.toList();
      final declining = rest.length >= 2 && rest.first.bpm - baseline >= 3;
      if (prevPeak != null && declining) {
        final tail = expectedAfter(
          peak: prevPeak.bpm,
          restingHr: restingHr,
          after: top.at.difference(prevPeak.at),
          tau: tau,
        );
        // Модель — только поправка вниз: замеренный отдых ниже модели важнее.
        withoutSet = math.min(
          baseline.toDouble(),
          math.max(tail, restingHr * 1.0),
        );
        carry =
            (expectedAfter(
                      peak: prevPeak.bpm,
                      restingHr: restingHr,
                      after: at
                          .subtract(peakBefore ~/ 2)
                          .difference(prevPeak.at),
                      tau: tau,
                    ) -
                    restingHr)
                .round()
                .clamp(0, 250);
      }
      final rise = (peak - withoutSet).round().clamp(0, 250);
      // Тяжесть — по доле резерва, без той части пика, что осталась от прошлого.
      final share = (peak - restingHr - carry / 2) / reserve;
      out.add(
        SetEffort(
          exerciseId: id,
          setIndex: index,
          peak: peak,
          rise: rise,
          carryOver: carry,
          level: share >= hardReserve
              ? EffortLevel.hard
              : share <= lightReserve
              ? EffortLevel.light
              : EffortLevel.moderate,
        ),
      );
      previous = at;
      previousPeak = (bpm: peak, at: top.at);
    }
    return out.isEmpty ? null : SetEffortAnalysis(out, recoveryTau: tau);
  }

  /// Через сколько пульс [bpm] спадёт до восстановления (доля резерва
  /// [recoveredReserve]) при спаде с постоянной [tau]. Уже ниже — ноль.
  static Duration timeToRecover({
    required int bpm,
    required int restingHr,
    required int maxHr,
    Duration tau = defaultTau,
  }) {
    final reserve = (maxHr - restingHr).clamp(20, 200);
    final target = recoveredReserve * reserve;
    final excess = bpm - restingHr;
    if (excess <= target) return Duration.zero;
    final seconds = tau.inSeconds * math.log(excess / target);
    return Duration(seconds: seconds.round());
  }

  /// Подсказка во время отдыха: пульс ещё высокий — отдохни подольше.
  /// Сколько ещё — по скорости спада ([tau], оценка по этой тренировке).
  /// null — можно продолжать.
  static String? restHint({
    required int? bpm,
    required Duration left,
    required int restingHr,
    required int maxHr,
    Duration tau = defaultTau,
  }) {
    if (bpm == null || left > const Duration(seconds: 15)) return null;
    final reserve = (maxHr - restingHr).clamp(20, 200);
    if ((bpm - restingHr) / reserve < 0.5) return null;
    final wait = timeToRecover(
      bpm: bpm,
      restingHr: restingHr,
      maxHr: maxHr,
      tau: tau,
    );
    // Округляем до 10 с, от 20 с до 2 минут.
    final seconds = ((wait.inSeconds / 10).round() * 10).clamp(20, 120);
    return 'Пульс ещё $bpm — отдохни ещё $seconds с';
  }
}
