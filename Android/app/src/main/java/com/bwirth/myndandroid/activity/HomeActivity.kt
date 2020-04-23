package com.bwirth.myndandroid.activity

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Bundle
import android.util.Log
import android.view.Menu
import android.view.View
import com.bwirth.myndandroid.R
import com.bwirth.myndandroid.activity.Result.*
import com.bwirth.myndandroid.commons.*
import com.bwirth.myndandroid.model.Study
import com.bwirth.myndandroid.view.ScenarioAdapter
import com.thegrizzlylabs.sardineandroid.impl.OkHttpSardine
import kotlinx.android.synthetic.main.activity_home.*
import kotlinx.android.synthetic.main.view_toolbar.*
import org.jetbrains.anko.doAsync
import org.jetbrains.anko.noHistory
import java.io.File

/**
 * This is the welcome activity. It shows a list of scenarios that are not yet completed.
 */
class HomeActivity : MyndActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (getPrefOrNull<String>(this, Pref.SUBJECT_ID).let {it == null || it == Pref.SUBJECT_ID.default}) {
            val signup = Intent(this, SignUpActivity::class.java).noHistory()
            startActivity(signup)
            finish(NONE)
            return
        }

        Study.loadState(this)
        setContentView(R.layout.activity_home)
        //home_listview.adapter = ScenarioAdapter(this, R.layout.view_sessioncard, Study.scenarios.filter { !it.isFinished() }) { onStartScenario() }
        setSupportActionBar(findViewById(R.id.toolbar))
        supportActionBar?.setDisplayShowTitleEnabled(false)
    }

    fun getBatteryPercentage(context: Context): Int {

        val iFilter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        val batteryStatus = context.registerReceiver(null, iFilter)

        val level = if (batteryStatus != null) batteryStatus!!.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) else -1
        val scale = if (batteryStatus != null) batteryStatus!!.getIntExtra(BatteryManager.EXTRA_SCALE, -1) else -1

        val batteryPct = level / scale.toFloat()

        return (batteryPct * 100).toInt()
    }

    override fun onResume() {
        super.onResume()
        val batteryPct = getBatteryPercentage(this)
        if (Study.isFinished()) {
            toolbar_title?.text = getString(R.string.app_name)
            studydonehomeroot.visibility = View.VISIBLE
            home_listview.visibility = View.GONE
            image_home_card.setImageResource(R.drawable.checkmark)
            home_card_description.text = getString(R.string.study_done_home)
            home_card_title.text = getString(R.string.study_completed_title)
            return
        }
        // study is not yet finished
        if (batteryPct < resources.getInteger(R.integer.critical_battery_level_device)
                && !isDeviceCurrentlyCharging()
                && !isDevModeEnabled()) { // allow skip in dev mode
            toolbar_title?.text = getString(R.string.app_name)
            Log.i(TAG, "Battery is too low: $batteryPct%")
            home_listview.visibility = View.GONE
            studydonehomeroot.visibility = View.VISIBLE
            image_home_card.setImageResource(R.drawable.batterylow)
            home_card_description.text = getString(R.string.home_card_batterylow)
            home_card_title.text = getString(R.string.home_card_batterytitle)
        } else {
            toolbar_title?.text = getString(R.string.today)
            home_listview.adapter = ScenarioAdapter(this, R.layout.view_sessioncard, Study.scenarios.filter { !it.isFinished() }) { onStartScenario() }
            home_listview.visibility = View.VISIBLE
            studydonehomeroot.visibility = View.GONE
        }
    }

    fun isDeviceCurrentlyCharging(): Boolean {
        val intent = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val plugged = intent.getIntExtra(BatteryManager.EXTRA_PLUGGED, -1)
        return plugged == BatteryManager.BATTERY_PLUGGED_AC || plugged == BatteryManager.BATTERY_PLUGGED_USB || plugged == BatteryManager.BATTERY_PLUGGED_WIRELESS
    }

    @SuppressLint("RestrictedApi")
    private fun onStartScenario() {
        Log.i(TAG, "starting the current scenario")
        //startActivityForResult(Intent(this, ScenarioActivity::class.java), 100)
        startActivityForResult(Intent(this, ConnectActivity::class.java), REQUEST_CONNECT)
    }


    override fun onCreateOptionsMenu(menu: Menu?): Boolean {
        menuInflater.inflate(R.menu.main, menu)
        return true
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        Log.i(TAG, "The following activity result was received: requestcode=$requestCode resultcode=$resultCode")

        when (resultCode) {
            USER_CANCELLED.code, MUSE_BATTERY_LOW.code -> BluetoothAdapter.getDefaultAdapter().disable()
            SUCCESS.code -> when (requestCode) {
                REQUEST_CONNECT -> startActForResult(REQUEST_FIT, FittingActivity::class.java) { it.putExtra(EXTRA_FITTING_MODE, "initialFitting") }
                REQUEST_FIT -> startActForResult(REQUEST_SCENARIO, ScenarioActivity::class.java)
                REQUEST_BLOCK -> startActForResult(REQUEST_PAUSE, PauseActivity::class.java)
                REQUEST_SCENARIO -> startActForResult(REQUEST_BLOCK, BlockActivity::class.java)
            }
            DEVICE_DISCONNECTED.code -> {
                logToFileAndCat("Muse headset disconnected", Log::w)
                BluetoothAdapter.getDefaultAdapter().disable()
                startActivity(Intent(this, ErrorActivity::class.java))
            }
            Result.REQUEST_FINISH.code -> BluetoothAdapter.getDefaultAdapter().disable()
            Result.REQUEST_CONTINUE.code -> startActForResult(REQUEST_FIT, FittingActivity::class.java) { it.putExtra(EXTRA_FITTING_MODE, "checkUp") }
            Result.REQUEST_RESTART_BLOCK.code -> startActForResult(REQUEST_SCENARIO, ScenarioActivity::class.java){it.putExtra(EXTRA_RESTARTING_BLOCK, true)}
            else -> Log.w(TAG, "unknown result code ignored")
        }

        doAsync {
            try {
                val sardine = OkHttpSardine()
                sardine.setCredentials(getPrefOrDefault(this@HomeActivity, Pref.OWN_CLOUD_USER), getPrefOrDefault(this@HomeActivity, Pref.OWN_CLOUD_PW))
                Log.i(TAG, "uploading log file ${logFile.name} ...")
                fileLogger.flush()
                sardine.put("${getString(R.string.owncloud_baseURL)}${getString(R.string.owncloud_path)}/${logFile.name}", logFile.readBytes())
                Log.i(TAG, "uploaded log file ${logFile.name}")
            } catch (e: Exception) {
                Log.e(TAG, "failed to upload log file ${logFile.name}\n", e)
            }
        }
    }

    fun startActForResult(requestCode: Int, c: Class<*>, intentConfigurator: (intent: Intent) -> Intent = { it }) {
        startActivityForResult(intentConfigurator(Intent(this, c)), requestCode)
    }

    override fun onBackPressed() {

    }

}