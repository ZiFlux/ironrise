package com.ironrise.watch

import android.content.Context
import android.util.Log
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.tasks.await

/**
 * Отправка пульса и шагов на телефон через Wearable Data Layer.
 * Формат сообщения совпадает с приёмом на телефоне (MainActivity.kt):
 * путь [PATH_PULSE], тело «пульс;шаги;время_мс».
 */
class PhoneLink(context: Context) {
    private val messages = Wearable.getMessageClient(context)
    private val nodes = Wearable.getNodeClient(context)
    private var phoneIds: List<String> = emptyList()
    private var nodesCheckedAt = 0L

    suspend fun sendPulse(bpm: Int, steps: Long, atMillis: Long) =
        send(PATH_PULSE, "$bpm;$steps;$atMillis")

    suspend fun sendStopped() = send(PATH_STOPPED, "")

    /** Ответ телефону: версия приложения на часах (п. 48 — одна версия). */
    suspend fun sendVersion(nodeId: String, version: String) {
        try {
            messages.sendMessage(nodeId, PATH_VERSION, version.toByteArray()).await()
        } catch (e: Exception) {
            Log.w(TAG, "Не удалось отправить версию", e)
        }
    }

    /** Что умеют часы: протокол и ауры, которые они рисуют. */
    suspend fun sendCaps(nodeId: String) {
        val body = "proto=$WATCH_PROTOCOL;auras=${Auras.ids.joinToString(",")};flash=1"
        try {
            messages.sendMessage(nodeId, PATH_CAPS, body.toByteArray()).await()
        } catch (e: Exception) {
            Log.w(TAG, "Не удалось отправить возможности", e)
        }
    }

    private suspend fun send(path: String, body: String) {
        try {
            for (id in connectedPhones()) {
                messages.sendMessage(id, path, body.toByteArray()).await()
            }
        } catch (e: Exception) {
            // Телефон вне связи: следующий отсчёт пульса придёт через секунду.
            Log.w(TAG, "Не удалось отправить на телефон", e)
        }
    }

    private suspend fun connectedPhones(): List<String> {
        val now = System.currentTimeMillis()
        if (phoneIds.isEmpty() || now - nodesCheckedAt > NODES_TTL_MS) {
            val connected = nodes.connectedNodes.await()
            Log.i(TAG, "Телефоны на связи: ${connected.map { it.displayName }}")
            phoneIds = connected.map { it.id }
            nodesCheckedAt = now
        }
        return phoneIds
    }

    companion object {
        const val PATH_PULSE = "/ironrise/pulse"
        const val PATH_STOPPED = "/ironrise/stopped"

        /** Команды от телефона (PhoneCommandService). */
        const val PATH_START = "/ironrise/start"
        const val PATH_STOP = "/ironrise/stop"

        /** Телефон спрашивает версию, часы отвечают на [PATH_VERSION]. */
        const val PATH_HELLO = "/ironrise/hello"
        const val PATH_VERSION = "/ironrise/version"
        const val PATH_CAPS = "/ironrise/caps"

        /** Аура вспыхнула в дуэли на телефоне (п. 83), тело — id ауры. */
        const val PATH_AURA_FLASH = "/ironrise/aura_flash"

        /** Сводка от телефона для плитки (DataItem). */
        const val PATH_SUMMARY = "/ironrise/summary"
        private const val NODES_TTL_MS = 30_000L
        private const val TAG = "IronRisePhoneLink"
    }
}
