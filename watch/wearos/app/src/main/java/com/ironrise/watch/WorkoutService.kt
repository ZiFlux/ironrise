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
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.lifecycle.LifecycleService
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.launch

/**
 * Тренировка на часах: пульс и шаги с аппаратных датчиков, отправка на телефон.
 *
 * Почему не Health Services: на Galaxy Watch (Wear OS 6) ExerciseClient принимает
 * старт, но тренировку не запускает, а MeasureClient работает только при включённом
 * экране. Датчики через SensorManager в foreground-сервисе с wake lock работают и с
 * погасшим экраном.
 */
class WorkoutService : LifecycleService(), SensorEventListener {
    private val phone by lazy { PhoneLink(this) }
    private val sensors by lazy { getSystemService(SensorManager::class.java) }
    private var wakeLock: PowerManager.WakeLock? = null

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
        val heartRate = sensors.getDefaultSensor(Sensor.TYPE_HEART_RATE)
        if (heartRate == null) {
            WorkoutStore.failed("На часах нет датчика пульса")
            stopSelf()
            return
        }
        keepCpuAwake()
        sensors.registerListener(this, heartRate, SensorManager.SENSOR_DELAY_NORMAL)
        sensors.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)?.let {
            sensors.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL)
        }
        WorkoutStore.started(System.currentTimeMillis())
    }

    private fun stop() {
        releaseSensors()
        WorkoutStore.stopped()
        lifecycleScope.launch {
            phone.sendStopped()
            ServiceCompat.stopForeground(this@WorkoutService, ServiceCompat.STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
    }

    override fun onDestroy() {
        releaseSensors()
        super.onDestroy()
    }

    private fun releaseSensors() {
        sensors.unregisterListener(this)
        stepsAtStart = null
        wakeLock?.takeIf { it.isHeld }?.release()
    }

    override fun onSensorChanged(event: SensorEvent) {
        when (event.sensor.type) {
            Sensor.TYPE_HEART_RATE -> onPulse(event)
            Sensor.TYPE_STEP_COUNTER -> event.values.firstOrNull()?.let(::onSteps)
        }
    }

    override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) = Unit

    /** Без контакта с кожей датчик шлёт нули или помечает данные ненадёжными. */
    private fun onPulse(event: SensorEvent) {
        val bpm = event.values.firstOrNull()?.toInt() ?: return
        val unreliable = event.accuracy == SensorManager.SENSOR_STATUS_NO_CONTACT ||
            event.accuracy == SensorManager.SENSOR_STATUS_UNRELIABLE
        if (bpm <= 0 || unreliable) return
        WorkoutStore.pulse(bpm)
        lifecycleScope.launch {
            phone.sendPulse(bpm, WorkoutStore.state.value.steps, System.currentTimeMillis())
        }
    }

    private fun onSteps(total: Float) {
        val start = stepsAtStart ?: total.also { stepsAtStart = it }
        WorkoutStore.steps((total - start).toLong())
    }

    /** Экран гаснет, а процессор и датчик продолжают работать до конца тренировки. */
    private fun keepCpuAwake() {
        wakeLock = getSystemService(PowerManager::class.java)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "IronRise:workout")
            .apply { acquire(MAX_WORKOUT_MS) }
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

        /** Страховка: если тренировку забыли завершить, датчик выключится сам. */
        private const val MAX_WORKOUT_MS = 6 * 60 * 60 * 1000L

        fun start(context: Context) = context.startForegroundService(
            Intent(context, WorkoutService::class.java).setAction(ACTION_START),
        )

        fun stop(context: Context) = context.startService(
            Intent(context, WorkoutService::class.java).setAction(ACTION_STOP),
        )
    }
}
