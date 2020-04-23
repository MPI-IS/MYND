package com.bwirth.myndandroid.activity

import android.bluetooth.BluetoothAdapter
import android.content.IntentFilter
import android.os.Bundle
import android.support.v4.content.ContextCompat
import android.util.Log
import android.view.Menu
import android.view.View
import android.view.WindowManager
import android.view.animation.Animation
import android.view.animation.AnimationUtils
import android.widget.ImageView
import android.widget.Toast
import com.bwirth.myndandroid.R
import com.bwirth.myndandroid.commons.MuseDevice
import com.bwirth.myndandroid.commons.MuseDevice.DeviceState.*
import com.bwirth.myndandroid.controller.ProcessingDelegate
import com.bwirth.myndandroid.controller.loadSteps
import com.bwirth.myndandroid.model.FittingStep
import com.kizitonwose.android.disposebag.disposedWith
import com.mikhaellopez.circularprogressbar.CircularProgressBar
import io.reactivex.disposables.Disposable
import kotlinx.android.synthetic.main.activity_fitting.*
import kotlinx.android.synthetic.main.view_toolbar.*

const val REQUEST_FIT = 19373
const val EXTRA_FITTING_MODE = "EXTRA_FITTING_MODE"
const val RESULT_CONNECTION_LOST = 32943


/**
 * The fitting activity guides the user through putting on the headband in a way that
 * the contact between the electrodes and head is as good as possible.
 * Circular progress bars indicate how well each of the headband's sensors is fitted.
 */
class FittingActivity : MyndActivity() {

    private lateinit var fittingSteps: Iterator<InstructionStep>
    private lateinit var fittingStepsOrig: Array<InstructionStep>
    private lateinit var stepsView: StepsView
    private lateinit var currentFittingValues: Array<Double>
    private lateinit var processingDelegate: ProcessingDelegate


