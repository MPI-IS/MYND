/**
 * Example of using libmuse library on android.
 * Interaxon, Inc. 2016
 */

package com.bwirth.myndandroid.activity


//import com.bwirth.myndandroid.commons.BTHelper
import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothAdapter.ACTION_STATE_CHANGED
import android.bluetooth.BluetoothAdapter.getDefaultAdapter
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.pm.PackageManager.PERMISSION_DENIED
import android.os.Bundle
import android.support.v4.app.ActivityCompat
import android.support.v4.content.ContextCompat
import android.util.Log
import android.view.Menu
import android.view.WindowManager
import com.bwirth.myndandroid.R
import com.bwirth.myndandroid.commons.MuseDevice
import com.bwirth.myndandroid.commons.MuseDevice.DeviceState.*
import com.bwirth.myndandroid.controller.loadSteps
import kotlinx.android.synthetic.main.view_steps.*
import kotlinx.android.synthetic.main.view_toolbar.*
import android.view.animation.AnimationUtils
import android.view.animation.Animation
import com.bwirth.myndandroid.commons.Pref
import com.bwirth.myndandroid.commons.getPrefOrDefault
import com.bwirth.myndandroid.commons.setPref
import io.reactivex.disposables.Disposable


const val REQUEST_CONNECT = 1020

/**
 * This activity handles connecting the headband and putting it on.
 * Depending on the current step, certain criteria need to be fulfilled until the next step
 * can be completed. For example, only after bluetooth has been enabled, it will connect to the
 * headband.
 */
class ConnectActivity : MyndActivity() {
    private val REQUEST_COARSE_LOC = 3

    private lateinit var stepsView: StepsView
    private lateinit var steps: Array<InstructionStep>
    private var currStepIdx = -1
    private var subscriptions: MutableList<Disposable> = mutableListOf()

    override var cancelNeedsDoublePress = true


