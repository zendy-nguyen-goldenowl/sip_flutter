package com.catelt.sip_flutter.model

import com.catelt.sip_flutter.sip_manager.Api
import com.catelt.sip_flutter.sip_manager.Api.VIDMODE_OFF

class SipCall( val callp: Long,  val ua: Long,  val dir: String) {

    fun connect(): Boolean {
        return Api.call_connect(callp, dir) == 0
    }

    fun answer() {
        Api.ua_answer(ua, callp,VIDMODE_OFF)
    }

    fun hangup(code: Int?, reason: String?) {
       Api.ua_hangup(ua, callp, code ?: 486, reason ?: "Busy Here")
    }

    fun hold(): Boolean {
        return Api.call_hold(callp, true) == 0
    }

    fun resume(): Boolean {
        return Api.call_hold(callp, false) == 0
    }

    fun isMicMuted(): Boolean {
        return Api.call_ismuted(callp)
    }
}
