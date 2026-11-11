package com.ironrise.ironrise

import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.Wearable
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

// Health Connect запрашивает разрешения через registerForActivityResult —
// для этого нужна FragmentActivity (Android 14+).
class MainActivity : FlutterFragmentActivity() {
    private var watchListener: MessageClient.OnMessageReceivedListener? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, WATCH_CHANNEL)
            .setStreamHandler(WatchStream())
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
    }
}
