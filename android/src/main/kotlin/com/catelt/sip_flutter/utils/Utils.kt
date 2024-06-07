package com.catelt.sip_flutter.utils

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.net.wifi.WifiManager
import android.os.Build
import android.util.Log
import java.io.File
import java.io.FileNotFoundException
import java.io.FileOutputStream
import java.io.IOException
import java.lang.reflect.Method
import java.net.InetAddress
import java.net.NetworkInterface
import java.net.SocketException
import java.util.Enumeration
import java.util.concurrent.Executor

const val TAG = "Baresip"

object Utils {
    fun copyAssetToFile(context: Context, asset: String, path: String) {
        try {
            val `is` = context.assets.open(asset)
            val os = FileOutputStream(path)
            val buffer = ByteArray(512)
            var byteRead: Int = `is`.read(buffer)
            while (byteRead != -1) {
                os.write(buffer, 0, byteRead)
                byteRead = `is`.read(buffer)
            }
            os.close()
            `is`.close()
        } catch (e: IOException) {
            Log.e(TAG, "Failed to copy asset '$asset' to file: $e")
        }
    }

    fun getFileContents(filePath: String): ByteArray? {
        return try {
            File(filePath).readBytes()
        } catch (e: FileNotFoundException) {
            Log.e(TAG, "File '$filePath' not found: ${e.printStackTrace()}")
            null
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read file '$filePath': ${e.printStackTrace()}")
            null
        }
    }

    fun putFileContents(filePath: String, contents: ByteArray): Boolean {
        try {
            File(filePath).writeBytes(contents)
        } catch (e: IOException) {
            Log.e(TAG, "Failed to write file '$filePath': $e")
            return false
        }
        return true
    }

    fun setSpeakerPhone(
        executor: Executor,
        am: AudioManager,
        enable: Boolean,
        result: (isSpeakerOn: Boolean) -> Unit
    ) {
        if (Build.VERSION.SDK_INT >= 31) {
            val current = am.communicationDevice!!.type
            Log.d(TAG, "Current com dev/mode is $current/${am.mode}")
            var speakerDevice: AudioDeviceInfo? = null
            if (enable) {
                for (device in am.availableCommunicationDevices)
                    if (device.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER) {
                        speakerDevice = device
                        break
                    }
            } else {
                for (device in am.availableCommunicationDevices)
                    if (device.type == AudioDeviceInfo.TYPE_BUILTIN_EARPIECE) {
                        speakerDevice = device
                        break
                    }
            }
            if (speakerDevice == null) {
                Log.w(TAG, "Could not find requested communication device")
                result.invoke(isSpeakerPhoneOn(am))
                return
            }
            if (current != speakerDevice.type) {
                if (speakerDevice.type == AudioDeviceInfo.TYPE_BUILTIN_EARPIECE) {
                    clearCommunicationDevice(am)
                    Log.d(TAG, "Setting com device to TYPE_BUILTIN_EARPIECE")
                    if (!am.setCommunicationDevice(speakerDevice))
                        Log.e(TAG, "Could not set com device")
                    if (am.mode == AudioManager.MODE_NORMAL) {
                        Log.d(TAG, "Setting mode to communication")
                        am.mode = AudioManager.MODE_IN_COMMUNICATION
                    }
                    result.invoke(false)
                } else {
                    // Currently at API levels 31+, speakerphone needs normal mode
                    if (am.mode == AudioManager.MODE_NORMAL) {
                        Log.d(TAG, "Setting com device to ${speakerDevice.type} in MODE_NORMAL")
                        if (!am.setCommunicationDevice(speakerDevice))
                            Log.e(TAG, "Could not set com device")
                        result.invoke(true)
                    } else {
                        val normalListener = object : AudioManager.OnModeChangedListener {
                            override fun onModeChanged(mode: Int) {
                                if (mode == AudioManager.MODE_NORMAL) {
                                    am.removeOnModeChangedListener(this)
                                    Log.d(
                                        TAG, "Setting com device to ${speakerDevice.type}" +
                                                " in mode ${am.mode}"
                                    )
                                    if (!am.setCommunicationDevice(speakerDevice))
                                        Log.e(TAG, "Could not set com device")
                                    result.invoke(true)
                                }
                            }
                        }
                        am.addOnModeChangedListener(executor, normalListener)
                        Log.d(TAG, "Setting mode to NORMAL")
                        am.mode = AudioManager.MODE_NORMAL
                    }
                }
                Log.d(TAG, "New com device/mode is ${am.communicationDevice!!.type}/${am.mode}")
            } else {
                result.invoke(isSpeakerPhoneOn(am))
            }
        } else {
            @Suppress("DEPRECATION")
            am.isSpeakerphoneOn = enable
            Log.d(TAG, "Speakerphone is $enable")
            result.invoke(enable)
        }
    }

