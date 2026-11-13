package com.ironrise.watch

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.view.View

/**
 * Кольцо по краю круглого экрана: серая дорожка и дуга пульса цветом зоны.
 * [fraction] 0–1 — доля дуги (пульс от максимума), без тренировки — 0.
 */
class RingView(context: Context) : View(context) {
    private val density = resources.displayMetrics.density
    private val stroke = 5 * density
    private val track = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = stroke
        color = Color.parseColor("#232325")
    }
    private val arc = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = stroke
        strokeCap = Paint.Cap.ROUND
    }
    private val bounds = RectF()

    var fraction = 0f
        set(value) {
            field = value.coerceIn(0f, 1f)
            invalidate()
        }

    var color = Color.parseColor("#C6FF3D")
        set(value) {
            field = value
            invalidate()
        }

    override fun onDraw(canvas: Canvas) {
        val inset = stroke / 2 + 3 * density
        bounds.set(inset, inset, width - inset, height - inset)
        canvas.drawOval(bounds, track)
        if (fraction > 0f) {
            arc.color = color
            canvas.drawArc(bounds, -90f, 360f * fraction, false, arc)
        }
    }
}
