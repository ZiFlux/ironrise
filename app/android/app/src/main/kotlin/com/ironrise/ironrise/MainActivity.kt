package com.ironrise.ironrise

import com.google.android.gms.wearable.MessageClient
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
                    else -> result.notImplemented()
                }
            }
    }

    /** Команда приложению на часах. Отвечает true, если хоть одни часы на связи. */
    private fun sendToWatch(path: String, result: MethodChannel.Result) {
        val messages = Wearable.getMessageClient(applicationContext)
        Wearable.getNodeClient(applicationContext).connectedNodes
            .addOnSuccessListener { nodes ->
                nodes.forEach { messages.sendMessage(it.id, path, ByteArray(0)) }
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

    private companion object {
        const val WATCH_CHANNEL = "ironrise/watch"
        const val PATH_PULSE = "/ironrise/pulse"
        const val PATH_STOPPED = "/ironrise/stopped"
        const val WATCH_CONTROL_CHANNEL = "ironrise/watch_control"
        const val PATH_START = "/ironrise/start"
        const val PATH_STOP = "/ironrise/stop"
    }
}
