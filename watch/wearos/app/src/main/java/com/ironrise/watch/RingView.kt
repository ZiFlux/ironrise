package com.ironrise.watch

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.SweepGradient
import android.view.View
import android.view.animation.LinearInterpolator
import kotlin.math.sin

/**
 * Кольцо по краю круглого экрана: серая дорожка и дуга пульса цветом зоны.
 * [fraction] 0–1 — доля дуги (пульс от максимума), без тренировки — 0.
 * [aura] — надетая аура: свечение под кольцом, на тренировке ярче и живее.
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
    private val glow = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
    private val bounds = RectF()
    private val glowBounds = RectF()

    /** Фаза анимации ауры, 0–1 за круг. */
    private var phase = 0f
    private val animator = ValueAnimator.ofFloat(0f, 1f).apply {
        duration = 4_000
        repeatCount = ValueAnimator.INFINITE
        interpolator = LinearInterpolator()
        addUpdateListener {
            phase = it.animatedValue as Float
            invalidate()
        }
    }

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

    /** Идёт тренировка — аура ярче и быстрее. */
    var active = false
        set(value) {
            if (field == value) return
            field = value
            animator.duration = if (value) 2_000 else 4_000
            invalidate()
        }

    var aura: WatchAura? = null
        set(value) {
            if (field == value) return
            field = value
            gradientFor = null
            updateAnimation()
            invalidate()
        }

    private var gradientFor: Pair<WatchAura, Float>? = null

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        updateAnimation()
    }

    override fun onDetachedFromWindow() {
        animator.cancel()
        super.onDetachedFromWindow()
    }

    override fun onVisibilityChanged(changedView: View, visibility: Int) {
        super.onVisibilityChanged(changedView, visibility)
        updateAnimation()
    }

    /** Анимация — только при видимой ауре: батарею часов бережём. */
    private fun updateAnimation() {
        val needed = aura != null && isAttachedToWindow && isShown
        if (needed && !animator.isStarted) animator.start()
        if (!needed && animator.isStarted) animator.cancel()
    }

    override fun onDraw(canvas: Canvas) {
        val inset = stroke / 2 + 3 * density
        bounds.set(inset, inset, width - inset, height - inset)
        aura?.let { drawAura(canvas, it, inset) }
        canvas.drawOval(bounds, track)
        if (fraction > 0f) {
            arc.color = color
            canvas.drawArc(bounds, -90f, 360f * fraction, false, arc)
        }
    }

    private fun drawAura(canvas: Canvas, aura: WatchAura, inset: Float) {
        val width = (if (active) 12 else 9) * density
        // Сразу внутри дорожки: на тренировке дуга пульса поверх, аура — под ней.
        val g = inset + stroke / 2 + width / 2
        glowBounds.set(g, g, this.width - g, height - g)
        glow.strokeWidth = width
        val cx = this.width / 2f
        val cy = height / 2f
        val key = aura to cx
        if (gradientFor != key) {
            glow.shader = SweepGradient(
                cx,
                cy,
                intArrayOf(aura.main, aura.light, aura.main, aura.light, aura.main),
                null,
            )
            gradientFor = key
        }
        val base = if (active) 0.8f else 0.6f
        val t = phase * 2 * Math.PI
        canvas.save()
        when (aura.style) {
            AuraStyle.FLAME -> {
                // Неровное мерцание из двух частот — как пламя.
                val flicker = 0.75f + 0.15f * sin(t * 7).toFloat() + 0.1f * sin(t * 13 + 1).toFloat()
                glow.alpha = (255 * base * flicker).toInt().coerceIn(0, 255)
                canvas.rotate(phase * 90f, cx, cy)
                canvas.drawOval(glowBounds, glow)
            }
            AuraStyle.SHIELD -> {
                // Ровное «дыхание», щит не вращается.
                val breath = 0.7f + 0.3f * sin(t * 2).toFloat()
                glow.alpha = (255 * base * breath).toInt().coerceIn(0, 255)
                canvas.drawOval(glowBounds, glow)
            }
            AuraStyle.LIGHTNING -> {
                // Рваные сегменты бегут по кругу рывками.
                glow.alpha = (255 * base).toInt()
                val step = (phase * 24).toInt()
                canvas.rotate(step * 15f, cx, cy)
                for (i in 0 until 6) {
                    val sweep = 22f + (i * 7 + step) % 4 * 6f
                    canvas.drawArc(glowBounds, i * 60f, sweep, false, glow)
                }
            }
            AuraStyle.FLOW -> {
                // Медленное плавное вращение.
                glow.alpha = (255 * base).toInt()
                canvas.rotate(phase * 360f, cx, cy)
                canvas.drawOval(glowBounds, glow)
            }
        }
        canvas.restore()
    }
}
