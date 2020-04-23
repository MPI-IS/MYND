package com.bwirth.myndandroid.model

import android.content.Context
import android.util.Log
import com.bwirth.myndandroid.model.TrialType.*
import kotlinx.serialization.Serializable
import kotlinx.serialization.Transient


/**
 * A Scenario defined the blocks, trials and randomization of an experiment chunk.
 * The Factory pattern is being used to instantiate scenarios from the Study object.
 * Scenarios are shown on the welcome screen after logging into the app.
 */
@Serializable
class Scenario(private val titleRes: String, private val textRes: String, val image: String,
               val paradigm: String, val blocks: List<Block>) {
    @Transient
    var title: String = ""
    @Transient
    var text: String = ""

    fun isFinished() = blocks.all(Block::isFinished)

    fun getCurrentBlock() = blocks.firstOrNull { !it.isFinished }
    fun getCurrentBlockIndex() = blocks.indexOfFirst { !it.isFinished }

    fun getImage(c: Context) = c.resources.getIdentifier(image, "drawable", c.packageName)
    fun getImageBlurry(c: Context) = c.resources.getIdentifier(image + "_blurry", "drawable", c.packageName)


    fun init(c: Context) {
        Log.d("Resource", "trying to parse scenario with res ids  '$titleRes', '$textRes'")
        title = c.getString(c.resources.getIdentifier(titleRes, "string", c.packageName))
        text = c.getString(c.resources.getIdentifier(textRes, "string", c.packageName))
        blocks.flatMap { it.trials }.flatMap { it.phases }.forEach { phase -> phase.init(c) }
    }


    class Factory(private val c: Context) {
        val scenarios = mutableListOf<Scenario>()

        fun restingState(): Factory {
            scenarios.add(Scenario(
                    titleRes = "title_resting_state",
                    textRes = "descr_restingstate",
                    image = "resting",
                    paradigm = "resting",
                    blocks = createBlocks(3, true,
                            { createTrials(1, EYESOPEN, 300) },
                            { createTrials(1, EYESCLOSED, 400) }
                    )))
            return this
        }

        fun music(): Factory {
            scenarios.add(Scenario(
                    titleRes = "title_music_imagery",
                    textRes ="descr_music_imagery",
                    image = "music",
                    paradigm = "music",
                    blocks = createBlocks(3, true,
                            { createTrials(3, TrialType.MUSIC, 300) },
                            { createTrials(3, MENTALSUBTRACTION, 400) }
                    )))
            return this
        }

        fun memories(): Factory {
            scenarios.add(Scenario(
                    titleRes = "title_positive_memories",
                    textRes = "descr_positive_memories",
                    image = "demo",
                    paradigm = "posmem",
                    blocks = createBlocks(3, true,
                            { createTrials(3, POSITIVEMEMORIES, 300) },
                            { createTrials(3, MENTALSUBTRACTION, 400) }
                    )))
            return this
        }

        private fun createBlocks(numBlocks: Int, shuffle: Boolean, vararg trialGenerators: () -> Collection<Trial>): MutableList<Block> {
            val blocks: MutableList<Block> = mutableListOf()
            repeat(numBlocks) {
                val blockTrials = mutableListOf<Trial>()
                trialGenerators.forEach { generate ->
                    blockTrials.addAll(generate())
                }
                if (shuffle) blockTrials.shuffle()
                blockTrials.add(0, createTrial(WELCOME, 900))
                blockTrials.add(blockTrials.size, createTrial(GOODBYE, 900))
                blocks.add(Block(blockTrials))
            }
            return blocks
        }
    }
}

