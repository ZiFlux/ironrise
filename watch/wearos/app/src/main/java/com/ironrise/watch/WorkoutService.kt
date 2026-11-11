package com.ironrise.watch

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.health.services.client.ExerciseClient
import androidx.health.services.client.ExerciseUpdateCallback
import androidx.health.services.client.HealthServices
import androidx.health.services.client.data.Availability
import androidx.health.services.client.data.DataType
import androidx.health.services.client.data.ExerciseConfig
import androidx.health.services.client.data.ExerciseLapSummary
import androidx.health.services.client.data.ExerciseType
import androidx.health.services.client.data.ExerciseUpdate
import androidx.lifecycle.LifecycleService
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.guava.await
import kotlinx.coroutines.launch

/**
 * Силовая тренировка через Health Services: пульс каждую секунду и шаги.
 * Работает как foreground-сервис, поэтому пульс идёт и при погасшем экране.
 */
class WorkoutService : LifecycleService() {
    private val exercises: ExerciseClient by lazy { HealthServices.getClient(this).exerciseClient }
    private val phone by lazy { PhoneLink(this) }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        super.onStartCommand(intent, flags, startId)
        when (intent?.action) {
            ACTION_START -> start()
            ACTION_STOP -> stop()
        }
        return START_NOT_STICKY
    }

    private fun start() {
        if (WorkoutStore.state.value.active) return
        goForeground()
        lifecycleScope.launch {
            try {
                exercises.setUpdateCallback(updates)
                exercises.startExerciseAsync(exerciseConfig()).await()
                WorkoutStore.started(System.currentTimeMillis())
            } catch (e: Exception) {
                Log.e(TAG, "Health Services не запустил тренировку", e)
                WorkoutStore.failed("Не удалось начать: ${e.message ?: "ошибка датчиков"}")
                stopSelf()
            }
        }
    }

    private fun stop() {
        lifecycleScope.launch {
            try {
                exercises.endExerciseAsync().await()
            } catch (e: Exception) {
                Log.w(TAG, "Тренировка уже завершена", e)
            }
            exercises.clearUpdateCallbackAsync(updates)
            WorkoutStore.stopped()
            phone.sendStopped()
            ServiceCompat.stopForeground(this@WorkoutService, ServiceCompat.STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
    }

    /** Шаги есть не у всех типов тренировок на всех часах — берём, если поддерживаются. */
    private suspend fun exerciseConfig(): ExerciseConfig {
        val supported = exercises.getCapabilitiesAsync().await()
            .getExerciseTypeCapabilities(ExerciseType.STRENGTH_TRAINING)
            .supportedDataTypes
        val wanted = setOf(DataType.HEART_RATE_BPM, DataType.STEPS).filter { it in supported }.toSet()
        return ExerciseConfig.builder(ExerciseType.STRENGTH_TRAINING)
            .setDataTypes(wanted)
            .setIsAutoPauseAndResumeEnabled(false)
            .setIsGpsEnabled(false)
            .build()
    }

    private val updates = object : ExerciseUpdateCallback {
        override fun onExerciseUpdateReceived(update: ExerciseUpdate) {
            val metrics = update.latestMetrics
            val bpm = metrics.getData(DataType.HEART_RATE_BPM).lastOrNull()?.value?.toInt()
            val stepsDelta = metrics.getData(DataType.STEPS).sumOf { it.value }
            if (stepsDelta > 0) WorkoutStore.steps(stepsDelta)
            if (bpm == null || bpm <= 0) return
            WorkoutStore.pulse(bpm)
            lifecycleScope.launch {
                phone.sendPulse(bpm, WorkoutStore.state.value.steps, System.currentTimeMillis())
            }
        }

        override fun onLapSummaryReceived(lapSummary: ExerciseLapSummary) = Unit

        override fun onRegistered() = Unit

        override fun onRegistrationFailed(throwable: Throwable) {
            Log.e(TAG, "Не удалось подписаться на данные тренировки", throwable)
        }

        override fun onAvailabilityChanged(dataType: DataType<*, *>, availability: Availability) = Unit
    }

    private fun goForeground() {
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Тренировка", NotificationManager.IMPORTANCE_LOW),
        )
        val openApp = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_pulse)
            .setContentTitle("IronRise")
            .setContentText("Тренировка идёт, пульс передаётся на телефон")
            .setContentIntent(openApp)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_WORKOUT)
            .build()
        ServiceCompat.startForeground(this, NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH)
    }

    companion object {
        private const val ACTION_START = "com.ironrise.watch.START"
        private const val ACTION_STOP = "com.ironrise.watch.STOP"
        private const val CHANNEL_ID = "workout"
        private const val NOTIFICATION_ID = 1
        private const val TAG = "IronRiseWorkout"

        fun start(context: Context) = context.startForegroundService(
            Intent(context, WorkoutService::class.java).setAction(ACTION_START),
        )

        fun stop(context: Context) = context.startService(
            Intent(context, WorkoutService::class.java).setAction(ACTION_STOP),
        )
    }
}
