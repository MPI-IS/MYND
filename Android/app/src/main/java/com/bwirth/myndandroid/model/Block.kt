package com.bwirth.myndandroid.model

import kotlinx.serialization.Serializable
const val AVERAGE_ESTIMATED_PROMPT_DURATION = 2.0

/**
 * A block is simply a container for a number of trials to be completed.
 * The experimental logic of randomization is handled in the Scenario class.
 */
@Serializable
class Block(val trials: List<Trial>) {
    var isFinished = false


    fun getDuration() = trials.map {trial ->
        trial.getDuration() + trial.phases.filter {it.type == PhaseType.PROMPT }.count() * AVERAGE_ESTIMATED_PROMPT_DURATION
    }.sum()
}