import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'training_log.dart';
import 'providers.dart';

/// Канал записи в календарь телефона (MainActivity.kt).
const _calendar = MethodChannel('ironrise/calendar');
const _enabledKey = 'calendar_export_v1';

/// Записывать ли тренировки в календарь (п. 44 бэклога). Календарь телефона
/// синхронизируется на часы — тренировки видны там с временем начала и конца.
class CalendarExportNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(prefsProvider).getBool(_enabledKey) ?? false;

  /// Включить: спрашиваем доступ к календарю. Отказ — остаётся выключенным.
  Future<bool> setEnabled(bool on) async {
    if (on) {
      if (!Platform.isAndroid) return false;
      final status = await Permission.calendarFullAccess.request();
      if (!status.isGranted) return false;
    }
    state = on;
    await ref.read(prefsProvider).setBool(_enabledKey, on);
    return true;
  }

  /// Тренировка — событием в календарь. Ошибки молча: тренировка уже сохранена.
  Future<void> export(LoggedWorkout w) async {
    if (!state || !Platform.isAndroid) return;
    final end = w.at;
    final start = end.subtract(w.duration);
    try {
      await _calendar.invokeMethod<bool>('add', {
        'title': calendarTitle(w),
        'description': calendarDescription(w),
        'start': start.millisecondsSinceEpoch,
        'end': end.millisecondsSinceEpoch,
      });
    } on PlatformException {
      // Нет доступа или календаря — пропускаем.
    }
  }
}

final calendarExportProvider = NotifierProvider<CalendarExportNotifier, bool>(
  CalendarExportNotifier.new,
);

/// «IronRise: силовая, 7 упр.» / «IronRise: кардио».
String calendarTitle(LoggedWorkout w) => w.kind == WorkoutKind.strength
    ? 'IronRise: силовая, ${w.exercises.length} упр.'
    : 'IronRise: кардио';

String calendarDescription(LoggedWorkout w) => [
  '${w.duration.inMinutes} мин',
  if (w.kind == WorkoutKind.strength) '${w.sets} подходов',
  if (w.avgHr != null) 'пульс ср ${w.avgHr}',
  if (w.maxHr != null) 'макс ${w.maxHr}',
  '+${w.xp} опыта',
].join(', ');
