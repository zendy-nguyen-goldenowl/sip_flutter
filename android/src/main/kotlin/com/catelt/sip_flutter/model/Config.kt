package com.catelt.sip_flutter.model

import android.content.Context
import android.util.Log
import com.catelt.sip_flutter.sip_manager.Api
import com.catelt.sip_flutter.sip_manager.SipManager
import com.catelt.sip_flutter.utils.TAG
import com.catelt.sip_flutter.utils.Utils
import java.io.File
import java.net.InetAddress
import java.nio.charset.StandardCharsets

object Config {

    private lateinit var config: String
    private lateinit var previousConfig: String
    private lateinit var previousLines: List<String>
    private val audioModules = listOf("opus", "amr", "g722", "g7221", "g726", "g729", "codec2", "g711")

    fun initialize(path: String,ctx: Context) {
        val configPath = "$path/config"

        config = ctx.assets.open("config.static").bufferedReader().use { it.readText() }
        if (!File(configPath).exists()) {
            for (module in audioModules)
                config = "${config}module ${module}.so\n"
            config = "${config}module webrtc_aecm.so\n"
            previousConfig = config
        } else {
            previousConfig = String(Utils.getFileContents(configPath)!!, StandardCharsets.ISO_8859_1)
        }
        previousLines = previousConfig.split("\n")

        val logLevel = previousVariable("log_level")
        if (logLevel == "") {
            config = "${config}log_level 2\n"
        } else {
            config = "${config}log_level $logLevel\n"
        }

        val autoStart = previousVariable("auto_start")
        config = if (autoStart != "")
            "${config}auto_start $autoStart\n"
        else
            "${config}auto_start no\n"

        val sipListen = previousVariable("sip_listen")
        if (sipListen != "")
            config = "${config}sip_listen $sipListen\n"

        val addressFamily = previousVariable("net_af")
        if (addressFamily != "") {
            config = "${config}net_af $addressFamily\n"
            SipManager.addressFamily = addressFamily
        }

        val sipCertificate = previousVariable("sip_certificate")
        if (sipCertificate != "")
            config = "${config}sip_certificate $sipCertificate\n"

        val sipVerifyServer = previousVariable("sip_verify_server")
        if (sipVerifyServer != "")
            config = "${config}sip_verify_server $sipVerifyServer\n"

        val caBundlePath = "${path}/ca_bundle.crt"
        val caBundleFile = File(caBundlePath)
        val caFilePath = "${path}/ca_certs.crt"
        val caFile = File(caFilePath)
        if (caFile.exists())
            caFile.copyTo(caBundleFile, true)
        else
            caBundleFile.writeBytes(byteArrayOf())
        Log.d(TAG, "Size of caFile = ${caBundleFile.length()}")
        val cacertsPath = "/system/etc/security/cacerts"
        val cacertsDir = File(cacertsPath)
        var caCount = 0
        if (cacertsDir.exists()) {
            cacertsDir.walk().forEach {
                if (it.isFile) {
                    caBundleFile.appendBytes(
                        it.readBytes()
                            .toString(Charsets.UTF_8)
                            .substringBefore("Certificate:")
                            .toByteArray(Charsets.UTF_8)
                    )
                    caCount++
                }
            }
            Log.d(TAG, "Added $caCount ca certificates from $cacertsPath")
        } else {
            Log.w(TAG, "Directory $cacertsDir does not exist!")
        }
        Log.d(TAG, "Size of caBundleFile = ${caBundleFile.length()}")
        config = "${config}sip_cafile $caBundlePath\n"

        val dynamicDns = previousVariable("dyn_dns")
        if (dynamicDns == "no") {
            config = "${config}dyn_dns no\n"
            for (server in previousVariables("dns_server"))
                config = "${config}dns_server $server\n"
        } else {
            config = "${config}dyn_dns yes\n"
            for (dnsServer in SipManager.dnsServers)
                config = if (Utils.checkIpV4(dnsServer.hostAddress!!))
                    "${config}dns_server ${dnsServer.hostAddress}:53\n"
                else
                    "${config}dns_server [${dnsServer.hostAddress}]:53\n"
            SipManager.dynDns = true
        }

        val callVolume = previousVariable("call_volume")
        if (callVolume != "") {
            config = "${config}call_volume $callVolume\n"
            SipManager.callVolume = callVolume.toInt()
        } else {
            config = "${config}call_volume ${SipManager.callVolume}\n"
        }

        val previousModules = previousVariables("module")
        for (module in audioModules)
            if ("${module}.so" in previousModules)
                config = "${config}module ${module}.so\n"

        if ("webrtc_aecm.so" in previousModules)
            config = "${config}module webrtc_aecm.so\n"

        val opusBitRate = previousVariable("opus_bitrate")
        config = if (opusBitRate == "")
            "${config}opus_bitrate 28000\n"
        else
            "${config}opus_bitrate $opusBitRate\n"

        val opusPacketLoss = previousVariable("opus_packet_loss")
        config = if (opusPacketLoss == "")
            "${config}opus_packet_loss 1\n"
        else
            "${config}opus_packet_loss $opusPacketLoss\n"

        val audioDelay = previousVariable("audio_delay")
        if (audioDelay != "") {
            config = "${config}audio_delay $audioDelay\n"
            SipManager.audioDelay = audioDelay.toLong()
        } else {
            config = "${config}audio_delay ${SipManager.audioDelay}\n"
        }

        val toneCountry = previousVariable("tone_country")
        if (toneCountry != "")
            SipManager.toneCountry = toneCountry
        config = "${config}tone_country ${SipManager.toneCountry}\n"

        save(configPath)
    }

    private fun previousVariable(name: String): String {
        for (line in previousLines) {
            val nameValue = line.split(" ")
            if (nameValue.size == 2 && nameValue[0] == name)
                return nameValue[1].trim()
        }
        return ""
    }

    private fun previousVariables(name: String): ArrayList<String> {
        val result = ArrayList<String>()
        for (line in previousLines) {
            val nameValue = line.split(" ")
            if (nameValue.size == 2 && nameValue[0] == name)
                result.add(nameValue[1].trim())
        }
        return result
    }

    fun updateDnsServers(dnsServers: List<InetAddress>): Int {
        var servers = ""
        for (dnsServer in dnsServers) {
            if (dnsServer.hostAddress == null) continue
            var address = dnsServer.hostAddress!!.removePrefix("/")
            address = if (Utils.checkIpV4(address))
                "${address}:53"
            else
                "[${address}]:53"
            servers = if (servers == "")
                address
            else
                "${servers},${address}"
        }
        return Api.net_use_nameserver(servers)
    }


    fun save(configPath: String) {
        Utils.putFileContents(configPath, config.toByteArray())
        Log.d(TAG, "Saved new config '$config'")
    }
}
