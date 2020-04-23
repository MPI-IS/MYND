package com.bwirth.myndandroid.model

import android.content.Context
import android.util.Log
import kotlinx.serialization.Serializable
import kotlinx.serialization.Transient

/**
 * A phase is a temporal sequence happening in a trial. This class comprises the information.
 */
@Serializable
class Phase(val type: PhaseType, val duration: Double, val marker: Int) {
    private var textResID: String? = null
    private var instructionVarargs: Array<String>? = null
    @Transient // instead, will load from textResID
    var instruction: String = ""

    fun init(c: Context) {
        instruction = if (textResID == null) ""
        else if (instructionVarargs == null) {
            c.getString(c.resources.getIdentifier(textResID, "string", c.packageName))
        } else {
            c.getString(c.resources.getIdentifier(textResID, "string", c.packageName), *instructionVarargs!!)
        }
    }

    constructor(type: PhaseType, textResID: String, duration: Double, marker: Int, vararg instructionVarargs: String) :
            this(type, duration, marker) {
        this.textResID = if (textResID.isBlank()) null else textResID
        this.instructionVarargs = instructionVarargs.toList().toTypedArray()

    }


}

