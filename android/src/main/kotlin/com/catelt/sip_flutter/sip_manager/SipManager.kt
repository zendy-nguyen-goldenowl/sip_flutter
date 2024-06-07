package com.catelt.sip_flutter.sip_manager

import android.annotation.SuppressLint
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.util.Log
import androidx.annotation.Keep
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.media.AudioFocusRequestCompat
import androidx.media.AudioManagerCompat
import com.catelt.sip_flutter.SipFlutterPlugin
import com.catelt.sip_flutter.model.Config
import com.catelt.sip_flutter.model.SipCall
import com.catelt.sip_flutter.model.SipConfiguration
import com.catelt.sip_flutter.utils.*
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.net.InetAddress
import java.util.Timer
import java.util.TimerTask
import kotlin.concurrent.schedule
import kotlin.math.roundToInt


internal class SipManager private constructor(private var context: Context) {

    private var ua: Long? = null
    private var calls = mutableSetOf<SipCall>()
    private var currentCall: SipCall? = null
    private var cacheStateAccount = RegisterSipState.None
    private val handler: Handler = Handler(Looper.getMainLooper())

    private lateinit var rt: Ringtone
    private var pm: PowerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
    private lateinit var hotSpotReceiver: BroadcastReceiver
    private var am: AudioManager =
        context.getSystemService(AppCompatActivity.AUDIO_SERVICE) as AudioManager
    private var cm: ConnectivityManager =
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private var wm: WifiManager =
        context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
    private lateinit var vibrator: Vibrator
    private lateinit var wifiLock: WifiManager.WifiLock

    private var rtTimer: Timer? = null
    private var vbTimer: Timer? = null
    private var origVolume = mutableMapOf<Int, Int>()
    private var allNetworks = mutableSetOf<Network>()
    private var linkAddresses = mutableMapOf<String, String>()
    private var activeNetwork: Network? = null
    private var hotSpotIsEnabled = false
    private var hotSpotAddresses = mapOf<String, String>()
    private var mediaPlayer: MediaPlayer? = null

    init {
        val rtUri = RingtoneManager.getActualDefaultRingtoneUri(
            context.applicationContext,
            RingtoneManager.TYPE_RINGTONE
        )
        rt = RingtoneManager.getRingtone(context.applicationContext, rtUri)

        vibrator = if (Build.VERSION.SDK_INT >= 31) {
            val vibratorManager =
                context.applicationContext.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibratorManager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.applicationContext.getSystemService(AppCompatActivity.VIBRATOR_SERVICE) as Vibrator
        }

        val builder = NetworkRequest.Builder()
            .removeCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
        cm.registerNetworkCallback(
            builder.build(),
            object : ConnectivityManager.NetworkCallback() {

                override fun onAvailable(network: Network) {
                    super.onAvailable(network)
                    Log.d(TAG, "Network $network is available")
                    if (network !in allNetworks)
                        allNetworks.add(network)
                    // If API >= 26, this will be followed by onCapabilitiesChanged
                    if (isRunning && Build.VERSION.SDK_INT < 26)
                        updateNetwork()
                }

                override fun onLosing(network: Network, maxMsToLive: Int) {
                    super.onLosing(network, maxMsToLive)
                    Log.d(TAG, "Network $network is losing after $maxMsToLive ms")
                }

                override fun onLost(network: Network) {
                    super.onLost(network)
                    Log.d(TAG, "Network $network is lost")
                    if (network in allNetworks)
                        allNetworks.remove(network)
                    if (isRunning)
                        updateNetwork()
                }

                override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) {
                    super.onCapabilitiesChanged(network, caps)
                    Log.d(TAG, "Network $network capabilities changed: $caps")
                    if (network !in allNetworks)
                        allNetworks.add(network)
                    if (isRunning)
                        updateNetwork()
                }

                override fun onLinkPropertiesChanged(network: Network, props: LinkProperties) {
                    super.onLinkPropertiesChanged(network, props)
                    Log.d(TAG, "Network $network link properties changed: $props")
                    if (network !in allNetworks)
                        allNetworks.add(network)
                    if (isRunning)
                        updateNetwork()
                }

            }
        )

        hotSpotIsEnabled = Utils.isHotSpotOn(wm)

