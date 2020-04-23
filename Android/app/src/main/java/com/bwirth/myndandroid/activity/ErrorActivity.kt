package com.bwirth.myndandroid.activity

import android.os.Bundle
import android.view.View
import com.bwirth.myndandroid.R
import com.bwirth.myndandroid.model.Study
import kotlinx.android.synthetic.main.activity_pause.*

/**
 * Displays an error to the user. This is used for displaying when the battery is low or
 * when a block was interrupted due to the app being put to background.
 */
class ErrorActivity : MyndActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_pause)

        button_continue.setOnClickListener { finish() }

        blurry_scenario_bg.setImageResource(R.drawable.backgroundstatic)
        image_done.setImageResource(R.drawable.disconnected)

        negative_button.visibility = View.INVISIBLE
        button_continue.text = getString(R.string.error_ok)
        continue_title.text = getString(R.string.disonnected_title)
        continue_text.text = getString(R.string.disconnected_text)

        ttsInstance.speak(continue_text.text.toString())
    }

    override fun onBackPressed() {
        finish()
    }
}