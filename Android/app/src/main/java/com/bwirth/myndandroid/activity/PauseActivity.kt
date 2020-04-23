package com.bwirth.myndandroid.activity

import android.content.Context
import android.os.Bundle
import android.util.Log
import android.view.View
import com.bwirth.myndandroid.R
import com.bwirth.myndandroid.model.Study
import com.thegrizzlylabs.sardineandroid.impl.OkHttpSardine
import kotlinx.android.synthetic.main.activity_pause.*
import org.jetbrains.anko.doAsync
import java.io.File
import kotlin.math.roundToInt
import android.net.wifi.WifiManager
import android.widget.Toast
import com.bwirth.myndandroid.commons.*


const val REQUEST_PAUSE = 19314

/**
 * This activity informs the user about the state of the study.
 * It may be shown upon completing a block of trials or at the end of the study.
 */
class PauseActivity : MyndActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_pause)
        sendRecordings()
        negative_button.setOnClickListener { finish(Result.REQUEST_FINISH) }
        button_continue.setOnClickListener { finish(Result.REQUEST_CONTINUE) }
        val finishedIndex = Study.getCurrentScenario()!!.getCurrentBlockIndex()
        val blocksCount = Study.getCurrentScenario()!!.blocks.size
        val image = Study.getCurrentScenario()!!.getImage(this)
        blurry_scenario_bg.setImageResource(Study.getCurrentScenario()!!.getImageBlurry(this))
        val studyState = Study.advance(this)
        when (studyState) {
            Study.State.MIDDLE_OF_SCENARIO -> {
                button_continue.text = getString(R.string.continue_block)
                continue_title.text = getString(R.string.block_completed_title)
                continue_text.text = getString(R.string.block_completed_text, finishedIndex+1, blocksCount, Study.getCurrentScenario()!!.getCurrentBlock()!!.getDuration().div(60).roundToInt())
            }
            Study.State.END_OF_SCENARIO -> {
                button_continue.text = getString(R.string.continue_scenario)
                continue_title.text = getString(R.string.scenario_completed_title)
                continue_text.text = getString(R.string.scenario_completed_text)
            }
            Study.State.END_OF_STUDY -> {
                button_continue.visibility = View.INVISIBLE
                continue_title.text = getString(R.string.study_completed_title)
                continue_text.text = getString(R.string.study_completed_text)
            }
        }
        image_done.setImageResource(image)
        ttsInstance.speak(continue_text.text.toString())
    }

    private fun sendRecordings() {
        if (!getPrefOrDefault<Boolean>(this, Pref.AUTOMATIC_TRANSFER) ||!isWifiOnAndConnected(this)) {
            logToFileAndCat("Won't upload because either automatic transfer is disabled or wifi is not connected", Log::w)
            return
        }

        doAsync {
            val sardine = OkHttpSardine()
            sardine.setCredentials(getPrefOrDefault(this@PauseActivity, Pref.OWN_CLOUD_USER), getPrefOrDefault(this@PauseActivity, Pref.OWN_CLOUD_PW))
            val recordingFiles = getRecordingFiles(this@PauseActivity).toMutableList()
            recordingFiles
                    .filter { !it.uploaded }
                    .forEach { recordingFile ->
                        val file = File(filesDir, recordingFile.fileName)
                        try {
                            Log.i(TAG, "uploading file ${file.name} ...")
                            sardine.put("${getString(R.string.owncloud_baseURL)}${getString(R.string.owncloud_path)}/${recordingFile.fileName}", file.readBytes())
                            recordingFile.uploaded = true
                            Log.i(TAG, "uploaded file ${file.name}")
                        } catch (e: Exception) {
                            Log.w(TAG, "failed to upload file ${file.name}\n", e)
                        }
                    }
            saveRecordingFiles(this@PauseActivity, recordingFiles)
        }
    }

    private fun isWifiOnAndConnected(c: Context): Boolean {
        val wifiMgr = c.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        return if (wifiMgr.isWifiEnabled) { // Wi-Fi adapter is ON
            val wifiInfo = wifiMgr.connectionInfo
            wifiInfo.networkId != -1
        } else false
    }

    override fun onResume() {
        super.onResume()
        MuseDevice.state.subscribe{
            if(it != MuseDevice.DeviceState.CONNECTED && it != MuseDevice.DeviceState.ON_HEAD){
                button_continue.visibility = View.INVISIBLE
            }
        }
    }

    override fun onBackPressed() {
        // do nothing
    }

}