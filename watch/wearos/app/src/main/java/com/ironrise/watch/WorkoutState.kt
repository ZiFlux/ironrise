package com.ironrise.watch

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/** Что показывает экран часов. Обновляется сервисом тренировки. */
data class WorkoutState(
    val active: Boolean = false,
    val startedAtMillis: Long? = null,
    val bpm: Int? = null,
    val steps: Long = 0,
    val error: String? = null,
    /** Сумма и число отсчётов пульса — для среднего. */
    val bpmSum: Long = 0,
    val bpmCount: Int = 0,
    val maxBpm: Int? = null,
) {
    val avgBpm: Int? get() = if (bpmCount > 0) (bpmSum / bpmCount).toInt() else null
}

/** Одно состояние на процесс: сервис пишет, экран читает. */
object WorkoutStore {
    private val mutable = MutableStateFlow(WorkoutState())
    val state: StateFlow<WorkoutState> = mutable.asStateFlow()

    fun started(atMillis: Long) = mutable.update { WorkoutState(active = true, startedAtMillis = atMillis) }

    fun pulse(bpm: Int) = mutable.update {
        it.copy(
            bpm = bpm,
            bpmSum = it.bpmSum + bpm,
            bpmCount = it.bpmCount + 1,
            maxBpm = maxOf(it.maxBpm ?: 0, bpm),
        )
    }

    fun steps(total: Long) = mutable.update { it.copy(steps = total) }

    fun stopped() = mutable.update { it.copy(active = false) }

    fun failed(message: String) = mutable.update { it.copy(active = false, error = message) }
}