        hotSpotReceiver = object : BroadcastReceiver() {
            override fun onReceive(contxt: Context, intent: Intent) {
                val action = intent.action
                if ("android.net.wifi.WIFI_AP_STATE_CHANGED" == action) {
                    val state = intent.getIntExtra(WifiManager.EXTRA_WIFI_STATE, 0)
                    if (WifiManager.WIFI_STATE_ENABLED == state % 10) {
                        if (hotSpotIsEnabled) {
                            Log.d(TAG, "HotSpot is still enabled")
                        } else {
                            Log.d(TAG, "HotSpot is enabled")
                            hotSpotIsEnabled = true
                            Timer().schedule(1000) {
                                hotSpotAddresses = Utils.hotSpotAddresses()
                                Log.d(TAG, "HotSpot addresses $hotSpotAddresses")
                                if (hotSpotAddresses.isNotEmpty()) {
                                    var reset = false
                                    for ((k, v) in hotSpotAddresses)
                                        if (afMatch(k))
                                            if (Api.net_add_address_ifname(k, v) != 0)
                                                Log.e(TAG, "Failed to add $v address $k")
                                            else
                                                reset = true
                                    if (reset)
                                        Timer().schedule(2000) {
                                            updateNetwork()
                                        }
                                } else {
                                    Log.w(TAG, "Could not get hotspot addresses")
                                }
                            }
                        }
                    } else {
                        if (!hotSpotIsEnabled) {
                            Log.d(TAG, "HotSpot is still disabled")
                        } else {
                            Log.d(TAG, "HotSpot is disabled")
                            hotSpotIsEnabled = false
                            if (hotSpotAddresses.isNotEmpty()) {
                                for ((k, _) in hotSpotAddresses)
                                    if (Api.net_rm_address(k) != 0)
                                        Log.e(TAG, "Failed to remove address $k")
                                hotSpotAddresses = mapOf()
                                updateNetwork()
                            }
                        }
                    }
                }
            }
        }

        context.registerReceiver(
            hotSpotReceiver,
            IntentFilter("android.net.wifi.WIFI_AP_STATE_CHANGED")
        )

