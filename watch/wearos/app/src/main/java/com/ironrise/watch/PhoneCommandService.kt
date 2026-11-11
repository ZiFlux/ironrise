package com.ironrise.watch

import android.app.ForegroundServiceStartNotAllowedException
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

/**
 * Команды от телефона: тренировка на телефоне началась или закончилась.
 * Система будит этот сервис сама, приложение на часах открывать не нужно.
 */
class PhoneCommandService : WearableListenerService() {

    override fun onMessageReceived(event: MessageEvent) {
        when (event.path) {
            PhoneLink.PATH_START -> startWorkout()
            PhoneLink.PATH_STOP -> if (WorkoutStore.state.value.active) WorkoutService.stop(this)
        }
    }

    /**
     * Android может запретить запуск сервиса датчиков из фона. Тогда просим
     * одно нажатие: уведомление с вибрацией открывает экран и начинает тренировку.
     */
    private fun startWorkout() {
        try {
            WorkoutService.start(this)
        } catch (e: ForegroundServiceStartNotAllowedException) {
            Log.w(TAG, "Фоновый запуск запрещён, просим нажатие", e)
            askToStart()
        }
    }

    private fun askToStart() {
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Начало тренировки", NotificationManager.IMPORTANCE_HIGH),
        )
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java)
                .putExtra(MainActivity.EXTRA_AUTOSTART, true)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_pulse)
            .setContentTitle("Тренировка началась")
            .setContentText("Нажмите, чтобы часы передавали пульс")
            .setContentIntent(open)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_WORKOUT)
            .build()
        manager.notify(NOTIFICATION_ID, notification)
    }

    private companion object {
        const val CHANNEL_ID = "workout_start"
        const val NOTIFICATION_ID = 2
        const val TAG = "IronRiseCommands"
    }
}
