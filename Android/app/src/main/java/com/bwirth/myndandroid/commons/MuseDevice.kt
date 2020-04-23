package com.bwirth.myndandroid.commons

import android.bluetooth.BluetoothAdapter
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.bwirth.myndandroid.model.EEGData
import com.choosemuse.libmuse.*
import io.reactivex.subjects.BehaviorSubject
import kotlin.math.roundToInt


/** Represents the connected muse device
 *  Communication with the Muse is very low-level, but the provided SDK helps with
 *  setting up the connection via bluetooth.
 */
object MuseDevice {

    enum class DeviceState {
        FOUND,
        CONNECTED,
        ON_HEAD,
        DISCONNECTED
    }


    val channels = arrayOf("Left Ear", "Left Front", "Right Front", "Right Ear")
    private val dataListener = MyDataListener()

    const val samplingRate = 256

    var muse: Muse? = null
        private set

    var eegData = BehaviorSubject.create<EEGData>()
        private set

    var state = BehaviorSubject.create<DeviceState>()

    var battery = BehaviorSubject.create<Int>()

    val PRESET = MusePreset.PRESET_20


    fun isAvailable() = muse != null

    fun onConnectionChanged(newState: ConnectionState, m: Muse?) {
        when (newState) {
            ConnectionState.DISCONNECTED -> {
                state.onNext(DeviceState.DISCONNECTED)
                battery = BehaviorSubject.create<Int>()
                eegData = BehaviorSubject.create<EEGData>()
                muse = null
            }
            ConnectionState.CONNECTING -> {
                state.onNext(DeviceState.FOUND)
            }
            ConnectionState.CONNECTED -> {
                muse = m
                state.onNext(DeviceState.CONNECTED)
            }
            else -> {
            }
        }
    }

    val btStateReceiver: BroadcastReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == BluetoothAdapter.ACTION_STATE_CHANGED &&
                    intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR) == BluetoothAdapter.STATE_OFF) {
                onConnectionChanged(ConnectionState.DISCONNECTED, muse)
            }
        }
    }

    class MyDataListener : MuseDataListener() {
        override fun receiveMuseDataPacket(packet: MuseDataPacket, m: Muse?) {
            if (packet.packetType() == MuseDataPacketType.EEG) {
                val eegValues = listOf(
                        packet.getEegChannelValue(Eeg.EEG1),
                        packet.getEegChannelValue(Eeg.EEG2),
                        packet.getEegChannelValue(Eeg.EEG3),
                        packet.getEegChannelValue(Eeg.EEG4))
                eegValues.indexOfFirst { it.isNaN() }.let { nanIndex ->
                    if (nanIndex >= 0) Log.w("mynd_muse", "NaN values received at EEGvalues index $nanIndex")
                    else MuseDevice.eegData.onNext(EEGData(eegValues, packet.timestamp()))
                }
            } else if (packet.packetType() == MuseDataPacketType.BATTERY) {
                MuseDevice.battery.onNext(packet.getBatteryValue(Battery.CHARGE_PERCENTAGE_REMAINING).roundToInt())
            }
        }

        override fun receiveMuseArtifactPacket(packet: MuseArtifactPacket, m: Muse) {
            if (packet.headbandOn && MuseDevice.isAvailable()) {
                MuseDevice.state.onNext(MuseDevice.DeviceState.ON_HEAD)
            }
        }

    }


    val manager: MuseManagerAndroid by lazy {
        MuseManagerAndroid.getInstance()
    }

    private val connectionListener = object : MuseConnectionListener() {
        // called only for muses on which registerlistener  has been called
        override fun receiveMuseConnectionPacket(p: MuseConnectionPacket, muse: Muse) {
            MuseDevice.onConnectionChanged(p.currentConnectionState, muse)
            if (p.currentConnectionState == ConnectionState.CONNECTED)
                manager.stopListening()
        }
    }


    private val museListener = object : MuseListener() {
        override fun museListChanged() {
            if (manager.muses.isNotEmpty() && !MuseDevice.isAvailable()) { // considers only one device nearby
                connectWith(manager.muses.first())
            }
        }
    }

    /**
     * discovers muse devices that are bond with the device.
     * They are not necessarily connected/ nearby right now
     */
    fun startListening(context: Context) {
        Log.i("Connect", "starting to listen for muse devices")
        manager.setContext(context)
        manager.setMuseListener(museListener)
        manager.startListening()
    }


    /**
     * Stops listening
     */
    fun stopListening() {
        Log.i("muse_device", "stop to listen for muse devices")
        manager.stopListening()
    }

    fun disconnect() {
        Log.i("muse_device", "disconnect")
        muse?.disconnect()
    }


    /**
     * stops listening, then tries to connect with bonded device.
     * This will fail in case the bonded device is not available.
     * Don't forget to call startListening() again in case it failed
     */
    fun connectWith(muse: Muse) {
        Log.i("Connect", "trying to connect to muse device ${muse.name}")
        manager.stopListening()

        muse.unregisterAllListeners()
        muse.registerConnectionListener(connectionListener)
        muse.setPreset(MuseDevice.PRESET)
        muse.registerDataListener(dataListener, MuseDataPacketType.ARTIFACTS)
        muse.registerDataListener(dataListener, MuseDataPacketType.BATTERY)
        muse.registerDataListener(dataListener, MuseDataPacketType.EEG)

        // Initiate a connection to the headband and stream the eegData asynchronously.
        muse.runAsynchronously()
    }
}