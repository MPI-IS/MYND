package com.bwirth.myndandroid.activity

import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.util.Log
import android.view.Menu
import android.view.WindowManager
import com.bwirth.myndandroid.R
import com.bwirth.myndandroid.commons.*
import com.bwirth.myndandroid.model.*
import com.kizitonwose.android.disposebag.disposedWith
import io.reactivex.disposables.Disposable
import kotlinx.android.synthetic.main.activity_block.*
import kotlinx.android.synthetic.main.view_toolbar.*
import java.io.BufferedWriter
import java.io.File
import java.io.IOException
import java.text.SimpleDateFormat
import java.util.*
import kotlin.math.min
import kotlin.math.roundToLong

const val REQUEST_BLOCK = 15593

/**
 * This activity handles showing a sequence of trials in a experimental block.
 * If this activity is stopped or put to background, it will be handled by stopping the block.
 * It is important that subjects focus on the trial and are not distracted by other content on the
 * screen etc.
 */
class BlockActivity : MyndActivity() {
    private lateinit var filename: String
    private lateinit var fileWriter: BufferedWriter
    private var subscription: Disposable? = null
    private lateinit var block: Block
    private lateinit var currPhase: Phase
    private lateinit var currTrial: Trial
    private var currPhaseIdx = -1
    private var currTrialIdx = -1
    private var handler = Handler()
    private lateinit var recordingFiles: MutableList<RecordingFile>
    private lateinit var currFile: RecordingFile
    @Volatile
    private var prevMarker = -1
    override var cancelNeedsDoublePress = true
    private lateinit var datestring: String

    private fun createUniqueFileName(): String {
        val paradigm = Study.getCurrentScenario()!!.paradigm
        val subID = getPrefOrDefault<String>(this, Pref.SUBJECT_ID)
        datestring = SimpleDateFormat(getString(R.string.date_format_filename), Locale.ENGLISH).format(Date())
        return "${datestring}_${paradigm}_$subID.csv"
    }


    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setContentView(R.layout.activity_block)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        setSupportActionBar(toolbar)
        supportActionBar?.setDisplayShowTitleEnabled(false)
        block = Study.getCurrentScenario()!!.getCurrentBlock()!!

        filename = createUniqueFileName()
        currFile = RecordingFile(filename, false, 0, 0L, Study.getCurrentScenario()!!.paradigm, getPrefOrDefault(this, Pref.SUBJECT_ID), datestring)
        recordingFiles = getRecordingFiles(this).toMutableList()

        recordingFiles.add(currFile)
        saveRecordingFiles(this, recordingFiles)
        Log.i(TAG, "Data will be written to $filename")

        fixationcross.setOnClickListener {
            if (isDevModeEnabled()) {
                handler.removeCallbacksAndMessages(null)
                nextPhase()
            }
        }

        checkDeviceState(MuseDevice.state.value ?: MuseDevice.DeviceState.DISCONNECTED)
        MuseDevice.state.subscribe(this::checkDeviceState).disposedWith(this)

    }

    private fun checkDeviceState(state: MuseDevice.DeviceState) {
        if (isHeadsetDisconnected(state)) {
            Log.w(TAG, "The device was disconnected")
            subscription?.dispose()
            handler.removeCallbacksAndMessages(null)
            finish(Result.DEVICE_DISCONNECTED)
        }
    }


    override fun onResume() {
        super.onResume()
        handler.removeCallbacksAndMessages(null)
        subscription?.dispose()
        Log.i(TAG, "onResume: beginning file from scratch")
        if (MuseDevice.state.hasValue() && !isHeadsetDisconnected(MuseDevice.state.value!!)) {
            if (currPhaseIdx == -1) { // we just arrived here after oncreate
                startFromBeginning()
            } else { // the block was interrupted
                finish(Result.REQUEST_RESTART_BLOCK)
            }
        } else {
            finish(Result.DEVICE_DISCONNECTED)
        }
    }

    private fun isHeadsetDisconnected(state: MuseDevice.DeviceState): Boolean {
        return state != MuseDevice.DeviceState.CONNECTED && state != MuseDevice.DeviceState.ON_HEAD
    }

    private fun startFromBeginning() {
        currPhaseIdx = -1
        currTrialIdx = -1
        nextTrial()
        val file = File(filesDir, currFile.fileName)
        file.delete()
        file.createNewFile() // important in case we restarted the block
        fileWriter = file.bufferedWriter()
        subscription = MuseDevice.eegData.subscribe { eegData: EEGData? ->
            val eegvalues = eegData?.values?.joinToString(",")
            val currMarker = currTrial.phases[currPhaseIdx].marker
            val pointmarker = if (prevMarker == currMarker) 0 else currMarker
            prevMarker = currMarker
            fileWriter.appendln("$eegvalues, $pointmarker")
            currFile.numLines++
        }
        subscription?.disposedWith(this)
        updateProgress(0.0, block.getDuration())
    }

    private fun updateProgress(elapsed: Double, totalTime: Double) {
        val prog = if (elapsed <= 0.0) 0 else min((elapsed * 100.0 / totalTime).toInt(), 100)
        runOnUiThread {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N)
                block_progress.setProgress(prog, true)
            else block_progress.progress = prog
        }

        handler.postDelayed({ updateProgress(elapsed + 1, totalTime) }, 1000)
    }


    private fun nextTrial() {
        if (block.trials.lastIndex > currTrialIdx) {
            currTrialIdx++
            currTrial = block.trials[currTrialIdx]
            currPhaseIdx = -1
            Log.i(TAG, "next trial: " + currTrial.type)
            nextPhase()
        } else {
            Log.i(TAG, "no more trials left. Finishing with " + currFile.numLines + " recorded samples")
            try {
                currFile.fileSizeKB = File(filesDir, filename).length().toDouble().div(1_000).roundToLong()
            } catch (e: Exception) {
                logToFileAndCat("could not read file size on disk", Log::w)
            }
            subscription?.dispose()
            handler.removeCallbacksAndMessages(null)
            try {
                fileWriter.flush()
                fileWriter.close()
            } catch (e: IOException) {
                logToFileAndCat("Flush could not be executed\n" + Log.getStackTraceString(e), Log::w)
            }
            finish(Result.SUCCESS)
            saveRecordingFiles(this, recordingFiles)
        }

    }


    private fun nextPhase() {
        currPhaseIdx += 1
        if (currTrial.phases.size <= currPhaseIdx) {
            nextTrial()
            return
        }
        Log.i(TAG, "next phase: ${currTrial.phases[currPhaseIdx].type} with duration:${currTrial.phases[currPhaseIdx].duration}")
        currPhase = currTrial.phases[currPhaseIdx]
        textView5.text = currPhase.instruction
        when (currPhase.type) {
            PhaseType.PROMPT -> {
                ttsInstance.speak(textView5.text.toString(), onDone = this::nextPhase)
            }
            PhaseType.FIXATION -> {
                handler.postDelayed({ nextPhase() }, currPhase.duration.toLong() * 1000L)
            }
            PhaseType.PAUSE -> {
                ttsInstance.speak(textView5.text.toString())
                handler.postDelayed({ nextPhase() }, currPhase.duration.toLong() * 1000L)
            }
        }
    }

    override fun onPause() {
        super.onPause()
        handler.removeCallbacksAndMessages(null)
    }

    override fun onCancel() {
        subscription?.dispose()
        handler.removeCallbacksAndMessages(null)
        super.onCancel()
    }

    override fun onCreateOptionsMenu(menu: Menu?): Boolean {
        menuInflater.inflate(R.menu.menu_cancel_only, menu)
        return true
    }


    override fun onBackPressed() {}
}