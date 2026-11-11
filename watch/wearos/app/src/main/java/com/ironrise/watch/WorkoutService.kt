package com.ironrise.watch

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.health.services.client.ExerciseClient
import androidx.health.services.client.ExerciseUpdateCallback
import androidx.health.services.client.HealthServices
import androidx.health.services.client.MeasureCallback
import androidx.health.services.client.MeasureClient
import androidx.health.services.client.data.Availability
import androidx.health.services.client.data.DataPointContainer
import androidx.health.services.client.data.DataType
import androidx.health.services.client.data.DeltaDataType
import androidx.health.services.client.data.ExerciseConfig
import androidx.health.services.client.data.ExerciseLapSummary
import androidx.health.services.client.data.ExerciseTrackedStatus
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
class WorkoutService : LifecycleService(), SensorEventListener {
    private val exercises: ExerciseClient by lazy { HealthServices.getClient(this).exerciseClient }
    private val measure: MeasureClient by lazy { HealthServices.getClient(this).measureClient }
    private val phone by lazy { PhoneLink(this) }
    private val sensors by lazy { getSystemService(SensorManager::class.java) }

    /** Показание счётчика шагов в начале тренировки: он считает с перезагрузки часов. */
    private var stepsAtStart: Float? = null

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
                endLeftoverExercise()
                exercises.setUpdateCallback(updates)
                exercises.startExerciseAsync(exerciseConfig()).await()
                // Основной источник пульса — прямая подписка на датчик. Тренировка через
                // ExerciseClient на Galaxy Watch (Wear OS 6) принимает старт, но не идёт:
                // статус остаётся «нет тренировки», обновления не приходят.
                measure.registerMeasureCallback(DataType.HEART_RATE_BPM, directPulse)
                startCountingSteps()
                WorkoutStore.started(System.currentTimeMillis())
                Log.i(TAG, "Тренировка: ${exercises.getCurrentExerciseInfoAsync().await().exerciseTrackedStatus}")
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
            sensors.unregisterListener(this@WorkoutService)
            stepsAtStart = null
            try {
                measure.unregisterMeasureCallbackAsync(DataType.HEART_RATE_BPM, directPulse).await()
            } catch (e: Exception) {
                Log.w(TAG, "Подписка на пульс уже снята", e)
            }
            WorkoutStore.stopped()
            phone.sendStopped()
            ServiceCompat.stopForeground(this@WorkoutService, ServiceCompat.STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
    }

    /** Тренировка нашего приложения могла остаться после падения или обновления. */
    private suspend fun endLeftoverExercise() {
        val current = exercises.getCurrentExerciseInfoAsync().await()
        if (current.exerciseTrackedStatus == ExerciseTrackedStatus.OWNED_EXERCISE_IN_PROGRESS) {
            exercises.endExerciseAsync().await()
        }
    }

    /**
     * Берём первый вид тренировки, где пульс поддерживается.
     */
    private suspend fun exerciseConfig(): ExerciseConfig {
        val capabilities = exercises.getCapabilitiesAsync().await()
        val supportedTypes = capabilities.supportedExerciseTypes
        Log.i(TAG, "Поддерживаемые тренировки: $supportedTypes")
        val type = PREFERRED_TYPES.firstOrNull { candidate ->
            candidate in supportedTypes &&
                DataType.HEART_RATE_BPM in capabilities.getExerciseTypeCapabilities(candidate).supportedDataTypes
        } ?: throw IllegalStateException("часы не отдают пульс ни для одного вида тренировки")
        val supportedData = capabilities.getExerciseTypeCapabilities(type).supportedDataTypes
        Log.i(TAG, "Тренировка $type, данные: $supportedData")
        return ExerciseConfig.builder(type)
            .setDataTypes(setOf(DataType.HEART_RATE_BPM))
            .setIsAutoPauseAndResumeEnabled(false)
            .setIsGpsEnabled(false)
            .build()
    }

    private val updates = object : ExerciseUpdateCallback {
        override fun onExerciseUpdateReceived(update: ExerciseUpdate) {
            val metrics = update.latestMetrics
            metrics.getData(DataType.HEART_RATE_BPM).lastOrNull()?.value?.let(::onPulse)
        }

        override fun onLapSummaryReceived(lapSummary: ExerciseLapSummary) = Unit

        override fun onRegistered() {
            Log.i(TAG, "Приёмник обновлений зарегистрирован")
        }

        override fun onRegistrationFailed(throwable: Throwable) {
            Log.e(TAG, "Не удалось подписаться на данные тренировки", throwable)
        }

        override fun onAvailabilityChanged(dataType: DataType<*, *>, availability: Availability) {
            Log.d(TAG, "Доступность ${dataType.name}: $availability")
        }
    }

    private val directPulse = object : MeasureCallback {
        override fun onDataReceived(data: DataPointContainer) {
            data.getData(DataType.HEART_RATE_BPM).lastOrNull()?.value?.let(::onPulse)
        }

        override fun onAvailabilityChanged(dataType: DeltaDataType<*, *>, availability: Availability) {
            Log.d(TAG, "Датчик пульса: $availability")
        }
    }

    /** Пульс из любого источника: показать на часах и отправить на телефон. */
    private fun onPulse(value: Double) {
        val bpm = value.toInt()
        if (bpm <= 0) return
        WorkoutStore.pulse(bpm)
        lifecycleScope.launch {
            phone.sendPulse(bpm, WorkoutStore.state.value.steps, System.currentTimeMillis())
        }
    }

    /** Шаги — с аппаратного счётчика: он работает на всех часах и почти не тратит заряд. */
    private fun startCountingSteps() {
        val counter = sensors.getDefaultSensor(Sensor.TYPE_STEP_COUNTER) ?: return
        sensors.registerListener(this, counter, SensorManager.SENSOR_DELAY_NORMAL)
    }

    override fun onSensorChanged(event: SensorEvent) {
        val total = event.values.firstOrNull() ?: return
        val start = stepsAtStart ?: total.also { stepsAtStart = it }
        WorkoutStore.steps((total - start).toLong())
    }

    override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) = Unit

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

        /** По порядку предпочтения: чем ближе к залу, тем лучше. */
        private val PREFERRED_TYPES = listOf(
            ExerciseType.STRENGTH_TRAINING,
            ExerciseType.WEIGHTLIFTING,
            ExerciseType.CALISTHENICS,
            ExerciseType.WORKOUT,
            ExerciseType.EXERCISE_CLASS,
            ExerciseType.WALKING,
        )

        fun start(context: Context) = context.startForegroundService(
            Intent(context, WorkoutService::class.java).setAction(ACTION_START),
        )

        fun stop(context: Context) = context.startService(
            Intent(context, WorkoutService::class.java).setAction(ACTION_STOP),
        )
    }
}
