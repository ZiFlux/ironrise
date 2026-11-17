package com.ironrise.watch

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.VibrationEffect
import android.os.VibratorManager
import androidx.core.app.NotificationCompat

/**
 * Аура вспыхнула в дуэли на телефоне (п. 83): вибрация узором ауры и короткое
 * уведомление её цветом. Неизвестная аура (новее часов) — только короткая вибрация.
 */
object AuraFlash {
    private const val CHANNEL_ID = "aura_flash"
    private const val NOTIFICATION_ID = 7301

    fun show(context: Context, kind: String) {
        val aura = Auras.of(kind)
        vibrate(context, aura?.style)
        if (aura == null) return
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Ауры в дуэли", NotificationManager.IMPORTANCE_HIGH),
        )
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("${aura.name} горит!")
            .setContentText(effectOf(aura.id))
            .setColor(aura.main)
            .setColorized(true)
            .setCategory(NotificationCompat.CATEGORY_EVENT)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            // Вспышка — не напоминание: само исчезает через 5 секунд.
            .setTimeoutAfter(5_000)
            .build()
        manager.notify(NOTIFICATION_ID, notification)
    }

    private fun effectOf(id: String) = when (id) {
        "fury" -> "Удары сильнее 3 хода"
        "guard" -> "Урон по тебе меньше 3 удара"
        "haste" -> "Лишний удар"
        "focus" -> "Удар без промаха с критом"
        else -> "Аура в дуэли"
    }

    /** Узор вибрации: пламя — рвано, щит — два мягких, молнии — дробь, фокус — один долгий. */
    private fun vibrate(context: Context, style: AuraStyle?) {
        val pattern = when (style) {
            AuraStyle.FLAME -> longArrayOf(0, 80, 40, 120, 40, 200)
            AuraStyle.SHIELD -> longArrayOf(0, 250, 150, 250)
            AuraStyle.LIGHTNING -> longArrayOf(0, 40, 30, 40, 30, 40, 30, 120)
            AuraStyle.FLOW -> longArrayOf(0, 500)
            null -> longArrayOf(0, 150)
        }
        val vibrator = context.getSystemService(VibratorManager::class.java)?.defaultVibrator ?: return
        vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
    }
}