        wifiLock = if (Build.VERSION.SDK_INT < 29)
            @Suppress("DEPRECATION")
            wm.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "Baresip")
        else
            wm.createWifiLock(WifiManager.WIFI_MODE_FULL_LOW_LATENCY, "Baresip")

        wifiLock.setReferenceCounted(false)

        start()
    }

    private fun sendEvent(event: String, vararg params: Pair<String, Any>) {
        val data = createParams(event, *params)
        handler.post {
            SipFlutterPlugin.eventSink?.success(data)
        }
    }

    private fun sendAccountEvent(state: RegisterSipState) {
        cacheStateAccount = state
        sendEvent(SipEvent.AccountRegistrationStateChanged.name, "registrationState" to state.name)
    }

    private external fun baresipStart(path: String, addresses: String, logLevel: Int)
    private external fun baresipStop(force: Boolean)


    private fun start() {
        val filesPath = context.filesDir.absolutePath

        val assets = arrayOf("config")
        var file = File(filesPath)
        if (!file.exists()) {
            Log.i(TAG, "Creating baresip directory")
            try {
                File(filesPath).mkdirs()
            } catch (e: Error) {
                Log.e(TAG, "Failed to create directory: $e")
            }
        }
        for (a in assets) {
            file = File("${filesPath}/$a")
            if (!file.exists() && a != "config") {
                Log.i(TAG, "Copying asset '$a'")
                Utils.copyAssetToFile(context, a, "$filesPath/$a")
            } else {
                Log.i(TAG, "Asset '$a' already copied")
            }
            if (a == "config")
                Config.initialize(filesPath, context)
        }

        val logLevel = 2

        hotSpotAddresses = Utils.hotSpotAddresses()
        linkAddresses = linkAddresses()
        var addresses = ""
        for (la in linkAddresses)
            addresses = "$addresses;${la.key};${la.value}"
        Log.i(TAG, "Link addresses: $addresses")
        activeNetwork = cm.activeNetwork
        Log.i(TAG, "Active network: $activeNetwork")

        Thread {
            baresipStart(filesPath, addresses.removePrefix(";"), logLevel)
        }.start()

        isRunning = true
    }

    private fun closed() {
        baresipStop(force = false)
    }

    fun initSipModule(sipConfiguration: SipConfiguration) {
        if (ua != null) {
            unregister()
        }
        initSipAccount(sipConfiguration)
    }

    private fun initSipAccount(sipConfiguration: SipConfiguration) {
        val username = sipConfiguration.username
        val domain = sipConfiguration.domain
        val password = sipConfiguration.password
        val expires = sipConfiguration.expires ?: 900

        val addr =
            "<sip:$username@$domain>;auth_pass=$password;stunserver=\"stun:stun.l.google.com:19302\";regq=0.5;pubint=0;regint=$expires"

        // Start user agent.
        val uap = Api.ua_alloc(addr)
        if (uap == 0L) {
            Log.e(TAG, "ua_alloc() fail")
            return
        }
        ua = uap

        val accp = Api.ua_account(uap)
        val audioCodecs = Api.audio_codecs()

        if (Api.account_set_audio_codecs(accp, audioCodecs) != 0) {
            Log.e(TAG, "account_set_audio_codecs() fail")
            return
        }

        updateNetwork()

        registry()
    }

    private fun registry() {
        ua?.let {
            if (Api.ua_register(it) != 0) {
                Log.e(TAG, "ua_register() fail")
                return
            }
        }
    }

    private fun unregister() {
        ua?.let {
            Api.ua_unregister(it)
            ua = null
        }
    }

    fun call(recipient: String, result: Result) {
        ua?.let {
            val callp = Api.ua_call_alloc(it, 0L, Api.VIDMODE_OFF)
            val remoteAddress = "sip:$recipient"
            if (callp != 0L) {
                val call = SipCall(callp, it, remoteAddress)
                calls.add(call)
                val response = call.connect()
                if (response) {
                    currentCall = call
                } else {
                    calls.remove(call)
                }
                result.success(response)
                return
            }
            result.success(false)
        }
    }

    fun answer(result: Result) {
        if (currentCall == null) {
            Log.d(TAG, "Current call not found")
            return result.success(false)
        }
        stopRinging()
        stopMediaPlayer()
        setCallVolume()
        currentCall?.answer()
        Log.d(TAG, "Answer successful")
        result.success(true)
    }

    fun hangup(result: Result) {
        if (currentCall == null) {
            Log.d(TAG, "Current call not found")
            return result.success(false)
        }
        currentCall?.hangup(code = 487, reason = "Request Terminated")
        Log.d(TAG, "Hangup successful")
        result.success(true)
    }

    fun reject(result: Result) {
        if (currentCall == null) {
            Log.d(TAG, "Current call not found")
            return result.success(false)
        }
        currentCall?.hangup(code = 500, reason = "Busy Now")
        Log.d(TAG, "Reject successful")
        result.success(true)
    }

    fun pause(result: Result) {
        if (currentCall == null) {
            Log.d(TAG, "Current call not found")
            return result.success(false)
        }
        currentCall?.hold()
        Log.d(TAG, "Pause successful")
        result.success(true)
    }

    fun resume(result: Result) {
        if (currentCall == null) {
            Log.d(TAG, "Current call not found")
            return result.success(false)
        }
        currentCall?.resume()
        Log.d(TAG, "Resume successful")
        result.success(true)
    }

    fun setSpeaker(enable: Boolean, result: Result) {
        Utils.setSpeakerPhone(ContextCompat.getMainExecutor(context), am, enable){}
        result.success(true)
    }

    fun toggleSpeaker(result: Result) {
        Utils.toggleSpeakerPhone(ContextCompat.getMainExecutor(context), am) {
            result.success(it)
        }
    }

    fun toggleMic(result: Result) {
        if (currentCall == null) {
            return result.error("404", "Current call not found", null)
        }
        val isMicMuted = currentCall!!.isMicMuted()
        Api.calls_mute(!isMicMuted)
        result.success(!(currentCall!!.isMicMuted()))
    }

    fun refreshSipAccount(result: Result) {
        if (ua != null && cacheStateAccount != RegisterSipState.Ok) {
            registry()
        }
    }

    fun unregisterSipAccount(result: Result) {
        if (ua == null) {
            Log.d(TAG, "Sip account not found")
            return result.success(false)
        }
        unregister()
        result.success(true)
    }

    fun getSipRegistrationState(result: Result) {
        result.success(cacheStateAccount.name)
    }

    fun isMicEnabled(result: Result) {
        if (currentCall == null) {
            return result.success(false)
        }
        val isMicMuted = currentCall!!.isMicMuted()
        result.success(!isMicMuted)
    }

    fun isSpeakerEnabled(result: Result) {
        result.success(Utils.isSpeakerPhoneOn(am))
    }

    private fun createParams(event: String, vararg params: Pair<String, Any>): Map<String, Any> {
        return mapOf("event" to event, "body" to params.toMap())
    }

    @SuppressLint("UnspecifiedImmutableFlag", "DiscouragedApi")
    @Keep
    fun uaEvent(event: String, uap: Long, callp: Long) {
        if (!isRunning) return
        val ev = event.split(",")

        if (callp != 0L) {
            if (ua == null) return

            val sipCall = getSipCall(callp, ev.last())
            currentCall = sipCall
            when (ev[0]) {
                "call incoming" -> {
                    startRinging()
                    sendEvent(
                        SipEvent.Ring.name,
                        "username" to sipCall.dir,
                        "callType" to CallType.inbound.name
                    )
                    return
                }

                "call outgoing" -> {
                    sendEvent(
                        SipEvent.Ring.name,
                        "username" to sipCall.dir,
                        "callType" to CallType.outbound.name
                    )
                    return
                }

                "call ringing" -> {
                    playRingBack()
                    return
                }

                "call progress" -> {
                    if ((ev[1].toInt() and Api.SDP_RECVONLY) != 0)
                        stopMediaPlayer()
                    else
                        playRingBack()
                    return
                }

                "call update" -> {
                    when (ev[1]) {
                        "1" -> {
                            sendEvent(SipEvent.Paused.name)
                        }

                        "3" -> {
                            sendEvent(SipEvent.Resuming.name)
                        }
                    }
                    return
                }

                "call established" -> {
                    sendEvent(SipEvent.Up.name)
                    return
                }

                "call closed" -> {
                    sendEvent(SipEvent.Hangup.name)
                    calls.remove(sipCall)
                    if (currentCall != null) {
                        stopRinging()
                        stopMediaPlayer()
                        val tone = ev[2]
                        if (tone == "busy") {
                            playBusy()
                        } else if (currentCall != null) {
                            resetCallVolume()
                            abandonAudioFocus(context.applicationContext)
                        }
                        currentCall = null
                    }
                    return
                }
            }
        } else {
            when (ev[0]) {
                "registering", "unregistering" -> {
                    sendAccountEvent(RegisterSipState.Progress)
                    return
                }

                "registered" -> {
                    if (ua != null) {
                        sendAccountEvent(RegisterSipState.Ok)
                    } else {
                        sendAccountEvent(RegisterSipState.None)
                    }
                    return
                }

                "registering failed" -> {
                    sendAccountEvent(RegisterSipState.Failed)
                    return
                }
            }
        }
    }

    @Keep
    fun started() {
        Log.d(TAG, "Received 'started' from baresip")
        Api.net_debug()
    }

    @Keep
    fun stopped(error: String) {
        Log.d(TAG, "Received 'stopped' from baresip with start error '$error'")
        closed()
        isRunning = false
        context.unregisterReceiver(hotSpotReceiver)
        stopRinging()
        stopMediaPlayer()
        abandonAudioFocus(context.applicationContext)
        if (this::wifiLock.isInitialized)
            wifiLock.release()
    }


    /// ---------------------------------------------
    /// Network

    private fun updateNetwork() {

        updateDnsServers()

        val addresses = linkAddresses()

        Log.d(TAG, "Old/new link addresses $linkAddresses/$addresses")

        var added = 0
        for (a in addresses)
            if (!linkAddresses.containsKey(a.key)) {
                if (Api.net_add_address_ifname(a.key, a.value) != 0)
                    Log.e(TAG, "Failed to add address: $a")
                else
                    added++
            }
        var removed = 0
        for (a in linkAddresses)
            if (!addresses.containsKey(a.key)) {
                if (Api.net_rm_address(a.key) != 0)
                    Log.e(TAG, "Failed to remove address: $a")
                else
                    removed++
            }

        val active = cm.activeNetwork
        Log.d(TAG, "Added/Removed/Old/New Active = $added/$removed/$activeNetwork/$active")

        if (added > 0 || removed > 0 || active != activeNetwork) {
            linkAddresses = addresses
            activeNetwork = active
            Api.uag_reset_transp(register = true, reinvite = true)
        }

        Api.net_debug()

        if (activeNetwork != null) {
            val caps = cm.getNetworkCapabilities(activeNetwork)
            if (caps != null && caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
                Log.d(TAG, "Acquiring WiFi Lock")
                wifiLock.acquire()
                return
            }
        }
        Log.d(TAG, "Releasing WiFi Lock")
        wifiLock.release()
    }

    private fun linkAddresses(): MutableMap<String, String> {
        val addresses = mutableMapOf<String, String>()
        for (n in allNetworks) {
            val caps = cm.getNetworkCapabilities(n) ?: continue
            if (Build.VERSION.SDK_INT < 28 ||
                caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_FOREGROUND)
            ) {
                val props = cm.getLinkProperties(n) ?: continue
                for (la in props.linkAddresses)
                    if (la.scope == android.system.OsConstants.RT_SCOPE_UNIVERSE &&
                        props.interfaceName != null && la.address.hostAddress != null &&
                        afMatch(la.address.hostAddress!!)
                    )
                        addresses[la.address.hostAddress!!] = props.interfaceName!!
            }
        }
        if (hotSpotIsEnabled) {
            for ((k, v) in hotSpotAddresses)
                if (afMatch(k))
                    addresses[k] = v
        }
        return addresses
    }


    private fun afMatch(address: String): Boolean {
        return when (addressFamily) {
            "" -> true
            "ipv4" -> address.contains(".")
            else -> address.contains(":")
        }
    }

    private fun updateDnsServers() {
        if (isRunning && !dynDns)
            return
        val servers = mutableListOf<InetAddress>()
        // Use DNS servers first from active network (if available)
        val activeNetwork = cm.activeNetwork
        if (activeNetwork != null) {
            val linkProps = cm.getLinkProperties(activeNetwork)
            if (linkProps != null)
                servers.addAll(linkProps.dnsServers)
        }
        // Then add DNS servers from the other networks
        for (n in allNetworks) {
            if (n == cm.activeNetwork) continue
            val linkProps = cm.getLinkProperties(n)
            if (linkProps != null)
                for (server in linkProps.dnsServers)
                    if (!servers.contains(server)) servers.add(server)
        }
        // Update if change
        if (servers != dnsServers) {
            if (isRunning && Config.updateDnsServers(servers) != 0) {
                Log.w(TAG, "Failed to update DNS servers '${servers}'")
            } else {
                dnsServers = servers
            }
        }
    }

    /// ---------------------------------------------
    /// Network end

    /// ---------------------------------------------
    /// Media

    private fun startRinging() {
        if (Build.VERSION.SDK_INT >= 28) {
            rt.isLooping = true
            rt.play()
        } else {
            rt.play()
            rtTimer = Timer()
            rtTimer!!.schedule(object : TimerTask() {
                override fun run() {
                    if (!rt.isPlaying)
                        rt.play()
                }
            }, 1000, 1000)
        }
        if (shouldVibrate()) {
            vbTimer = Timer()
            vbTimer!!.schedule(object : TimerTask() {
                override fun run() {
                    if (Build.VERSION.SDK_INT < 26) {
                        @Suppress("DEPRECATION")
                        vibrator.vibrate(500)
                    } else {
                        vibrator.vibrate(
                            VibrationEffect.createOneShot(
                                500,
                                VibrationEffect.DEFAULT_AMPLITUDE
                            )
                        )
                    }
                }
            }, 500L, 2000L)
        }
    }

    private fun shouldVibrate(): Boolean {
        return if (am.ringerMode != AudioManager.RINGER_MODE_SILENT) {
            if (am.ringerMode == AudioManager.RINGER_MODE_VIBRATE) {
                true
            } else {
                if (am.getStreamVolume(AudioManager.STREAM_RING) != 0) {
                    @Suppress("DEPRECATION")
                    Settings.System.getInt(
                        context.contentResolver,
                        Settings.System.VIBRATE_WHEN_RINGING,
                        0
                    ) == 1
                } else {
                    false
                }
            }
        } else {
            false
        }
    }


    private fun stopRinging() {
        if (Build.VERSION.SDK_INT < 28 && rtTimer != null) {
            rtTimer!!.cancel()
            rtTimer = null
        }
        rt.stop()
        if (vbTimer != null) {
            vbTimer!!.cancel()
            vbTimer = null
        }
    }

    @SuppressLint("DiscouragedApi")
    private fun playRingBack() {
        if (mediaPlayer == null) {
            val name = "ringback_$toneCountry"
            val resourceId = context.applicationContext.resources.getIdentifier(
                name,
                "raw",
                context.applicationContext.packageName
            )
            if (resourceId != 0) {
                mediaPlayer = MediaPlayer.create(context, resourceId)
                mediaPlayer?.isLooping = true
                mediaPlayer?.start()
            } else {
                Log.e(TAG, "Ringback tone $name.wav not found")
            }
        }
    }

    @SuppressLint("DiscouragedApi")
    private fun playBusy() {
        if (mediaPlayer == null) {
            val name = "busy_$toneCountry"
            val resourceId = context.applicationContext.resources.getIdentifier(
                name,
                "raw",
                context.applicationContext.packageName
            )
            if (resourceId != 0) {
                mediaPlayer = MediaPlayer.create(context, resourceId)
                mediaPlayer?.setOnCompletionListener {
                    stopMediaPlayer()
                    if (currentCall == null) {
                        resetCallVolume()
                        abandonAudioFocus(context.applicationContext)
                    }
                }
                mediaPlayer?.start()
            } else {
                Log.e(TAG, "Busy tone $name.wav not found")
            }
        }
    }

    private fun stopMediaPlayer() {
        mediaPlayer?.stop()
        mediaPlayer?.release()
        mediaPlayer = null
    }

    private fun setCallVolume() {
        if (callVolume != 0)
            for (streamType in listOf(AudioManager.STREAM_MUSIC, AudioManager.STREAM_VOICE_CALL)) {
                origVolume[streamType] = am.getStreamVolume(streamType)
                val maxVolume = am.getStreamMaxVolume(streamType)
                am.setStreamVolume(streamType, (callVolume * 0.1 * maxVolume).roundToInt(), 0)
                Log.d(
                    TAG, "Orig/new/max $streamType volume is " +
                            "${origVolume[streamType]}/${am.getStreamVolume(streamType)}/$maxVolume"
                )
            }
    }

    private fun resetCallVolume() {
        if (callVolume != 0)
            for ((streamType, streamVolume) in origVolume) {
                am.setStreamVolume(streamType, streamVolume, 0)
                Log.d(TAG, "Reset $streamType volume to ${am.getStreamVolume(streamType)}")
            }
    }

    /// Stop Media
    /// ---------------------------------

    private fun getSipCall(callp: Long, remoteUri: String): SipCall {
        val idCalls: List<Long> = calls.map {
            it.callp
        }.toList()
        val index = idCalls.indexOf(callp)
        if (index >= 0) {
            return calls.elementAt(index)

        } else {
            val sipCall = SipCall(callp, ua ?: 0, remoteUri)
            calls.plus(sipCall)
            return sipCall
        }
    }

    companion object {
        private const val TAG = "SipManager"
        private var INSTANCE: SipManager? = null
        var isRunning = false
        var addressFamily = ""
        var dnsServers = listOf<InetAddress>()
        var dynDns = false

        var audioDelay = if (Build.VERSION.SDK_INT < 31) 1500L else 500L
        var toneCountry = "us"
        var callVolume = 0

        private var audioFocusRequest: AudioFocusRequestCompat? = null

        fun abandonAudioFocus(ctx: Context) {
            val am = ctx.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            if (audioFocusRequest != null) {
                Log.d(TAG, "Abandoning audio focus")
                if (AudioManagerCompat.abandonAudioFocusRequest(am, audioFocusRequest!!) ==
                    AudioManager.AUDIOFOCUS_REQUEST_GRANTED
                ) {
                    audioFocusRequest = null
                } else {
                    Log.e(TAG, "Failed to abandon audio focus")
                }
            }
            am.mode = AudioManager.MODE_NORMAL
        }

        fun getInstance(context: Context): SipManager {
            return INSTANCE ?: synchronized(SipManager::class.java) {
                INSTANCE ?: SipManager(context).also {
                    INSTANCE = it
                }
            }
        }
    }
}