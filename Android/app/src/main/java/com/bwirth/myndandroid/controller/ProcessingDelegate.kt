package com.bwirth.myndandroid.controller

import android.util.Log
import com.bwirth.myndandroid.commons.MuseDevice
import com.bwirth.myndandroid.commons.variance
import com.bwirth.myndandroid.model.EEGData
import io.reactivex.disposables.Disposable
import io.reactivex.schedulers.Schedulers
import io.reactivex.subjects.BehaviorSubject
import java.util.concurrent.TimeUnit


class ProcessingDelegate {
    private var signalQuality = BehaviorSubject.create<List<Double>>()
    var avgSignalQuality = BehaviorSubject.create<List<Double>>()
    private lateinit var variance: List<Double>
    var subscriptions = mutableListOf<Disposable>()

    private var winStep = 0.5
    private var signaQualityWinLength = 5
    private var varianceThreshold = 150.0 // in muVsquared



    fun startListening() {
        signalQuality.onNext(List(MuseDevice.channels.size) { 100.0 })
        avgSignalQuality.onNext(List(MuseDevice.channels.size) { 100.0 })
        variance = MutableList(MuseDevice.channels.size) { 0.0 }
        subscriptions.add(MuseDevice.eegData
                .scan(mutableListOf(0.0, 0.0, 0.0, 0.0), this::addToBlock)
                .buffer((1000 * winStep).toLong(), TimeUnit.MILLISECONDS, Schedulers.newThread(), (MuseDevice.samplingRate / 2.0).toInt())
                .subscribe { computeSignalQuality(it) })
        subscriptions.add(signalQuality
                .scan(listOf(0.0, 0.0, 0.0, 0.0), ::computeAverageSignalQuality)
                .subscribe { sq -> avgSignalQuality.onNext(sq) })
    }

    private fun computeAverageSignalQuality(lastData: List<Double>, newData: List<Double>): List<Double> {
        return (lastData
                .map { it * (signaQualityWinLength - 1) })
                .mapIndexed { index, d -> d + newData[index] }
                .map { it / signaQualityWinLength }
    }

    private fun computeSignalQuality(block: List<List<Double>>) {
        if (block.isEmpty()) {
            Log.w("muse_signal quality", "block is empty")
            return
        }
        val blockT = block[0].indices.map { col ->
            block.indices.map { row ->
                block[row][col]
            }
        }
        Log.i("muse_blockT size", block.size.toString())

        variance = blockT.map { it -> variance(it) }
        val nextQuality = variance.map { it ->
            if (it != 0.0) {
                if (it < varianceThreshold) {
                    110.0 // small overshoot, otherwise never reaches 100
                } else (varianceThreshold / it) * 100
            } else {
                0.0
            }
        }
        signalQuality.onNext(nextQuality)
    }


    private fun addToBlock(acc: List<Double>, newData: EEGData): List<Double> {
        val newWeights: List<Double>? = avgSignalQuality.value?.map { it / 100.0 }
        val oldWeights: List<Double>? = newWeights?.map { 1.0 - it }
        val summand1 = acc.zip(oldWeights!!).map { it.first * it.second }
        val summand2 = newData.values.zip(newWeights).map { it.first * it.second }
        return summand1.mapIndexed { i, it -> it + summand2[i] }
    }


}