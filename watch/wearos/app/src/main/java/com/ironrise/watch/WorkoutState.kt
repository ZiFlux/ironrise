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
)

/** Одно состояние на процесс: сервис пишет, экран читает. */
object WorkoutStore {
    private val mutable = MutableStateFlow(WorkoutState())
    val state: StateFlow<WorkoutState> = mutable.asStateFlow()

    fun started(atMillis: Long) = mutable.update { WorkoutState(active = true, startedAtMillis = atMillis) }

    fun pulse(bpm: Int) = mutable.update { it.copy(bpm = bpm) }

    fun steps(delta: Long) = mutable.update { it.copy(steps = it.steps + delta) }

    fun stopped() = mutable.update { it.copy(active = false) }

    fun failed(message: String) = mutable.update { it.copy(active = false, error = message) }
}
