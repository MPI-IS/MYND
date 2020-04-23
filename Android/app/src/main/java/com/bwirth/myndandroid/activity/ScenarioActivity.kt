package com.bwirth.myndandroid.activity

import android.os.Bundle
import android.util.Log
import android.view.Menu
import com.bwirth.myndandroid.R
import com.bwirth.myndandroid.commons.MuseDevice
import com.bwirth.myndandroid.model.Scenario
import com.bwirth.myndandroid.model.Study
import com.kizitonwose.android.disposebag.disposedWith
import kotlinx.android.synthetic.main.activity_scenario2.*
import kotlinx.android.synthetic.main.view_toolbar.*

val REQUEST_SCENARIO = 10223
val EXTRA_RESTARTING_BLOCK = "EXTRA_RESTARTING_BLOCK"

/**
 * This activity shows a quick preview of what's about to happen during the upcoming scenario.
 */
class ScenarioActivity : MyndActivity() {
    private lateinit var scenario: Scenario
    override var cancelNeedsDoublePress = true

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_scenario2)
        scenario = Study.getCurrentScenario()!!
        blurry_scenario_bg.setImageResource(scenario.getImageBlurry(this))
        scenario_image.setImageResource(scenario.getImage(this))
        scenario_title.text = scenario.title
        scenario_description.text = scenario.text
        start_scenario_button.setOnClickListener { _ -> finish(Result.SUCCESS) }
       // ttsInstance.speak(scenario.text)

        setSupportActionBar(toolbar)
        title = ""
        Log.i(TAG, "showing scenario ${scenario.title}")
        checkDeviceState(MuseDevice.state.value ?: MuseDevice.DeviceState.DISCONNECTED)
        MuseDevice.state.subscribe(this::checkDeviceState).disposedWith(this)
    }

    private fun checkDeviceState(state: MuseDevice.DeviceState){
        if(state == MuseDevice.DeviceState.DISCONNECTED){
            finish(Result.DEVICE_DISCONNECTED)
        }
    }

    override fun onCreateOptionsMenu(menu: Menu?): Boolean {
        menuInflater.inflate(R.menu.cancel_and_settings, menu)
        return true
    }

    override fun onResume() {
        super.onResume()
        val ttsMessage =
        if(intent.hasExtra(EXTRA_RESTARTING_BLOCK) && intent.getBooleanExtra(EXTRA_RESTARTING_BLOCK, false)){
            getString(R.string.ttsinit_repeatingscenario)
        } else getString(R.string.ttsinit_nextscenario)
        ttsInstance.speak("$ttsMessage ${scenario.title}. ${scenario.text}")
    }


}