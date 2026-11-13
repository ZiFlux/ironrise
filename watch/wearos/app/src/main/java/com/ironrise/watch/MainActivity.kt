package com.ironrise.watch

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.text.format.DateUtils
import android.view.Gravity
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Экран тренировки на часах: время, пульс крупно с цветом зоны, средний и
 * максимальный пульс, шаги, «Начать / Завершить» и журнал тренировок.
 */
class MainActivity : ComponentActivity() {
    private lateinit var timeText: TextView
    private lateinit var bpmText: TextView
    private lateinit var zoneText: TextView
    private lateinit var detailsText: TextView
    private lateinit var actionButton: Button
    private lateinit var ring: RingView

    private val permissionRequest =
        registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { granted ->
            if (granted[heartRatePermission] == true) WorkoutService.start(this)
            else detailsText.text = "Нужен доступ к пульсу"
        }

    /** С Wear OS 6 (Android 16) пульс читается по health-разрешению. */
    private val heartRatePermission =
        if (Build.VERSION.SDK_INT >= 36) "android.permission.health.READ_HEART_RATE"
        else Manifest.permission.BODY_SENSORS

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(buildLayout())
        actionButton.setOnClickListener { onActionClick() }
        // Открыли по уведомлению «Тренировка началась» — сразу включаем пульс.
        if (intent.getBooleanExtra(EXTRA_AUTOSTART, false) && !WorkoutStore.state.value.active) onActionClick()
        lifecycleScope.launch {
            repeatOnLifecycle(Lifecycle.State.STARTED) {
                launch { WorkoutStore.state.collect(::render) }
                launch { tickClock() }
            }
        }
    }

    private fun onActionClick() {
        if (WorkoutStore.state.value.active) {
            WorkoutService.stop(this)
            return
        }
        val needed = listOf(heartRatePermission, Manifest.permission.ACTIVITY_RECOGNITION, Manifest.permission.POST_NOTIFICATIONS)
            .filter { ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED }
        if (needed.isEmpty()) WorkoutService.start(this) else permissionRequest.launch(needed.toTypedArray())
    }

    private fun render(state: WorkoutState) {
        val zone = Zone.of(state.bpm)
        bpmText.text = state.bpm?.toString() ?: "—"
        bpmText.setTextColor(if (state.active) zone.color else MUTED)
        zoneText.text = if (state.active && state.bpm != null) "уд/мин · ${zone.label}" else "уд/мин"
        actionButton.text = if (state.active) "Завершить" else "Начать"
        (actionButton.background as? android.graphics.drawable.GradientDrawable)?.setColor(if (state.active) STOP else ACCENT)
        // Дуга по краю: пульс от максимума (190), цвет зоны.
        ring.color = zone.color
        ring.fraction = if (state.active) (state.bpm ?: 0) / 190f else 0f
        if (state.active) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        renderTime(state)
        detailsText.text = when {
            state.error != null && !state.active -> state.error
            state.active -> listOfNotNull(
                state.avgBpm?.let { "ср $it" },
                state.maxBpm?.let { "макс $it" },
                "${state.steps} шаг.",
            ).joinToString(" · ")
            else -> lastWorkoutLine()
        }
    }

    private fun renderTime(state: WorkoutState) {
        val start = state.startedAtMillis
        timeText.text = if (state.active && start != null) {
            val seconds = (System.currentTimeMillis() - start) / 1000
            if (seconds >= 3600) "%d:%02d:%02d".format(seconds / 3600, seconds / 60 % 60, seconds % 60)
            else "%d:%02d".format(seconds / 60, seconds % 60)
        } else {
            "IronRise"
        }
        timeText.setTextColor(if (state.active) PRIMARY else SECONDARY)
    }

    /** Без тренировки — когда была последняя. */
    private fun lastWorkoutLine(): String {
        val last = WorkoutJournal.all(this).firstOrNull() ?: return "Пульс пойдёт на телефон"
        val ago = DateUtils.getRelativeTimeSpanString(
            last.startedAtMillis, System.currentTimeMillis(), DateUtils.MINUTE_IN_MILLIS,
        )
        val minutes = (last.endedAtMillis - last.startedAtMillis) / 60_000
        return "Последняя: $ago, $minutes мин"
    }

    private suspend fun tickClock() {
        while (true) {
            renderTime(WorkoutStore.state.value)
            delay(1_000 - SystemClock.uptimeMillis() % 1_000)
        }
    }

    private fun buildLayout(): FrameLayout {
        timeText = TextView(this).apply {
            textSize = 15f
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            gravity = Gravity.CENTER
        }
        bpmText = TextView(this).apply {
            textSize = 34f
            typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
            gravity = Gravity.CENTER
            includeFontPadding = false
        }
        zoneText = TextView(this).apply {
            textSize = 11f
            setTextColor(MUTED)
            gravity = Gravity.CENTER
        }
        detailsText = TextView(this).apply {
            textSize = 11f
            setTextColor(SECONDARY)
            gravity = Gravity.CENTER
            maxLines = 2
            setPadding(0, dp(2), 0, dp(6))
        }
        actionButton = Button(this).apply {
            setTextColor(ON_ACCENT)
            isAllCaps = false
            textSize = 13f
            gravity = Gravity.CENTER
            minHeight = 0
            minimumHeight = 0
            minWidth = 0
            minimumWidth = 0
            setPadding(dp(18), dp(6), dp(18), dp(6))
            background = android.graphics.drawable.GradientDrawable().apply {
                cornerRadius = dp(20).toFloat()
                setColor(ACCENT)
            }
        }
        val journal = TextView(this).apply {
            text = "Журнал"
            textSize = 11f
            setTextColor(ACCENT)
            gravity = Gravity.CENTER
            setPadding(dp(12), dp(6), dp(12), dp(2))
            setOnClickListener { startActivity(Intent(this@MainActivity, JournalActivity::class.java)) }
        }
        ring = RingView(this)
        // Всё — во вписанном в круг квадрате (сторона ≈ 0,7 диаметра), по центру:
        // на круглом экране ничего не уходит за край.
        val side = (resources.displayMetrics.widthPixels * 0.72f).toInt()
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            addView(timeText, LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT))
            addView(bpmText, LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT))
            addView(zoneText, LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT))
            addView(detailsText, LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT))
            addView(actionButton, LinearLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT))
            addView(journal, LinearLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT))
        }
        return FrameLayout(this).apply {
            setBackgroundColor(BACKGROUND)
            addView(ring, FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))
            addView(content, FrameLayout.LayoutParams(side, side, Gravity.CENTER))
        }
    }

    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()

    /**
     * Цвет пульса: до 100 — зелёный (норма), до 125 — жёлтый (повышен),
     * выше 125 — красный (высокий). Простая шкала, понятная с одного взгляда.
     */
    private enum class Zone(val label: String, val color: Int, val upTo: Int) {
        Normal("норма", Color.parseColor("#2EBD59"), 101),
        Raised("повышен", Color.parseColor("#FFC93D"), 126),
        High("высокий", Color.parseColor("#E5484D"), Int.MAX_VALUE);

        companion object {
            fun of(bpm: Int?): Zone = if (bpm == null) Normal else entries.first { bpm < it.upTo }
        }
    }

    companion object {
        const val EXTRA_AUTOSTART = "autostart"
        private val BACKGROUND = Color.parseColor("#0F0F10")
        private val ACCENT = Color.parseColor("#C6FF3D")
        private val STOP = Color.parseColor("#FF7A3D")
        private val ON_ACCENT = Color.parseColor("#111111")
        private val PRIMARY = Color.parseColor("#EDEDED")
        private val SECONDARY = Color.parseColor("#A1A1A6")
        private val MUTED = Color.parseColor("#85858B")
    }
}
