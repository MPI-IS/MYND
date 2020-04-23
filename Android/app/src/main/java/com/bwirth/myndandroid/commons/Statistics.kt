package com.bwirth.myndandroid.commons

import java.util.*
import kotlin.math.pow

internal val random = Random()

fun variance(data: Collection<Double>) =
        data.map { (it - data.average()).pow(2) }.sum() / data.size.toDouble()


fun rand(from: Int, to: Int): Int {
    return random.nextInt(to - from) + from
}

fun rand(from: Double, to: Double): Double {
    return from + (to - from) * random.nextDouble()
}