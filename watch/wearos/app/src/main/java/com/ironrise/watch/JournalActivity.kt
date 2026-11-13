package com.ironrise.watch

import android.graphics.Color
import android.graphics.Typeface
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.activity.ComponentActivity
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Журнал тренировок на часах: дата, время начала и конца, пульс, шаги. */
class JournalActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val list = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(32, 36, 32, 48)
        }
        list.addView(text("Журнал", 17f, PRIMARY, bold = true))
        val entries = WorkoutJournal.all(this)
        if (entries.isEmpty()) {
            list.addView(text("Тренировок на часах пока нет", 13f, SECONDARY))
        }
        val day = SimpleDateFormat("d MMM", Locale("ru"))
        val time = SimpleDateFormat("HH:mm", Locale("ru"))
        for (e in entries) {
            val minutes = (e.endedAtMillis - e.startedAtMillis) / 60_000
            list.addView(
                text(
                    "${day.format(Date(e.startedAtMillis))}, ${time.format(Date(e.startedAtMillis))}–" +
                        "${time.format(Date(e.endedAtMillis))} · $minutes мин",
                    14f,
                    PRIMARY,
                ).apply { setPadding(0, 14, 0, 0) },
            )
            val pulse = listOfNotNull(e.avgBpm?.let { "ср $it" }, e.maxBpm?.let { "макс $it" }, "${e.steps} шаг.")
            list.addView(text(pulse.joinToString(" · "), 12f, SECONDARY))
        }
        setContentView(
            ScrollView(this).apply {
                setBackgroundColor(Color.parseColor("#0F0F10"))
                isVerticalScrollBarEnabled = false
                addView(list, LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT))
            },
        )
    }

    private fun text(value: String, size: Float, color: Int, bold: Boolean = false) = TextView(this).apply {
        text = value
        textSize = size
        setTextColor(color)
        gravity = Gravity.CENTER
        if (bold) typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
        layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT)
    }

    private companion object {
        val PRIMARY = Color.parseColor("#EDEDED")
        val SECONDARY = Color.parseColor("#A1A1A6")
    }
}
