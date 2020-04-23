package com.bwirth.myndandroid.view

import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import com.bwirth.myndandroid.R
import com.bwirth.myndandroid.model.Scenario
import de.hdodenhof.circleimageview.CircleImageView
import kotlin.math.roundToInt

/**
 * An adapter for the list view of scenarios on the Welcome Screen.
 */
class ScenarioAdapter(private val c: Context, val resource: Int, private val list: List<Scenario>, val onClick: (Scenario) -> Unit) :
        ArrayAdapter<Scenario>(c, resource, list) {
    private var vi = context.getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater

    override fun getView(position: Int, convertView: View?, parent: ViewGroup): View? {
        val holder: ViewHolder
        val resultView: View?

        if (convertView == null) {
            resultView = vi.inflate(resource, null)
            holder = ViewHolder()
            holder.image = resultView.findViewById(R.id.sessioncard_image)
            holder.imageBG = resultView.findViewById(R.id.sessioncard_bg)
            holder.title = resultView.findViewById(R.id.sessioncard_title)
            holder.text = resultView.findViewById(R.id.sessioncard_text)
            holder.button = resultView.findViewById(R.id.sessioncard_button)
            resultView.tag = holder
        } else {
            holder = convertView.tag as ViewHolder
            resultView = convertView
        }
        holder.image?.setImageResource(list[position].getImage(c))
        holder.imageBG?.setImageResource(list[position].getImageBlurry(c))
        val remaining = list[position].blocks.filter { !it.isFinished }.count()
        val minutes =  list[position].blocks.filter { !it.isFinished }.map { it.getDuration() }.sum().div(60).roundToInt()
        holder.text?.text = c.resources.getQuantityString(R.plurals.blocks_remaining_plural, remaining, remaining, minutes)
        holder.title?.text = list[position].title

        if (list[position].blocks.all { !it.isFinished }) {
            holder.button?.text = c.getString(R.string.start_session)
        } else {
            holder.button?.text = c.resources.getQuantityString(R.plurals.continue_session, remaining)
        }
        holder.button?.setOnClickListener { onClick(list[position]) }
        holder.button?.visibility = if(position > 0) View.GONE else View.VISIBLE
        return resultView
    }

    internal class ViewHolder {
        var title: TextView? = null
        var text: TextView? = null
        var image: CircleImageView? = null
        var imageBG: ImageView? = null
        var button: Button? = null

    }
}