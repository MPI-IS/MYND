package com.bwirth.myndandroid.activity

import android.bluetooth.BluetoothAdapter
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.os.Bundle
import android.preference.CheckBoxPreference
import android.preference.Preference
import android.preference.Preference.OnPreferenceClickListener
import android.preference.PreferenceFragment
import android.support.design.widget.Snackbar
import android.support.v7.app.AppCompatActivity
import android.text.InputType
import android.util.Log
import android.view.MenuItem
import android.view.View
import com.afollestad.materialdialogs.MaterialDialog
import com.bwirth.myndandroid.R
import com.bwirth.myndandroid.commons.*
import kotlinx.android.synthetic.main.view_toolbar.*
import org.jetbrains.anko.contentView
import org.jetbrains.anko.runOnUiThread
import java.io.File
import java.util.*


private fun setLocale(context: Context) {
    val locale = Locale.GERMAN
    Locale.setDefault(locale)

    val res = context.resources
    val config = Configuration(res.configuration)
    config.setLocale(Locale.GERMAN)
    res.configuration.setLocale(Locale.GERMAN)
}

/**
 * The settings are password protected. They can be accessed from the welcome screen's overflow menu.
 * The WebDav server can be changed form here.
 * Also, some information about the currently logged-in patient can be viewed in here.
 */
class SettingsActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        title = ""
        showLoginDialog()
    }

    private fun showLoginDialog() {
        MaterialDialog.Builder(this)
                .title(getString(R.string.settings_dialog_title))
                .content(getString(R.string.settings_dialog_text))
                .input("", "") { _, pw ->
                    if(pw.toString() != getString(R.string.settings_password)) finish()
                    else onPWCorrect()
                }
                .inputType(InputType.TYPE_TEXT_VARIATION_PASSWORD)
                .positiveText(getString(R.string.settings_dialog_positive))
                .negativeText(R.string.cancel)
                .onNegative{_,_ -> finish()}
                .cancelListener{_ -> finish()}
                .show()
    }

    private fun onPWCorrect(){
        setContentView(R.layout.activity_settings)
        sessioncard_image.visibility = View.GONE
        val fragment = MyPreferenceFragment()
        fragmentManager.beginTransaction().replace(R.id.content_prefs_fragment, fragment).commit()
        setSupportActionBar(toolbar)
        supportActionBar?.setDisplayHomeAsUpEnabled(true)
        supportActionBar?.setDisplayShowHomeEnabled(true)
        toolbar_title.text = getString(R.string.toolbar_title_settings)
        setLocale(this)
    }


    override fun onOptionsItemSelected(item: MenuItem): Boolean {
        return when (item.itemId) {
            android.R.id.home -> {
                finish()
                true
            }
            else -> super.onOptionsItemSelected(item)
        }
    }

    class MyPreferenceFragment : PreferenceFragment() {
        private lateinit var eraseBtn: Preference
        private lateinit var showRecordedBtn: Preference
        private lateinit var changeCredentialsBtn: Preference
        private lateinit var idInfoPreference: Preference
        private lateinit var prefDevMode: CheckBoxPreference
        private lateinit var prefTTS: CheckBoxPreference
        private lateinit var autoTransfer: CheckBoxPreference

        override fun onCreate(savedInstanceState: Bundle?) {
            super.onCreate(savedInstanceState)
            addPreferencesFromResource(R.xml.preferences)
            eraseBtn = findPreference("erasebutton")
            showRecordedBtn = findPreference("pref_show_recorded")
            changeCredentialsBtn = findPreference("pref_id_owncloud")
            idInfoPreference = findPreference("pref_id_info")
            autoTransfer = findPreference("pref_autotransfer") as CheckBoxPreference
            prefDevMode = findPreference("pref_dev_mode") as CheckBoxPreference
            prefTTS = findPreference("pref_tts") as CheckBoxPreference
            initViews()
            setListeners()
            changeCredentialsBtn.summary = getPrefOrDefault(activity, Pref.OWN_CLOUD_USER)
            testConnection(activity, this::updateOwncloudStatus)
        }

        private fun updateOwncloudStatus(success: Boolean) {
            runOnUiThread {
                changeCredentialsBtn.summary = if (success) getString(R.string.connection_established) else getString(R.string.not_connected)
                if (!success) {
                    Snackbar.make(activity.contentView!!, getString(R.string.not_connected), Snackbar.LENGTH_SHORT).show()
                }
            }
        }

        private fun setListeners() {
            eraseBtn.onPreferenceClickListener = onClickHandler(this::showConfirmEraseDialog)
            changeCredentialsBtn.onPreferenceClickListener = onClickHandler { showOwnCloudDialog(activity, this::updateOwncloudStatus) }
            showRecordedBtn.onPreferenceClickListener = onClickHandler {
                startActivity(Intent(activity, RecordingHistoryActivity::class.java))
            }
            prefDevMode.onPreferenceChangeListener = Preference.OnPreferenceChangeListener { a: Preference?, newVal: Any? ->
                setPref(activity, Pref.DEV_MODE, newVal as Boolean)
                true
            }

            prefDevMode.onPreferenceChangeListener = Preference.OnPreferenceChangeListener { a: Preference?, newVal: Any? ->
                setPref(activity, Pref.DEV_MODE, newVal as Boolean)
                true
            }
            prefTTS.onPreferenceChangeListener = Preference.OnPreferenceChangeListener { a: Preference?, newVal: Any? ->
                setPref(activity, Pref.TTS, newVal as Boolean)
                true
            }
            autoTransfer.onPreferenceChangeListener = Preference.OnPreferenceChangeListener { a: Preference?, newVal: Any? ->
                setPref(activity, Pref.AUTOMATIC_TRANSFER, newVal as Boolean)
                true
            }
        }

        private fun onClickHandler(callback: () -> Unit): Preference.OnPreferenceClickListener =
                OnPreferenceClickListener { callback(); true }


        /**
         * Read current shared prefs and set views accordignly
         */
        private fun initViews() {
            prefDevMode.isChecked = getPrefOrDefault(activity, Pref.DEV_MODE)
            prefTTS.isChecked = getPrefOrDefault(activity, Pref.TTS)
            autoTransfer.isChecked = getPrefOrDefault(activity, Pref.AUTOMATIC_TRANSFER)
            idInfoPreference.summary = getPrefOrDefault<String>(activity, Pref.SUBJECT_ID)
        }

        private fun eraseAndReset() {
            val logFile = File(activity.filesDir, "${getPrefOrDefault<String>(activity,Pref.SUBJECT_ID)}.log.txt")
            if(logFile.exists()){
               try{
                   logFile.delete()
               } catch (e: Exception){
                   Log.e("mynd_settings", "Could not delete log file",e)}
            }
            resetSharedPrefs(activity)
            val intent = Intent(activity, SignUpActivity::class.java)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            BluetoothAdapter.getDefaultAdapter().disable()
            activity.startActivity(intent)
        }

        private fun showConfirmEraseDialog() {
            MaterialDialog
                    .Builder(activity)
                    .title(getString(R.string.pref_title_erase))
                    .content(getString(R.string.pref_descr_erase_data))
                    .positiveText("OK")
                    .negativeText(getString(R.string.cancel))
                    .onPositive { _, _ ->
                        eraseAndReset()
                    }
                    .show()
        }
    }


}