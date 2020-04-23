package com.bwirth.myndandroid.commons

/**
 * The functions and classes in here are mainly for serializing information and storing them in
 * shared prefs etc.
 */
//import kotlinx.serialization.*
//import kotlinx.serialization.json.JSON
import android.content.Context
import android.content.SharedPreferences
import android.text.InputType
import android.util.Log
import com.afollestad.materialdialogs.MaterialDialog
import com.bwirth.myndandroid.R
import com.bwirth.myndandroid.model.Scenario
import com.thegrizzlylabs.sardineandroid.impl.OkHttpSardine
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JSON
import org.jetbrains.anko.doAsync
import org.json.JSONArray
import org.json.JSONObject

enum class Pref(val key: String, val default: Any, val preventReset: Boolean = false) {
    DEV_MODE("developerModeEnabled", false),
    SUBJECT_ID("uuid", "missinguserid"),
    PATIENT_NAME("patientname", ""),
    TTS("isTTSEnabled", true),
    VERY_FIRST_STARTUP("new", true, true),
    OWN_CLOUD_PW("owncloudpw", default = "", preventReset = true),
    OWN_CLOUD_USER("ownclouduser", default = "username", preventReset = true),
    AUTOMATIC_TRANSFER("autotransfer", default = true)
}

private enum class JSONPref(val key: String) { // add a version tag to each key to safely restore
    RECORDING_FILE_NAMES("RecordingFile_v1"),
    STUDY_STATE("studystate_v1"),
}

fun resetSharedPrefs(c: Context) {
    val editor = getPrefs(c).edit()
    Pref.values()
            .filter { !it.preventReset }
            .forEach { pref ->
                when (pref.default) {
                    is Boolean -> editor.putBoolean(pref.key, pref.default)
                    is String -> editor.putString(pref.key, pref.default)
                }
            }
    editor.remove(Pref.SUBJECT_ID.key) // this is special, need to remove completely
    //JSONPref.values().map { it.key }.forEach { editor.remove(it) }
    editor.remove(JSONPref.STUDY_STATE.key)
    editor.apply()
}

private fun getPrefs(c: Context): SharedPreferences {
    return c.getSharedPreferences("Mynd_SharedPrefs", Context.MODE_PRIVATE)
}

fun <T : Any> getPrefOrNull(c: Context, p: Pref): T? {
    return if (!getPrefs(c).contains(p.key))
        null
    else getPrefOrDefault(c, p)
}

fun <T : Any> getPrefOrDefault(c: Context, p: Pref): T {
    return when (p.default) {
        is Boolean -> getPrefs(c).getBoolean(p.key, p.default) as T
        is String -> getPrefs(c).getString(p.key, p.default) as T
        else -> throw NotImplementedError("Missing implementation for ${p.default::class}")
    }
}

fun <T : Any> setPref(c: Context, p: Pref, value: T) {
    if (p.default::class != value::class) throw IllegalArgumentException("wrong type for this setting")
    val editor = getPrefs(c).edit()
    when (p.default) {
        is Boolean -> editor.putBoolean(p.key, value as Boolean)
        is String -> editor.putString(p.key, value as String)
        else -> throw NotImplementedError("Missing implementation for ${p.default::class}")
    }
    editor.apply()
}


@Serializable
data class RecordingFile(val fileName: String, var uploaded: Boolean, var numLines: Int, var fileSizeKB: Long, var paradigm: String, val userID: String, val  dateString: String)


fun getStudyState(c: Context): List<Scenario>? {
    if (!getPrefs(c).contains(JSONPref.STUDY_STATE.key)) {
        return null
    }
    val rawString = getPrefs(c).getString(JSONPref.STUDY_STATE.key, "[]")
    val jsonArr = JSONArray(rawString)
    return (0 until jsonArr.length())
            .map { jsonArr.getJSONObject(it).toString(4) }
            .map { JSON.parse<Scenario>(it) }
            .also { scenarios ->
                scenarios.flatMap { it.blocks }.flatMap { it.trials }.flatMap { it.phases }
                        .forEach { phase -> phase.init(c) }
            }
}

