package com.ironrise.watch

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.view.Gravity
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.view.WindowManager
import android.widget.Button
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

/** Один экран: пульс крупно, время, шаги и кнопка «Начать / Завершить». */
class MainActivity : ComponentActivity() {
    private lateinit var bpmText: TextView
    private lateinit var detailsText: TextView
    private lateinit var actionButton: Button

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
        bpmText.text = state.bpm?.toString() ?: "—"
        actionButton.text = if (state.active) "Завершить" else "Начать"
        if (state.active) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        detailsText.text = when {
            state.error != null && !state.active -> state.error
            state.active -> details(state)
            else -> "Пульс пойдёт на телефон"
        }
    }

    private suspend fun tickClock() {
        while (true) {
            val state = WorkoutStore.state.value
            if (state.active) detailsText.text = details(state)
            delay(1_000 - SystemClock.uptimeMillis() % 1_000)
        }
    }

    private fun details(state: WorkoutState): String {
        val seconds = ((System.currentTimeMillis() - (state.startedAtMillis ?: System.currentTimeMillis())) / 1000)
        return "%d:%02d · %d шагов".format(seconds / 60, seconds % 60, state.steps)
    }

    private fun buildLayout(): LinearLayout {
        bpmText = TextView(this).apply {
            textSize = 48f
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            setTextColor(ACCENT)
            gravity = Gravity.CENTER
        }
        val unit = TextView(this).apply {
            text = "уд/мин"
            textSize = 12f
            setTextColor(MUTED)
            gravity = Gravity.CENTER
        }
        detailsText = TextView(this).apply {
            textSize = 14f
            setTextColor(SECONDARY)
            gravity = Gravity.CENTER
            setPadding(0, 8, 0, 12)
        }
        actionButton = Button(this).apply {
            setTextColor(ON_ACCENT)
            backgroundTintList = android.content.res.ColorStateList.valueOf(ACCENT)
            isAllCaps = false
            textSize = 15f
        }
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(BACKGROUND)
            setPadding(24, 24, 24, 24)
            addView(bpmText, LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT))
            addView(unit, LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT))
            addView(detailsText, LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT))
            addView(actionButton, LinearLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT))
        }
    }

    private companion object {
        val BACKGROUND = Color.parseColor("#0F0F10")
        val ACCENT = Color.parseColor("#C6FF3D")
        val ON_ACCENT = Color.parseColor("#111111")
        val SECONDARY = Color.parseColor("#A1A1A6")
        val MUTED = Color.parseColor("#85858B")
    }
}