    private lateinit var progressViews: Array<CircularProgressBar>
    private lateinit var checkmarkViews: Array<ImageView>
    private var subscriptions =  mutableListOf<Disposable>()
    override var cancelNeedsDoublePress = true

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_fitting)
        setSupportActionBar(toolbar)
        supportActionBar?.setDisplayShowTitleEnabled(false)
        stepsView = StepsView(this, fittingRoot, ttsInstance)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        registerReceiver(MuseDevice.btStateReceiver, IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED))
        processingDelegate = ProcessingDelegate()
        progressViews = arrayOf(fit_circle_left_ear, fit_circle_left_forehead, fit_circle_right_forehead, fit_circle_right_ear) // order must! be the same as Muse.EEG.EEG1 .. EEG4 http://android.choosemuse.com/enumcom_1_1choosemuse_1_1libmuse_1_1_eeg.html#aff197d94f2fe3089df08314495b461d8
        checkmarkViews = arrayOf(checkmark_left_ear, checkmark_left_forehead, checkmark_right_forehead, checkmark_right_ear) // order must! be the same as Muse.EEG.EEG1 .. EEG4 http://android.choosemuse.com/enumcom_1_1choosemuse_1_1libmuse_1_1_eeg.html#aff197d94f2fe3089df08314495b461d8
        status.setOnClickListener{_ -> stepsView.currentStep?.let {ttsInstance.speak(it.instruction) }}


        if (!intent.hasExtra(EXTRA_FITTING_MODE)) {
            Log.e(TAG, "Fitting Mode was not provided with intent", Exception())
            finish(Result.NONE)
            return
        }
        val fittingMode = intent.getStringExtra(EXTRA_FITTING_MODE)
        fittingStepsOrig = loadSteps(this, fittingMode)
        Log.i(TAG, "Fitting with mode $fittingMode")
    }

    private fun isHeadsetDisconnected(state: MuseDevice.DeviceState): Boolean{
        return state != CONNECTED && state != ON_HEAD
    }

    override fun onResume() {
        super.onResume()
        currentFittingValues = Array(4) { 0.0 }
        fittingSteps = fittingStepsOrig.iterator() // fitting always needs to start from beginning
        checkmarkViews.forEach { it.visibility = View.INVISIBLE }
        subscriptions.add(MuseDevice.state.subscribe {
            if (isHeadsetDisconnected(it)) {
                logToFileAndCat("connection to muse headset lost, state=$it", Log::w)
                finish(Result.DEVICE_DISCONNECTED)
            }
        })
        processingDelegate.startListening()
        subscriptions.add(processingDelegate.avgSignalQuality
                .subscribe { progress -> runOnUiThread { updateProgress(progress) } })
        nextStep()
    }

    override fun onPause() {
        super.onPause()
        subscriptions.forEach { it.dispose() }
        processingDelegate.subscriptions.forEach { it.dispose() }
        subscriptions.clear()
        processingDelegate.subscriptions.clear()
    }

    private fun nextStep() {
        if (!fittingSteps.hasNext()) {
            endFitting()
            return
        }
        val currentFittingStep = fittingSteps.next()
        var enableNextStep = false
        if((currentFittingStep.id == "front" || currentFittingStep.id == "back" || currentFittingStep.id == "intro") && isStepFinished(currentFittingStep.id)) {
            nextStep() // skip fittings steps if already fitted
            return
        }
        when (currentFittingStep.id) {
            "front", "demo" -> {
                progressViews[1].visibility = View.VISIBLE
                progressViews[2].visibility = View.VISIBLE
                progressViews[0].visibility = View.INVISIBLE
                progressViews[3].visibility = View.INVISIBLE
            }
            "back", "intro" -> progressViews.forEach { it.visibility = View.VISIBLE }
            "turnOff" -> progressViews.forEach { it.visibility = View.INVISIBLE }
            "done" -> {
                progressViews.forEach { it.visibility = View.INVISIBLE }
                checkmarkViews.forEach { it.visibility = View.VISIBLE }
                enableNextStep = true
            }
            else -> {
            }
        }
        Log.i(TAG, "Next step: " +currentFittingStep.id)

        enableNextStep = enableNextStep || isDevModeEnabled()
        val anim = AnimationUtils.loadAnimation(this, R.anim.push_left_exit)
        anim.setAnimationListener(object : Animation.AnimationListener {
            override fun onAnimationRepeat(p0: Animation?) {
            }

            override fun onAnimationEnd(p0: Animation?) {
                stepsView.show(currentFittingStep, this@FittingActivity::nextStep, enableNextStep)
                val anim2 = AnimationUtils.loadAnimation(this@FittingActivity, R.anim.push_left_enter)
                status.startAnimation(anim2)
                stepsView.button_nextstep?.isClickable = true
            }

            override fun onAnimationStart(p0: Animation?) {
            }

        })
        if(stepsView.currentStep == null){
            // do not animate first step
            stepsView.show(currentFittingStep, this::nextStep, enableNextStep)
        } else{
            stepsView.button_nextstep?.isClickable = false
            status.startAnimation(anim)
        }
    }


    override fun onCreateOptionsMenu(menu: Menu?): Boolean {
        menuInflater.inflate(R.menu.cancel_and_settings, menu)
        return true
    }


    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(MuseDevice.btStateReceiver)
        MuseDevice.stopListening()
    }


    private fun updateProgress(progress: List<Double>) {
        for (i in progress.indices) {
            if (currentFittingValues[i] != 100.0) {
                currentFittingValues[i] = progress[i]
                currentFittingValues[i] = Math.min(currentFittingValues[i], 100.0)
                progressViews[i].setProgressWithAnimation(currentFittingValues[i].toFloat(), 300)
                progressViews[i].color = ContextCompat.getColor(this, progressToColor(currentFittingValues[i]))
            }
            if(progressViews[i].visibility == View.VISIBLE
                    && currentFittingValues[i] == 100.0
                    && stepsView.currentStep?.id != "demo"){
                checkmarkViews[i].visibility =  View.VISIBLE
            }
        }

        val done = isStepFinished(stepsView.currentStep?.id)
        if (done) {
            when (stepsView.currentStep?.id){
                 "front", "back", "intro" -> nextStep()
                null -> {}
                else -> stepsView.enableNextStep()
            }
        }
    }

    private fun isStepFinished(step: String?): Boolean{
        return step != null && when (step) {
            "front" -> (isFitted(1) && isFitted(2))
            "back", "intro" -> (0..3).all { isFitted(it) }
            "turnOff" -> false // enabling will be handled by subscription above
            else -> true
        }
    }

    private fun isFitted(index: Int) = currentFittingValues[index] >= 100.0


    private fun endFitting() {
        Log.i(TAG, "Fitting done. Finishing.")
        finish(Result.SUCCESS)
    }


    private fun progressToColor(value: Double) = when {
        value < 20.0 -> R.color.mp_red
        value > 80.0 -> R.color.mp_green
        else -> R.color.mp_orange
    }


}