    private fun clearCommunicationDevice(am: AudioManager) {
        if (Build.VERSION.SDK_INT >= 31) {
            am.clearCommunicationDevice()
        } else {
            @Suppress("DEPRECATION")
            if (am.isSpeakerphoneOn)
                am.isSpeakerphoneOn = false
        }
    }

    fun toggleSpeakerPhone(
        executor: Executor,
        am: AudioManager,
        result: (isSpeakerOn: Boolean) -> Unit
    ) {
        if (Build.VERSION.SDK_INT >= 31) {
            if (am.communicationDevice!!.type == AudioDeviceInfo.TYPE_BUILTIN_EARPIECE)
                setSpeakerPhone(executor, am, true, result)
            else if (am.communicationDevice!!.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER)
                setSpeakerPhone(executor, am, false, result)
        } else {
            @Suppress("DEPRECATION")
            setSpeakerPhone(executor, am, !am.isSpeakerphoneOn, result)
        }
    }

    fun isSpeakerPhoneOn(am: AudioManager): Boolean {
        return if (Build.VERSION.SDK_INT >= 31)
            am.communicationDevice!!.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER
        else
            @Suppress("DEPRECATION")
            am.isSpeakerphoneOn
    }

    fun isHotSpotOn(wm: WifiManager): Boolean {
        try {
            val method: Method = wm.javaClass.getDeclaredMethod("isWifiApEnabled")
            method.isAccessible = true
            return method.invoke(wm) as Boolean
        } catch (ignored: Throwable) {
        }
        return false
    }

    fun hotSpotAddresses(): Map<String, String> {
        val result = mutableMapOf<String, String>()
        try {
            val interfaces: Enumeration<NetworkInterface> = NetworkInterface.getNetworkInterfaces()
            while (interfaces.hasMoreElements()) {
                val iface: NetworkInterface = interfaces.nextElement()
                val ifName = iface.name
                Log.d(TAG, "Found interface with name $ifName")
                if (ifName.startsWith("ap") || ifName.contains("wlan")) {
                    val addresses: Enumeration<InetAddress> = iface.inetAddresses
                    while (addresses.hasMoreElements()) {
                        val inetAddress: InetAddress = addresses.nextElement()
                        if (inetAddress.isSiteLocalAddress)
                            result[inetAddress.hostAddress!!] = ifName
                    }
                    if (result.isNotEmpty()) return result
                }
            }
        } catch (ex: SocketException) {
            Log.e(TAG, "hotSpotAddresses SocketException: $ex")
        } catch (ex: NullPointerException) {
            Log.e(TAG, "hotSpotAddresses NullPointerException: $ex")
        }
        return result
    }

    fun checkIpV4(ip: String): Boolean {
        return Regex("^(([0-1]?[0-9]{1,2}\\.)|(2[0-4][0-9]\\.)|(25[0-5]\\.)){3}(([0-1]?[0-9]{1,2})|(2[0-4][0-9])|(25[0-5]))$").matches(
            ip
        )
    }
}

