package com.bwirth.myndandroid.model

import com.bwirth.myndandroid.commons.rand
import com.bwirth.myndandroid.model.PhaseType.*
import com.bwirth.myndandroid.model.TrialType.*
import kotlinx.serialization.Serializable


/**
 * A trial is the smallest unit of an experiment. it consists of a text being displayed on the screen
 * for a given duration (plus some jitter). The welcome and goodbye trials are used in the beginning
 * and end of blocks. They are not part of the experiment itself,
 * but prepare the participant to concentrate or to let him/her know when done.
 */
@Serializable
class Trial(val type: TrialType, val phases: List<Phase>) {
    fun getDuration() = phases.map(Phase::duration).sum()
}

fun createTrials(amount: Int, type: TrialType, marker: Int): List<Trial> {
    return (1..amount).map { createTrial(type, marker) }
}

fun jittered(target: Double) = target + rand(-1.0, 1.0)


fun createTrial(type: TrialType, marker: Int): Trial {
    val phases = mutableListOf<Phase>()
    when (type) {
        WELCOME -> {
            phases.add(Phase(PROMPT, "trial_sitstill", 0.0, marker + 10))
            phases.add(Phase(FIXATION, 5.0, marker + 10))
        }
        GOODBYE -> {
            phases.add(Phase(PROMPT, "trial_thankyou", 0.0, marker + 10))
        }
        EYESOPEN -> {
            phases.add(Phase(PROMPT, "trial_eyesopen", 0.0, marker + 10))
            phases.add(Phase(FIXATION, 60.0, marker + 20))
            phases.add(Phase(PAUSE, "trial_takebreak", jittered(5.0), marker + 30))
        }
        EYESCLOSED -> {
            phases.add(Phase(PROMPT, "trial_eyesclosed", 0.0, marker + 10))
            phases.add(Phase(FIXATION, 60.0, marker + 20))
            phases.add(Phase(PAUSE, "trial_takebreak", jittered(5.0), marker + 30))
        }
        MUSIC -> {
            phases.add(Phase(PROMPT, "trial_getready", 0.0, marker))
            phases.add(Phase(FIXATION, 3.0, marker + 5))
            phases.add(Phase(PROMPT, "trial_musicimagery", 0.0, marker + 10))
            phases.add(Phase(FIXATION, 30.0, marker + 20))
            phases.add(Phase(PAUSE, "trial_takebreak", jittered(5.0), marker + 30))
        }
        POSITIVEMEMORIES -> {
            phases.add(Phase(PROMPT, "trial_getready", 0.0, marker))
            phases.add(Phase(FIXATION, 3.0, marker + 5))
            phases.add(Phase(PROMPT, "trial_positivememory", 0.0, marker + 10))
            phases.add(Phase(FIXATION, 30.0, marker + 20))
            phases.add(Phase(PAUSE, "trial_takebreak", jittered(5.0), marker + 30))
        }
        MENTALSUBTRACTION -> {
            var randBig: Int
            var randSmall: Int
            do {
                randBig = rand(500, 900)
            } while ((randBig % 5 == 0) || (randBig % 10 == 0))
            do {
                randSmall = rand(3, 9)
            } while (randSmall % 5 == 0)

            phases.add(Phase(PROMPT, "trial_getready", 0.0, marker))
            phases.add(Phase(FIXATION, 3.0, marker + 5))
            phases.add(Phase(PROMPT, "trial_mentalsubtraction", 0.0, marker + 10,  randBig.toString(), randSmall.toString()))
            phases.add(Phase(FIXATION, 30.0, marker + 20))
            phases.add(Phase(PAUSE, 5.0, marker + 30))

        }
    }
    return Trial(type, phases)
}

