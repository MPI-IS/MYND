package com.bwirth.myndandroid.activity

import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.support.v4.content.ContextCompat
import android.support.v4.content.FileProvider
import android.util.Log
import android.view.MenuItem
import android.view.View
import android.widget.ArrayAdapter
import android.widget.Toast
import com.afollestad.materialdialogs.MaterialDialog
import com.bwirth.myndandroid.BuildConfig
import com.bwirth.myndandroid.R
import com.bwirth.myndandroid.commons.*
import com.thegrizzlylabs.sardineandroid.impl.OkHttpSardine
import kotlinx.android.synthetic.main.activity_recording_history.*
import kotlinx.android.synthetic.main.view_toolbar.*
import org.jetbrains.anko.doAsync
import java.io.File
import java.text.SimpleDateFormat
import java.util.*

/**
 * This is a hidden activity, which can only be accessed by the experimenter from the settings.
 * It allows to manage experimental data stored on the device.
 */
class RecordingHistoryActivity : MyndActivity() {
    private lateinit var recordingFiles: MutableList<RecordingFile>
    private lateinit var adapter: ArrayAdapter<String>

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_recording_history)
        setSupportActionBar(toolbar)
        supportActionBar?.setDisplayHomeAsUpEnabled(true)
        supportActionBar?.setDisplayShowHomeEnabled(true)
        sessioncard_image.visibility = View.GONE
        title = ""
        toolbar_title.text = getString(R.string.toolbar_title_recordinghistory)
        recordingFiles = getRecordingFiles(this).toMutableList()
        adapter = ArrayAdapter(this, android.R.layout.simple_list_item_1)
        recording_list.adapter = adapter

        recording_list.setOnItemClickListener { parent, view, position, id ->
            showItemDialog(id.toInt())
        }

        val hasPermission = ContextCompat.checkSelfPermission(this,
                android.Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED

        if (!hasPermission) {
            createzipbutton.isEnabled = false
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                requestPermissions(arrayOf(android.Manifest.permission.WRITE_EXTERNAL_STORAGE), 0)
            }
        }

        createzipbutton.setOnClickListener {
            fun zip(s: String) = doAsync {
                    compressFiles(this@RecordingHistoryActivity,
                            recordingFiles.map { it -> File(filesDir, it.fileName) },
                            File(Environment.getExternalStorageDirectory(), "mynd/$s"))
                }
            MaterialDialog.Builder(this)
                    .title("Creates a zip")
                    .content("Override mynd.zip or create a unique zip file with timestamp?")
                    .negativeText("mynd.zip")
                    .positiveText("unique")
                    .onNegative{_,_ -> zip("mynd.zip")}
                    .onPositive{_,_ ->
                        val datestring = SimpleDateFormat(getString(R.string.date_format_filename), Locale.ENGLISH).format(Date())
                        zip("mynd_$datestring.zip")
                    }
                    .show()
        }
        deleteallbutton.setOnClickListener{
            MaterialDialog.Builder(this)
                    .title("Delete All")
                    .content("Delete ${recordingFiles.size} file(s)?")
                    .positiveColor(ContextCompat.getColor(this, R.color.mp_red))
                    .positiveText("Delete!")
                    .titleColor(ContextCompat.getColor(this, R.color.mp_red))
                    .onPositive { _, _ -> repeat(recordingFiles.size) {_ -> delete(0)} }
                    .show()
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 0 && grantResults[permissions.indexOf(android.Manifest.permission.WRITE_EXTERNAL_STORAGE)] == PackageManager.PERMISSION_GRANTED) {
            createzipbutton.isEnabled = true
        }
    }


    override fun onOptionsItemSelected(item: MenuItem?): Boolean {
        return when (item?.itemId) {
            android.R.id.home -> {
                finish(Result.NONE)
                true
            }
            else -> super.onOptionsItemSelected(item)
        }
    }

    private fun showItemDialog(index: Int) {
        MaterialDialog.Builder(this)
                .title(recordingFiles[index].fileName)
                .content(getFileDetails(index))
                .positiveText("upload")
                .neutralText("delete")
                .neutralColor(ContextCompat.getColor(this, R.color.mp_red))
                .negativeText("view")
                .onNegative{_,_ ->
                try {
                    open(index)
                } catch (e: Exception){showToast("Install a viwer app first", Toast.LENGTH_SHORT)}
                }
                .onPositive { _, _ -> send(index) }
                .onNeutral { _, _ -> delete(index) }
                .show()
    }

    private fun getFileDetails(index: Int): String {
        val file = recordingFiles[index]
        val updateStatus = if (file.uploaded) "On Server" else "Not uploaded yet"
        return "ID: ${file.userID}\n" +
                "Paradigm: ${file.paradigm}\n" +
                "Lines: ${file.numLines}\n" +
                "Size: ${file.fileSizeKB} KB\n" +
                "Status: $updateStatus\n"

    }

    private fun delete(index: Int) {
        val fileToDelete = File(filesDir, recordingFiles[index].fileName)
        val didDelete = fileToDelete.delete()
        if (!didDelete) {
            Log.e(TAG, "Could not delete file ${fileToDelete.path}")
            return
        }
        recordingFiles.removeAt(index)
        updateView()
        saveRecordingFiles(this, recordingFiles)
    }

    override fun onResume() {
        super.onResume()
        updateView()
    }

    private fun updateView(){
        adapter.clear()
        adapter.addAll(recordingFiles.map {
            "${if (it.uploaded) "SERVER" else "LOCAL"} | ${it.paradigm} | ${it.userID}" +
                    "\n${it.dateString} | ${it.fileSizeKB} KB"})
        adapter.notifyDataSetChanged()
        if(recordingFiles.isEmpty()){
            norecordingshint.visibility = View.VISIBLE
            deleteallbutton.visibility = View.GONE
            createzipbutton.visibility = View.GONE
        } else {
            norecordingshint.visibility = View.GONE
            deleteallbutton.visibility = View.VISIBLE
            createzipbutton.visibility = View.VISIBLE
        }
    }

    private fun send(index: Int) {
        val fileToSend = File(filesDir, recordingFiles[index].fileName)
        Log.i(TAG, "will now send ${fileToSend.name}")


        doAsync {
            try {
                val sardine = OkHttpSardine()
                sardine.setCredentials(getPrefOrDefault(this@RecordingHistoryActivity, Pref.OWN_CLOUD_USER), getPrefOrDefault(this@RecordingHistoryActivity, Pref.OWN_CLOUD_PW))
                sardine.put("${getString(R.string.owncloud_baseURL)}${getString(R.string.owncloud_path)}/${fileToSend.name}", fileToSend.readBytes())
                showToast("success: uploaded ${fileToSend.name}", Toast.LENGTH_LONG)
                Log.i(TAG, "success: uploaded ${fileToSend.name}")
                recordingFiles[index].uploaded = true
                saveRecordingFiles(this@RecordingHistoryActivity, recordingFiles)
                runOnUiThread{updateView()}
            } catch (e: Exception) {
                logToFileAndCat("failed to upload file ${fileToSend.name}\n"+Log.getStackTraceString(e), Log::w)
                val diag = MaterialDialog.Builder(this@RecordingHistoryActivity)
                        .title(fileToSend.name)
                        .positiveText("\uD83D\uDCA9")
                        .content("Failed: \n${e.message}\ncause: ${e.cause?.message}")
                        runOnUiThread{diag.show()}
            }
        }


    }

    private fun open(index: Int){
        val fileToSend = File(filesDir, recordingFiles[index].fileName)
        val intent = Intent()
        intent.action = android.content.Intent.ACTION_VIEW
        val apkURI = FileProvider.getUriForFile(this, BuildConfig.APPLICATION_ID + ".provider", fileToSend);
        intent.setDataAndType(apkURI, "text/csv")
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        startActivity(intent)

    }

    override fun onBackPressed() {
        finish(Result.NONE)
    }
}