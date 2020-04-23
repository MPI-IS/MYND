package com.bwirth.myndandroid.activity

import android.content.Intent
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.EditText
import android.widget.Toast
import com.afollestad.materialdialogs.DialogAction
import com.afollestad.materialdialogs.MaterialDialog
import com.bwirth.myndandroid.R
import com.bwirth.myndandroid.commons.Pref
import com.bwirth.myndandroid.commons.getPrefOrDefault
import com.bwirth.myndandroid.commons.setPref
import com.bwirth.myndandroid.commons.showOwnCloudDialog
import eightbitlab.com.blurview.RenderScriptBlur
import kotlinx.android.synthetic.main.activity_signup.*
import java.util.regex.Pattern


/**
 * This activity is shown in the beginning of a study. The user has to provide a name,
 * an ID (experimental subject ID) and a password (predefined by the experimenter).
 */
class SignUpActivity : MyndActivity() {
    // may contain alphanumeric and underscores and minus, must begin with one alphanumeric char
    private val validID = Pattern.compile("[a-zA-Z0-9]+[a-zA-Z0-9_-]*")

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_signup)
        button_signup.setOnClickListener { showSignupDialog(false, "","") }
        initBlurView()
        if (getPrefOrDefault(this, Pref.VERY_FIRST_STARTUP)) {
            showOwnCloudDialog(this) {success ->
                if (success) {
                    setPref(this, Pref.VERY_FIRST_STARTUP, false)
                    showToast(getString(R.string.connection_established), Toast.LENGTH_SHORT)
                } else {
                    showToast(getString(R.string.not_connected), Toast.LENGTH_SHORT)
                }
            }
        }
    }

    /**
     * Setup the blur view such that the underlying gif is blurred
     */
    private fun initBlurView() {
        val rootView = window.decorView.findViewById<ViewGroup>(android.R.id.content)
        val windowBackground = window.decorView.background

        blurView.setupWith(rootView)
                .windowBackground(windowBackground)
                .blurAlgorithm(RenderScriptBlur(this))
                .blurRadius(25f)
                .setHasFixedTransformationMatrix(true)


    }

    /**
     * Shows a dialog with fields for id and password.
     */
    private fun showSignupDialog(indicateError: Boolean, userNameText: String, patientNameText: String) {
        val dialog = MaterialDialog.Builder(this)
                .title(R.string.signUpDialogTitle)
                .customView(R.layout.dialog_signup, false)
                .positiveText(R.string.dialog_positive)
                .negativeText(R.string.dialog_negative)
                .onPositive { d, _ ->
                    checkPassword(d)
                }.build()

        val positive = dialog.getActionButton(DialogAction.POSITIVE)
        val userId = dialog.customView?.findViewById<EditText>(R.id.username)
        val patientname = dialog.customView?.findViewById<EditText>(R.id.patientname)
        val pw = dialog.customView?.findViewById<EditText>(R.id.pw)
        val pwHint = dialog.customView!!.findViewById<View>(R.id.password_wrong)
        if (indicateError) {
            pwHint.visibility = View.VISIBLE
            pw?.requestFocus()
        } else {
            pwHint.visibility = View.GONE
        }

        positive.isEnabled = false
        userId?.setText(userNameText)
        patientname?.setText(patientNameText)

        val listener = object : TextWatcher {
            override fun beforeTextChanged(p0: CharSequence?, p1: Int, p2: Int, p3: Int) {
            }

            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
            }

            override fun afterTextChanged(arg0: Editable) {
                positive.isEnabled = userId?.text?.isNotBlank() ?: false
                        && pw?.text?.isNotBlank() ?: false
                        && patientname?.text?.isNotBlank() ?: false
                        && validID.matcher(userId!!.text!!.trim()).matches()
                        && userId.text.toString().trim().length < 20
            }
        }

        userId?.addTextChangedListener(listener)
        pw?.addTextChangedListener(listener)
        dialog.window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE)
        dialog.show()
    }


    /**
     * Checks if the password is correct. If so, starts HomeActivity. If not,
     * retains the username and clears the password field, also shows an error message.
     */
    private fun checkPassword(dialog: MaterialDialog) {
        val pw = dialog.customView!!.findViewById<EditText>(R.id.pw)
        val username = dialog.customView!!.findViewById<EditText>(R.id.username)
        val patientname = dialog.customView!!.findViewById<EditText>(R.id.patientname)

        if (pw.text.toString().toLowerCase() == getString(R.string.signup_password)) {
            setPref(this, Pref.SUBJECT_ID, username.text.toString().trim())
            setPref(this, Pref.PATIENT_NAME, patientname.text.toString().trim())
            val intent = Intent(this, HomeActivity::class.java)
            setPref(this, Pref.VERY_FIRST_STARTUP, false)
            startActivity(intent)
        } else {
            showSignupDialog(true, username.text.toString(), patientname.text.toString())
        }
    }

    override fun onBackPressed() {

    }
}