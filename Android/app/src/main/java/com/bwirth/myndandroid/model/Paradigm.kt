package com.bwirth.myndandroid.model

import kotlinx.serialization.Serializable

@Serializable
data class Paradigm(val conditionLabels: Array<String>, val conditionMarkers: Array<Int>, val baseMarkers: Array<Int>, val baseTime: Int, val trialTime: Int)