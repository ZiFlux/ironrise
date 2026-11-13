package com.ironrise.watch

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/** Тренировка в журнале часов: когда, сколько и какой был пульс. */
data class JournalEntry(
    val startedAtMillis: Long,
    val endedAtMillis: Long,
    val avgBpm: Int?,
    val maxBpm: Int?,
    val steps: Long,
)

/**
 * Журнал тренировок на самих часах (п. 44 бэклога): последние [LIMIT] записей
 * с отметками времени. Хранится на часах — телефон для просмотра не нужен.
 */
object WorkoutJournal {
    private const val PREFS = "journal"
    private const val KEY = "entries"
    private const val LIMIT = 30

    fun all(context: Context): List<JournalEntry> {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null) ?: return emptyList()
        val array = runCatching { JSONArray(raw) }.getOrNull() ?: return emptyList()
        return (0 until array.length()).mapNotNull { i ->
            val o = array.optJSONObject(i) ?: return@mapNotNull null
            JournalEntry(
                startedAtMillis = o.optLong("start"),
                endedAtMillis = o.optLong("end"),
                avgBpm = o.optInt("avg", 0).takeIf { it > 0 },
                maxBpm = o.optInt("max", 0).takeIf { it > 0 },
                steps = o.optLong("steps"),
            )
        }
    }

    fun add(context: Context, entry: JournalEntry) {
        // Тренировка короче минуты — случайное нажатие, не храним.
        if (entry.endedAtMillis - entry.startedAtMillis < 60_000) return
        val list = listOf(entry) + all(context)
        val array = JSONArray()
        for (e in list.take(LIMIT)) {
            array.put(
                JSONObject()
                    .put("start", e.startedAtMillis)
                    .put("end", e.endedAtMillis)
                    .put("avg", e.avgBpm ?: 0)
                    .put("max", e.maxBpm ?: 0)
                    .put("steps", e.steps),
            )
        }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, array.toString()).apply()
    }
}
