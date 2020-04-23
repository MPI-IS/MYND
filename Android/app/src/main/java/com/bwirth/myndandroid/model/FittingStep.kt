package com.bwirth.myndandroid.model

data class FittingStep(
        val name: String,
        val gif: String,
        val instruction: String,
        val next: String,
        val countdown: Double)