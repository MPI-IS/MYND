package com.bwirth.myndandroid.model

import android.util.Log

data class EEGData(val values: List<Double>, val timeStamp: Long) {
    init {
        if (values.size != 4) {
            Log.e("EEGData", "values must always contain 4 values")
        }
    }
}

