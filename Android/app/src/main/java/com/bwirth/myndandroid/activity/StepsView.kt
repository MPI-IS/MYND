package com.bwirth.myndandroid.activity

import android.content.Context
import android.graphics.drawable.Drawable
import android.net.Uri
import android.util.Log
import android.view.View
import android.widget.*
import com.bwirth.myndandroid.R


class InstructionStep(val id: String, val instruction: String, val imageResource: String) {
    fun isVideo(): Boolean {
        return imageResource.endsWith("mp4")
    }
}

/**
 * This class provides the logic behind the steps necessary to connect and fit the headband.
 */
class StepsView(private val c: Context, viewRoot: View, tts: MuseTTS) {
    private val videoView = viewRoot.findViewById<VideoView>(R.id.steps_videoview)
    val imageview_steps = viewRoot.findViewById<ImageView?>(R.id.imageview_steps)
    val status = viewRoot.findViewById<TextView>(R.id.status)
    val button_nextstep = viewRoot.findViewById<Button>(R.id.button_nextstep)
    var currentStep: InstructionStep? = null
    private val speak = tts
    private var stop = false

    fun enableNextStep() {
        button_nextstep.isEnabled = true
    }

    fun disableNextStep() {
        button_nextstep.isEnabled = false
    }

    fun stop() {
        stop = true
        videoView.stopPlayback()
        // gifImageView_steps.stopAnimation()
    }


    fun show(currentStep: InstructionStep, callback: () -> Unit, enableNextStep: Boolean = false) {
        Log.i("Strepsivew","showing step ${currentStep.instruction}")
        this.currentStep = currentStep
        Log.i("RenderStep", "rendering step ${currentStep.id} with imageresource ${currentStep.imageResource}")
        button_nextstep.isEnabled = enableNextStep
        button_nextstep.setOnClickListener { callback() }
        status.text = currentStep.instruction
        if (currentStep.imageResource.isEmpty()) {
            imageview_steps?.visibility = View.INVISIBLE
            videoView.visibility = View.INVISIBLE
        } else {
            imageview_steps?.visibility = View.VISIBLE
            videoView.visibility = View.VISIBLE
            if (currentStep.isVideo()) {
                imageview_steps?.visibility = View.INVISIBLE
                showVideo(currentStep.imageResource)
            } else {
                imageview_steps?.visibility = View.VISIBLE
                showImage(currentStep.imageResource)
            }
        }
        speak.speak(currentStep.instruction){Log.i("ttsspeak", "done speaking " + currentStep.instruction.substring(0,20))}
    }

    private fun showImage(imageResource: String) {
        if (stop) return
        Log.i("RenderStep", "showing image $imageResource")
            imageview_steps?.setImageResource(c.resources.getIdentifier(imageResource.substringBeforeLast("."),"drawable",c.packageName))
            videoView.stopPlayback()

    }


    private fun showVideo(imageResource: String) {
        val res = imageResource.substringBeforeLast(".")
        if (stop) return

        videoView.setMediaController(MediaController(c))
        val uri = "android.resource://" + c.packageName + "/" + c.resources.getIdentifier(res, "raw", c.packageName)
        videoView.setVideoURI(Uri.parse(uri))
        videoView.setMediaController(null)
        videoView.start()
        videoView.setOnPreparedListener {
            it.isLooping = true;it.setVolume(0F, 0F)
        }

    }

}