    private val btAdapter: BluetoothAdapter by lazy {
        getDefaultAdapter()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.view_steps)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        setSupportActionBar(toolbar)
        supportActionBar?.setDisplayShowTitleEnabled(false)
        steps = loadSteps(this, "Start")
        stepsView = StepsView(this, steps_root, ttsInstance)
        button_nextstep.text = getString(R.string.next_step)
        status.setOnClickListener{_ -> stepsView.currentStep?.let {ttsInstance.speak(it.instruction) }}
        nextStep()
    }


    private fun stepByID(id: String): InstructionStep {
        currStepIdx = steps.indexOfFirst { it.id == id }
        return steps[currStepIdx]
    }


    private fun nextStep() {
        stepsView.disableNextStep() // disable user input until we know what to do
        currStepIdx++
        val currStep = steps[currStepIdx]
        Log.i(TAG, "next step: " + currStep.id)
        button_nextstep.text = getString(R.string.next_step)
        when (currStep.id) {
            "water" -> {
                stepsView.show(currStep, this::nextStep, true)
            }
            "location", "location_repeating" -> {
                val locationPermitted = ContextCompat.checkSelfPermission(this@ConnectActivity,
                        Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
                if (!locationPermitted) {
                    requestLocationPermission(steps[currStepIdx - 1].id.contains("location"))
                } else {
                    Log.i(TAG, "location permission already granted or bt is already on")
                    nextStep()
                }
            }
            "bluetooth" -> {
                if (btAdapter.isEnabled) {
                    Log.i(TAG, "bluetooth already enabled.")
                    nextStep()
                } else {
                    requestEnableBT()
                }
            }
            "turnOn" -> {
                if(MuseDevice.state.value == CONNECTED || MuseDevice.state.value == ON_HEAD){
                    Log.i(TAG, "muse is already connected")
                    nextStep()
                } else{
                    Log.i(TAG, "muse not recoginzed as turned on. is in state ${MuseDevice.state.value}")
                    MuseDevice.stopListening()
                    MuseDevice.startListening(this)
                    showAnimated(currStep, this::nextStep)
                }
            }
            "putOn" -> {
                val alreadyOnHead = MuseDevice.state.hasValue() && MuseDevice.state.value!! == ON_HEAD
                showAnimated(currStep, this::nextStep, alreadyOnHead || isDevModeEnabled())

            }
            "push" -> {
                button_nextstep.text = getString(R.string.button_finish)
                showAnimated(currStep, {
                    Log.i(TAG, "Connection stuff done, finishing")
                    stepsView.stop()
                    finish(Result.SUCCESS)
                }, true)
            }
            else -> {
                showAnimated(currStep, this::nextStep, true)
            }
        }
    }

    private fun showAnimated(currentStep: InstructionStep, callback: () -> Unit, enableNextStep: Boolean = false) {
        Log.i(TAG, "Animating the current step: ${currentStep.id}")

        val anim = AnimationUtils.loadAnimation(this, R.anim.push_left_exit)
        button_nextstep.isClickable = false
        videoroot.animate()
                .alpha(0.3f)
                .setDuration(300L)
                .withEndAction{
                    stepsView.show(currentStep,callback,enableNextStep)
                    videoroot.animate()
                            .alpha(1f)
                            .setDuration(300L)
                            .withEndAction{button_nextstep.isClickable = true}
                            .setStartDelay(100L)
                }
                .start()

        anim.setAnimationListener(object : Animation.AnimationListener {
            override fun onAnimationRepeat(p0: Animation?) {
            }

            override fun onAnimationEnd(p0: Animation?) {
                val anim2 = AnimationUtils.loadAnimation(this@ConnectActivity, R.anim.push_left_enter)
                status.startAnimation(anim2)
            }

            override fun onAnimationStart(p0: Animation?) {
            }

        })
        status.startAnimation(anim)
    }

    override fun onResume() {
        super.onResume()

        val batterySubscription =
        MuseDevice.battery.take(1).subscribe{level ->
            if (level < resources.getInteger(R.integer.critical_battery_level_muse)) {
                subscriptions.forEach { it.dispose() }
                showAnimated(InstructionStep("batterylow", getString(R.string.muse_battery_low),
                        "charging.mp4"),{
                            unregisterReceiver(MuseDevice.btStateReceiver)
                            finish(Result.MUSE_BATTERY_LOW)
                        },
                        enableNextStep = true)
                button_nextstep.text = getString(R.string.button_ok_charge)
                Log.i(TAG, "battery level is LOW! ($level %)")
            } else {
                Log.i(TAG, "battery level is ok! ($level %)")
            }
        }
        subscriptions.add(batterySubscription)


        subscriptions.add(MuseDevice.state.subscribe { state ->
            if (state == DISCONNECTED && currStepIdx > steps.indexOfFirst { it.id == "bluetooth" }) {
                MuseDevice.stopListening()
                btAdapter.cancelDiscovery()
                Log.i(TAG, "Device is now disconnected!")
                val locationPermitted = ContextCompat.checkSelfPermission(this@ConnectActivity,
                        Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
                if (locationPermitted) {
                    if (btAdapter.isEnabled) {
                        MuseDevice.startListening(this)
                        if (stepsView.currentStep?.id == "turnOn") { // not in case we're already in this step
                            stepsView.disableNextStep()
                        } else { // in case we lost connection after establishing it, we go back
                            showAnimated(stepByID("turnOn"), this::nextStep)
                        }
                    } else {
                        requestEnableBT()
                    }
                } else {
                    requestLocationPermission(false)
                }
            } else if(stepsView.currentStep?.id == "turnOn" && (state == CONNECTED)){
                Log.i(TAG, "The device is now connected")
                stepsView.enableNextStep()
            } else if(stepsView.currentStep?.id == "putOn" && state == ON_HEAD){
                Log.i(TAG, "The device is now ON_HEAD")
                stepsView.enableNextStep()
            }
        })

        registerReceiver(MuseDevice.btStateReceiver, IntentFilter(ACTION_STATE_CHANGED))
        steps_videoview.start()
        stepsView.currentStep?.instruction?.let { ttsInstance.speak(it) }
        if(btAdapter.isEnabled && MuseDevice.state.value.let { it == null || it == DISCONNECTED }){
            MuseDevice.startListening(this) // early listening if bt is already switched on
        }
    }

    override fun onPause() {
        super.onPause()
        subscriptions.forEach{it.dispose()}
        try{
            unregisterReceiver(MuseDevice.btStateReceiver)
        } catch (e: Exception){}
        MuseDevice.stopListening()
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_COARSE_LOC) {
            val index = permissions.indexOf(Manifest.permission.ACCESS_COARSE_LOCATION)
            if (index < 0 || grantResults[index] == PERMISSION_DENIED) {
                showAnimated(stepByID("location_repeating"), {
                    ActivityCompat.requestPermissions(this,
                            arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION), REQUEST_COARSE_LOC)
                }, true)
            } else {
                nextStep()
            }
        }
    }

    /**
     * returns true in case bluetooth is already enabled. Otherwise, requests for enabling it.
     */
    private fun requestEnableBT() {
        showAnimated(stepByID("bluetooth"), {
            btAdapter.enable()
            nextStep()
        }, true)
    }


    /**
     * returns true if the permission is already granted, false if async request was sent
     */
    private fun requestLocationPermission(repeating: Boolean): Boolean {
        val hasPermission = ContextCompat.checkSelfPermission(this,
                Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        if (!hasPermission) {
            Log.i(TAG, "requesting coarse location permission")
            showAnimated(stepByID(if (repeating) "location_repeating" else "location"), {
                ActivityCompat.requestPermissions(this,
                        arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION), REQUEST_COARSE_LOC)
            }, true)
        }
        return hasPermission
    }

    override fun onCreateOptionsMenu(menu: Menu?): Boolean {
        menuInflater.inflate(R.menu.cancel_and_settings, menu)
        return true
    }
}
