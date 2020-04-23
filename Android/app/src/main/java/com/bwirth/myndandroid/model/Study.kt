package com.bwirth.myndandroid.model

import android.content.Context
import android.util.Log
import com.bwirth.myndandroid.commons.Pref
import com.bwirth.myndandroid.commons.getPrefOrDefault
import com.bwirth.myndandroid.commons.getStudyState
import com.bwirth.myndandroid.commons.saveStudyState
import kotlinx.serialization.SerializationException

/**
 * A study comprises multiple scenarios, for example 'resting state', which defines the
 * order, type, and number of experimental blocks to be done.
 * The user's progress of the study as preserved as a state of the study, and can be loaded from
 * this Study object.
 * The study also takes care of creating different groups for balancing in experiments.
 */
object Study {
    var scenarios = mutableListOf<Scenario>()

    fun isFinished() = scenarios.all(Scenario::isFinished)

    fun getCurrentScenario() = scenarios.firstOrNull { !it.isFinished() }

    fun advance(c: Context): State {
        val scenario = getCurrentScenario()
        val block = scenario?.getCurrentBlock()
        block?.isFinished = true
        saveStudyState(c, scenarios)
        return when {
            scenario?.getCurrentBlock() != null -> State.MIDDLE_OF_SCENARIO
            isFinished() -> State.END_OF_STUDY
            else -> State.END_OF_SCENARIO
        }
    }

    fun loadState(c: Context) {
        this.scenarios = mutableListOf()
        val storedScenarios = try {
            getStudyState(c)
        } catch (e: SerializationException) {
            Log.e("Serialization", "Error when deserializing study state. Will fall back to whole study", e)
            null
        }
        if (storedScenarios != null) {
            Log.i("mynd_Study", "Using existing state")
            scenarios.addAll(storedScenarios)
        } else {
            Log.i("mynd_Study", "Initializing state")
            val subID = getPrefOrDefault<String>(c, Pref.SUBJECT_ID)
            scenarios.addAll(balancedFactory(subID,c).scenarios)
        }
        scenarios.forEach { it.init(c) }
        Log.i("mynd_Study", "Scenarios: " + scenarios.joinToString(", ") {it.paradigm})
        saveStudyState(c, scenarios)
    }

    private fun balancedFactory(subjectID: String, c: Context): Scenario.Factory{
        val group1: Scenario.Factory by lazy { Scenario.Factory(c)
                .restingState()
                .music()
                .memories()
                .restingState()
                .music()
                .memories()
        }
        val group2: Scenario.Factory by lazy { Scenario.Factory(c)
                .restingState()
                .memories()
                .music()
                .restingState()
                .memories()
                .music()
        }

        return try{
            val stringIndexOfDigits = subjectID.indexOfFirst { it.isDigit()}
            if(stringIndexOfDigits == -1){
                throw  Exception("Could not read the prticipant id '$subjectID'")
            } else{
                val subjectNumber = subjectID.substring(stringIndexOfDigits).trim().toInt()
                if(subjectNumber % 2 == 0) {
                    Log.i("mynd_Study", "using group 2")
                    group2
                } else {
                    Log.i("mynd_Study", "using group 1")
                    group1
                }
            }
        } catch (e: Exception) {
            Log.e("mynd_Study", "Could not read the prticipant id '$subjectID' for making a balanced condition study. Using group 1")
            group1
        }
    }

    enum class State {
        MIDDLE_OF_SCENARIO, END_OF_SCENARIO, END_OF_STUDY
    }


}