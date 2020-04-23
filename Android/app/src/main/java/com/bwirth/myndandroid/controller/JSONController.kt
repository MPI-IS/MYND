package com.bwirth.myndandroid.controller

import android.content.Context
import com.bwirth.myndandroid.R
import com.bwirth.myndandroid.activity.InstructionStep
import com.bwirth.myndandroid.commons.Pref
import com.bwirth.myndandroid.commons.getPrefOrNull
import org.json.JSONObject


fun loadSteps(c: Context, mode: String): Array<InstructionStep> {
    val instructions = mutableListOf<InstructionStep>()
    val json = JSONObject(loadJSONFromAsset(c, c.getString(R.string.steps_file)))
    val modes = json.getJSONArray("modes")
    for (i in 0 until modes.length()) {
        with(modes.getJSONObject(i)) {
            if (getString("mode") == mode) {
                val jsonInstr = getJSONArray("instructions")
                for (x in 0 until jsonInstr.length()) {
                    val ins = jsonInstr.getJSONObject(x)
                    instructions.add(InstructionStep(
                            id = ins.getString("name"),
                            instruction = personalizedInstruction(c,ins.getString("instruction")),
                            imageResource = ins.getString("pictureName")
                    ))
                }
            }

        }
    }
    return instructions.toTypedArray()
}

private fun personalizedInstruction(c: Context, raw: String): String{
    val patientName = getPrefOrNull(c, Pref.PATIENT_NAME) ?: ""
    val str = {s: Int -> c.getString(s)}
   return raw
           .replace("#possessivePatient#",str(R.string.posessivePatient), true)
           .replace("#patientName#",patientName, true)
           .replace("#helperName#",patientName, true)
}


fun loadJSONFromAsset(context: Context, fileName: String): String {
    val stream = context.assets.open(fileName)
    val size = stream.available()
    val buffer = ByteArray(size)
    stream.read(buffer)
    stream.close()
    return String(buffer)
}
