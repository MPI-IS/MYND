package com.bwirth.myndandroid.activity

import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.support.v4.content.ContextCompat
import android.support.v7.app.AppCompatActivity
import android.util.Log
import android.view.MenuItem
import android.widget.Toast
import com.bwirth.myndandroid.R
import com.bwirth.myndandroid.commons.Pref
import com.bwirth.myndandroid.commons.getPrefOrDefault
import com.mapzen.speakerbox.Speakerbox
import kotlinx.android.synthetic.main.view_toolbar.*
import java.io.BufferedWriter
import java.io.File
import java.io.FileWriter
import java.text.SimpleDateFormat
import java.util.*


class MuseTTS(private val speak: Speakerbox, var enabled: Boolean) {
    fun speak(speech: String, onDone: (() -> Unit) = {}) {
        if (enabled) Handler().postDelayed({ speak.playAndOnDone(speech, onDone) }, 200)
        else onDone()
    }

    fun stop() = speak.stop()
}

enum class Result(val code: Int) {
    USER_CANCELLED(10123),
    DEVICE_DISCONNECTED(11342),
    REQUEST_CONTINUE(11912),
    REQUEST_FINISH(14389),
    SUCCESS(19992),
    NONE(16001),
    MUSE_BATTERY_LOW(15221),
    REQUEST_RESTART_BLOCK(19442)
}

/**
 * This abstract base activity contains logic for TTS.
 * Many activities use TTS to have text read aloud for hearing impaired users.
 */
abstract class MyndActivity : AppCompatActivity() {
    lateinit var ttsInstance: MuseTTS
    private var toast: Toast? = null
    private var pressAgainWillCancel = false
    private val cancelHandler: Handler by lazy { Handler() }
    open var cancelNeedsDoublePress = false
    open var TAG = "mynd_" + this::class.java.simpleName
    protected val logFile: File by lazy {File(filesDir, "${getPrefOrDefault<String>(this,Pref.SUBJECT_ID)}.log.txt")}
    protected lateinit var fileLogger: BufferedWriter
    private lateinit var fileLogFormatter: SimpleDateFormat


    override fun onOptionsItemSelected(item: MenuItem?): Boolean {
        Log.i(TAG, "Menu item " + item?.toString() + " selected")
        when (item?.itemId) {
            R.id.action_cancel -> onPreCancel()
            R.id.action_settings -> startActivity(Intent(this, SettingsActivity::class.java))
            else -> super.onOptionsItemSelected(item)
        }
        return true
    }

    fun logToFileAndCat(message: String, logFn: (String, String) -> Int = Log::i){
        val datestring = fileLogFormatter.format(Date())
        try{
            fileLogger.appendln("$datestring $packageName $TAG $message")
        } catch (e: Exception){Log.e(TAG, "could not log to file", e)}
        logFn(TAG, message)
    }

    private fun onPreCancel() {
        if (!cancelNeedsDoublePress || pressAgainWillCancel) {
            onCancel()
        } else {
            Log.i(TAG, "First of 2 cancel presses have been evoked")
            pressAgainWillCancel = true
            changeToolAndStatusBarColor(R.color.mp_red)
            ttsInstance.speak(getString(R.string.press_again_cancel))
            cancelHandler.postDelayed({
                changeToolAndStatusBarColor(R.color.mp_blue)
                pressAgainWillCancel = false
            }, 4000L)
        }
    }

    private fun changeToolAndStatusBarColor(res: Int) {
        toolbar.setBackgroundColor(ContextCompat.getColor(this, res))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP)
            window.statusBarColor = ContextCompat.getColor(this, res)
    }

    open fun onCancel() {
        Log.i(TAG, "onCancel")
        finish(Result.USER_CANCELLED)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        fileLogFormatter = SimpleDateFormat(getString(R.string.date_format_filelogger), Locale.ENGLISH)
        if(!logFile.exists()) logFile.createNewFile()
        initFileLogger()
        ttsInstance = MuseTTS(Speakerbox(application), getPrefOrDefault(this, Pref.TTS))
    }

    private fun initFileLogger(){
        fileLogger =  BufferedWriter(FileWriter(logFile,true))
    }

    override fun onResume() {
        super.onResume()
        if(!logFile.exists()) logFile.createNewFile()
        initFileLogger()
        //setVolumeToDefault() // enable this to enforce volume to be set high
        ttsInstance.enabled = getPrefOrDefault(this, Pref.TTS)
        logToFileAndCat("onResume")
    }

    fun showToast(text: String, length: Int) = runOnUiThread {
        toast?.cancel()
        toast = Toast.makeText(this, text, length)
        toast!!.show()
    }

    private fun setVolumeToDefault() {
        Log.i(TAG, "Resetting volume to default")
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val defaultVolume = resources.getInteger(R.integer.default_volume) / 100f
        val criticalVolume = resources.getInteger(R.integer.critical_volume) / 100f
        val maxVolumeAbs = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC).toDouble()
        val currVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC).toDouble() / maxVolumeAbs
        if (currVolume < criticalVolume) {
            audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, (maxVolumeAbs * defaultVolume).toInt(), 0)
        }
    }

    fun isDevModeEnabled() = getPrefOrDefault(this, Pref.DEV_MODE) as Boolean


    override fun onPause() {
        logToFileAndCat("onPause")
        super.onPause()
        ttsInstance.stop()
        try {
            fileLogger.flush()
            fileLogger.close()
        } catch (e: Exception) {
            Log.w(TAG, "could not close fileLogger", e)
        }
    }

    override fun onBackPressed() {
        if (pressAgainWillCancel || !cancelNeedsDoublePress) {
            onCancel()
        } else {
            onPreCancel()
        }
    }

    protected fun finish(result: Result) {
        setResult(result.code)
        super.finish()
    }

    override fun finish() {
        Log.w(TAG, "finished without MyndActivity.Result", Exception())
        super.finish()
    }
}