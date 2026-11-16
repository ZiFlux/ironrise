import 'package:flutter/services.dart';

const _sound = MethodChannel('ironrise/sound');

/// Короткие сигналы тренировки (п. 72): старт упражнения и начало отдыха.
/// Звук — через поток уведомлений Android (учитывает громкость и беззвучный
/// режим), плюс короткая вибрация. Ошибки не мешают тренировке.
abstract final class TrainingSound {
  static Future<void> start() => _play('start', HapticFeedback.heavyImpact);

  static Future<void> rest() => _play('rest', HapticFeedback.lightImpact);

  static Future<void> _play(
    String method,
    Future<void> Function() haptic,
  ) async {
    try {
      await haptic();
      await _sound.invokeMethod<bool>(method);
    } catch (_) {
      // Нет канала (тесты, не Android) — молча.
    }
  }
}
