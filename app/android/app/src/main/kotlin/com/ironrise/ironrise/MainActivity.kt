package com.ironrise.ironrise

import android.content.ContentValues
import android.media.AudioManager
import android.media.ToneGenerator
import android.provider.CalendarContract
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.PutDataMapRequest
import java.util.TimeZone
import com.google.android.gms.wearable.Wearable
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

// Health Connect запрашивает разрешения через registerForActivityResult —
// для этого нужна FragmentActivity (Android 14+).
class MainActivity : FlutterFragmentActivity() {
    private var watchListener: MessageClient.OnMessageReceivedListener? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, WATCH_CHANNEL)
            .setStreamHandler(WatchStream())
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WATCH_CONTROL_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> sendToWatch(PATH_START, result)
                    "stop" -> sendToWatch(PATH_STOP, result)
                    // Спросить версию приложения на часах: ответ придёт в WatchStream.
                    "hello" -> sendToWatch(PATH_HELLO, result)
                    // Аура вспыхнула в дуэли (п. 83): старые часы путь пропустят.
                    "auraFlash" -> sendToWatch(
                        PATH_AURA_FLASH,
                        result,
                        (call.argument<String>("kind") ?: "").toByteArray(),
                    )
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SUMMARY_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "publish") return@setMethodCallHandler result.notImplemented()
                publishSummary(
                    streak = call.argument<Number>("streak")?.toInt() ?: 0,
                    today = call.argument<String>("today") ?: "",
                    level = call.argument<String>("level") ?: "",
                    aura = call.argument<String>("aura") ?: "",
                    auraState = call.argument<String>("auraState") ?: "",
                )
                result.success(true)
            }
        // Короткие сигналы тренировки: старт упражнения и начало отдыха (п. 72).
        // Поток уведомлений — громкость и беззвучный режим телефона учитываются.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SOUND_CHANNEL)
            .setMethodCallHandler { call, result ->
                val (tone, ms) = when (call.method) {
                    "start" -> ToneGenerator.TONE_PROP_BEEP2 to 400
                    "rest" -> ToneGenerator.TONE_PROP_ACK to 300
                    else -> return@setMethodCallHandler result.notImplemented()
                }
                result.success(runCatching { beep(tone, ms) }.isSuccess)
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALENDAR_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "add") return@setMethodCallHandler result.notImplemented()
                result.success(
                    runCatching {
                        addToCalendar(
                            title = call.argument<String>("title") ?: "IronRise",
                            description = call.argument<String>("description") ?: "",
                            start = call.argument<Number>("start")!!.toLong(),
                            end = call.argument<Number>("end")!!.toLong(),
                        )
                    }.getOrDefault(false),
                )
            }
    }

    /**
     * Сводка для виджета и плитки на часах: серия, что сегодня, уровень героя.
     * Виджет читает её из SharedPreferences, часы получают через Data Layer.
     */
    private fun publishSummary(streak: Int, today: String, level: String, aura: String, auraState: String) {
        getSharedPreferences(SummaryWidget.PREFS, MODE_PRIVATE).edit()
            .putInt("streak", streak)
            .putString("today", today)
            .putString("level", level)
            .apply()
        SummaryWidget.refresh(applicationContext)
        val request = PutDataMapRequest.create(PATH_SUMMARY).apply {
            dataMap.putInt("streak", streak)
            dataMap.putString("today", today)
            dataMap.putString("level", level)
            // Надетая аура (id из AuraKind). Старые часы ключ не читают, новые
            // рисуют эффект, только если знают этот id.
            dataMap.putString("aura", aura)
            dataMap.putString("auraState", auraState)
        }.asPutDataRequest().setUrgent()
        Wearable.getDataClient(applicationContext).putDataItem(request)
    }

    /**
     * Тренировка — событием в основной календарь телефона (п. 44 бэклога).
     * Календарь Google/Samsung сам синхронизируется на часы. Разрешение на календарь
     * запрашивает Dart-сторона; без него — false.
     */
    private fun addToCalendar(title: String, description: String, start: Long, end: Long): Boolean {
        val projection = arrayOf(
            CalendarContract.Calendars._ID,
            CalendarContract.Calendars.IS_PRIMARY,
            CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL,
            CalendarContract.Calendars.VISIBLE,
        )
        var calendarId: Long? = null
        contentResolver.query(CalendarContract.Calendars.CONTENT_URI, projection, null, null, null)?.use { c ->
            while (c.moveToNext()) {
                val writable = c.getInt(2) >= CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR && c.getInt(3) == 1
                if (!writable) continue
                if (calendarId == null || c.getInt(1) == 1) calendarId = c.getLong(0)
                if (c.getInt(1) == 1) break
            }
        }
        val id = calendarId ?: return false
        val values = ContentValues().apply {
            put(CalendarContract.Events.CALENDAR_ID, id)
            put(CalendarContract.Events.TITLE, title)
            put(CalendarContract.Events.DESCRIPTION, description)
            put(CalendarContract.Events.DTSTART, start)
            put(CalendarContract.Events.DTEND, end)
            put(CalendarContract.Events.EVENT_TIMEZONE, TimeZone.getDefault().id)
        }
        return contentResolver.insert(CalendarContract.Events.CONTENT_URI, values) != null
    }

    /** Команда приложению на часах. Отвечает true, если хоть одни часы на связи. */
    private fun sendToWatch(path: String, result: MethodChannel.Result, body: ByteArray = ByteArray(0)) {
        val messages = Wearable.getMessageClient(applicationContext)
        Wearable.getNodeClient(applicationContext).connectedNodes
            .addOnSuccessListener { nodes ->
                nodes.forEach { messages.sendMessage(it.id, path, body) }
                result.success(nodes.isNotEmpty())
            }
            .addOnFailureListener { result.success(false) }
    }

    /**
     * Сообщения от приложения IronRise на часах (watch/wearos, PhoneLink.kt):
     * «pulse;пульс;шаги;время_мс» или «stopped».
     */
    private inner class WatchStream : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
            val listener = MessageClient.OnMessageReceivedListener { message ->
                when (message.path) {
                    PATH_PULSE -> events.success("pulse;" + String(message.data))
                    PATH_STOPPED -> events.success("stopped")
                    PATH_VERSION -> events.success("version;" + String(message.data))
                    // Что умеют часы: «proto=2;auras=fury,guard». Старые часы не шлют.
                    PATH_CAPS -> events.success("caps;" + String(message.data))
                    // Прочие пути — от более новых часов: молча пропускаем.
                }
            }
            watchListener = listener
            Wearable.getMessageClient(applicationContext).addListener(listener)
        }

        override fun onCancel(arguments: Any?) {
            watchListener?.let { Wearable.getMessageClient(applicationContext).removeListener(it) }
            watchListener = null
        }
    }

    private var tones: ToneGenerator? = null

    private fun beep(tone: Int, ms: Int) {
        val gen = tones ?: ToneGenerator(AudioManager.STREAM_NOTIFICATION, 80).also { tones = it }
        gen.startTone(tone, ms)
    }

    override fun onDestroy() {
        tones?.release()
        tones = null
        super.onDestroy()
    }

    private companion object {
        const val WATCH_CHANNEL = "ironrise/watch"
        const val PATH_PULSE = "/ironrise/pulse"
        const val PATH_STOPPED = "/ironrise/stopped"
        const val WATCH_CONTROL_CHANNEL = "ironrise/watch_control"
        const val PATH_START = "/ironrise/start"
        const val PATH_STOP = "/ironrise/stop"
        const val PATH_HELLO = "/ironrise/hello"
        const val PATH_VERSION = "/ironrise/version"
        const val PATH_CAPS = "/ironrise/caps"
        const val PATH_AURA_FLASH = "/ironrise/aura_flash"
        const val CALENDAR_CHANNEL = "ironrise/calendar"
        const val SOUND_CHANNEL = "ironrise/sound"
        const val SUMMARY_CHANNEL = "ironrise/summary"
        const val PATH_SUMMARY = "/ironrise/summary"
    }
}