fun saveStudyState(c: Context, scenarios: List<Scenario>) {
    val json = JSONArray()
    scenarios.map { JSON.stringify(it) }
            .map { JSONObject(it) }
            .forEach { json.put(it) }
    val state = json.toString(4)
    getPrefs(c).edit()
            .putString(JSONPref.STUDY_STATE.key, state)
            .apply()
}

fun getRecordingFiles(c: Context): List<RecordingFile> {
    val json = getPrefs(c).getString(JSONPref.RECORDING_FILE_NAMES.key, "[]")
    val arr = JSONArray(json)
    return (0 until arr.length())
            .map { arr.get(it).toString() }
            .map { JSON.parse<RecordingFile>(it) }
}

fun saveRecordingFiles(c: Context, files: List<RecordingFile>) {
    val json = JSONArray()
    files.forEach { json.put(JSON.stringify(it)) }
    getPrefs(c).edit()
            .putString(JSONPref.RECORDING_FILE_NAMES.key, json.toString())
            .apply()
}

fun testConnection(c: Context, didSucceedCallback: (Boolean) -> Unit) = c.doAsync {
    val sardine = OkHttpSardine()
    sardine.setCredentials(getPrefOrDefault(c,Pref.OWN_CLOUD_USER), getPrefOrDefault(c,Pref.OWN_CLOUD_PW))
    var exception = false
    var list: List<Any>? = null
    try {
        list = sardine.list(c.getString(R.string.owncloud_baseURL))
        Log.i("mynd_OwnCloud", "baseURL ${c.getString(R.string.owncloud_baseURL)} " +
                "contains the following files:\n" + list?.joinToString("\n"))
        if(list.indexOfFirst { it.isDirectory && it.name == c.getString(R.string.owncloud_path)} == -1){
            Log.i("mynd_OwnCloud", "direcotry baseURL/${c.getString(R.string.owncloud_path)} " +
                    "does not exist. will create it now")
            sardine.createDirectory(c.getString(R.string.owncloud_baseURL) + c.getString(R.string.owncloud_path))
        } else {
            Log.i("mynd_OwnCloud", "direcotry baseURL/${c.getString(R.string.owncloud_path)} " +
                    "already exists")
        }
    } catch (e: Exception) {
        Log.w("mynd_Owncloud", "testConnection: list dir did not work", e)
        exception = true
    }
    didSucceedCallback(!exception && list != null)
}


fun showOwnCloudDialog(c: Context, callback: (success: Boolean) -> Unit) {
    MaterialDialog.Builder(c)
            .title(c.getString(R.string.owncloud_dialog_title))
            .content(c.getString(R.string.owncloud_dialog_username))
            .inputType(InputType.TYPE_CLASS_TEXT)
            .input(c.getString(R.string.owncloud_dialog_unchanged), getPrefOrDefault(c, Pref.OWN_CLOUD_USER)) { _, username ->
                if (username.isNotEmpty()) {
                    getPrefs(c).edit()
                            .putString(Pref.OWN_CLOUD_USER.key, username.toString())
                            .apply()
                }
                MaterialDialog.Builder(c)
                        .title(c.getString(R.string.owncloud_dialog_title))
                        .content(c.getString(R.string.owncloud_dialog_pw))
                        .inputType(InputType.TYPE_TEXT_VARIATION_PASSWORD)
                        .input(c.getString(R.string.owncloud_dialog_unchanged), "") { _, pw ->
                            if (pw.isNotEmpty()) {
                                getPrefs(c).edit()
                                        .putString(Pref.OWN_CLOUD_PW.key, pw.toString())
                                        .apply()
                            }
                            testConnection(c, callback)
                        }
                        .show()
            }
            .show()
}