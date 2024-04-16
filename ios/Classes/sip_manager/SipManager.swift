import Foundation
import linphonesw

class SipManager {
    
    static let instance = SipManager()
    var mCore: Core!
    private var timeStartStreamingRunning: Int64 = 0
    private var isPause: Bool = false
    private var coreDelegate : CoreDelegate!
    
    private init() {
        do {
            try mCore = Factory.Instance.createCore(configPath: "", factoryConfigPath: "", systemContext: nil)
            mCore.keepAliveEnabled = true
            mCore.pushNotificationEnabled = true
            try mCore.start()
            coreDelegate = CoreDelegateStub(
                onCallStateChanged: {(
                    core: Core,
                    call: Call,
                    state: Call.State?,
                    message: String
                ) in
                    switch (state) {
                    case .IncomingReceived:
                        // Immediately hang up when we receive a call. There's nothing inherently wrong with this
                        // but we don't need it right now, so better to leave it deactivated.
                        // try! call.terminate()
                        NSLog("IncomingReceived")
                        let username = core.defaultAccount?.contactAddress?.username ?? ""
                        let phoneNumber = call.remoteAddress?.username ?? ""
                        self.sendEvent(eventName: EventRing, body: ["username": username, "phoneNumber": phoneNumber, "callType": CallType.inbound.rawValue])
                        break
                    case .OutgoingInit:
                        // First state an outgoing call will go through
                        NSLog("OutgoingInit")
                        break
                    case .OutgoingProgress:
                        // First state an outgoing call will go through
                        NSLog("OutgoingProgress")
                        
                        let username = core.defaultAccount?.contactAddress?.username ?? ""
                        let phoneNumber = call.remoteAddress?.username ?? ""
                        self.sendEvent(eventName: EventRing, body: ["username": username, "phoneNumber": phoneNumber, "callType": CallType.outbound.rawValue])
                        break
                    case .OutgoingRinging:
                        // Once remote accepts, ringing will commence (180 response)
                        NSLog("OutgoingRinging")
                        break
                    case .Connected:
                        NSLog("Connected")
                        break
                    case .StreamsRunning:
                        // This state indicates the call is active.
                        // You may reach this state multiple times, for example after a pause/resume
                        // or after the ICE negotiation completes
                        // Wait for the call to be connected before allowing a call update
                        NSLog("StreamsRunning")
                        if(!self.isPause) {
                            self.timeStartStreamingRunning = Int64(Date().timeIntervalSince1970 * 1000)
                        }
                        self.isPause = false
                        let callId = call.callLog?.callId ?? ""
                        self.sendEvent(eventName: EventUp, body: ["callId": callId])
                        break
                    case .Paused:
                        NSLog("Paused")
                        self.isPause = true
                        self.sendEvent(eventName: EventPaused, body: nil)
                        break
                    case .Resuming:
                        NSLog("Resuming")
                        self.sendEvent(eventName: EventResuming, body: nil)
                        break
                    case .PausedByRemote:
                        NSLog("PausedByRemote")
                        break
                    case .Updating:
                        // When we request a call update, for example when toggling video
                        NSLog("Updating")
                        break
                    case .UpdatedByRemote:
                        // When the remote requests a call update
                        NSLog("UpdatedByRemote")
                        break
                    case .Released:
                        // Call state will be released shortly after the End state
                        if(self.isMissed(callLog: call.callLog)) {
                            NSLog("Missed")
                            let callee = call.remoteAddress?.username ?? ""
                            let totalMissed = core.missedCallsCount
                            self.sendEvent(eventName: EventMissed, body: ["phoneNumber": callee, "totalMissed": totalMissed])
                        } else {
                            NSLog("Released")
                        }
                        break
                    case .End:
                        NSLog("End")
                        let duration = self.timeStartStreamingRunning == 0 ? 0 : Int64(Date().timeIntervalSince1970 * 1000) - self.timeStartStreamingRunning
                        self.sendEvent(eventName: EventHangup, body: ["duration": duration])
                        self.timeStartStreamingRunning = 0
                        break
                    case .Error:
                        NSLog("Error")
                        self.sendEvent(eventName: EventError, body: ["message": message])
                        break
                    default:
                        break
                    }
                },
                onAccountRegistrationStateChanged: { (core: Core, account: Account, state: RegistrationState, message: String) in
                    self.sendEvent(eventName: EventAccountRegistrationStateChanged, body: ["registrationState": RegisterSipState.allCases[state.rawValue].rawValue, "message": message])
                }
            )
            
            mCore.addDelegate(delegate: coreDelegate)
        } catch {
            NSLog(error.localizedDescription)
        }
    }
    
    private func createParams(eventName: String, body: [String: Any]?) -> [String:Any] {
        if body == nil {
            return [
                "event": eventName
            ] as [String: Any]
        } else {
            return [
                "event": eventName,
                "body": body!
            ] as [String: Any]
        }
    }
    
    private func sendEvent(eventName: String, body: [String: Any]?) {
        let data = createParams(eventName: eventName, body: body)
        SwiftSipFlutterPlugin.eventSink?(data)
    }
    
    public func initSipModule(sipConfiguration: SipConfiguration) {
        do {
            if(mCore.defaultAccount != nil){
                deleteSipAccount()
            }
            initSipAccount(sipConfiguration: sipConfiguration)
        } catch {
            NSLog(error.localizedDescription)
        }
    }
    
    private func initSipAccount(sipConfiguration: SipConfiguration) {
        do {
            let username = sipConfiguration.username
            let password = sipConfiguration.password
            let domain = sipConfiguration.domain
            let expires = sipConfiguration.expires
            // To configure a SIP account, we need an Account object and an AuthInfo object
            // The first one is how to connect to the proxy server, the second one stores the credentials
            
            // The auth info can be created from the Factory as it's only a data class
            // userID is set to null as it's the same as the username in our case
            // ha1 is set to null as we are using the clear text password. Upon first register, the hash will be computed automatically.
            // The realm will be determined automatically from the first register, as well as the algorithm
            let authInfo = try Factory.Instance.createAuthInfo(username: username, userid: "", passwd: password, ha1: "", realm: "", domain: domain)
            // Account object replaces deprecated ProxyConfig object
            // Account object is configured through an AccountParams object that we can obtain from the Core
            let accountParams = try mCore.createAccountParams()
            
            // A SIP account is identified by an identity address that we can construct from the username and domain
            let identity = try Factory.Instance.createAddress(addr: String("sip:" + username + "@" + domain))
            try! accountParams.setIdentityaddress(newValue: identity)
            
            // We also need to configure where the proxy server is located
            let address = try Factory.Instance.createAddress(addr: String("sip:" + domain))
            
            // We use the Address object to easily set the transport protocol
            try address.setTransport(newValue: TransportType.Tcp)
            // try address.setPort(newValue: port)
            try accountParams.setServeraddress(newValue: address)
            // And we ensure the account will start the registration process
            accountParams.registerEnabled = true
            
            // Set the provider to the development apple push notification servers, not the production ones.
            // Make sure your flexisip server has a matching certificate to send the pushes
             accountParams.pushNotificationConfig?.provider = "apns.dev"
            
            // We use remote notifications in this tutorials, not VOIP ones
             accountParams.pushNotificationAllowed = false
             accountParams.remotePushNotificationAllowed = true
        
            // Set up Session Timers
            if(expires != nil){
                accountParams.expires = expires!
            }
            
            // Now that our AccountParams is configured, we can create the Account object
            let account = try mCore.createAccount(params: accountParams)
            
            // Now let's add our objects to the Core
            mCore.addAuthInfo(info: authInfo)
            try mCore.addAccount(account: account)
            
            // Also set the newly added account as default
            mCore.defaultAccount = account
        } catch {
            NSLog(error.localizedDescription)
        }
    }
    
    func call(recipient: String, result: FlutterResult) {
        NSLog("Try to call")
        do {
            // As for everything we need to get the SIP URI of the remote and convert it sto an Address
            let sipUri = String("sip:" + recipient)
            let remoteAddress = try Factory.Instance.createAddress(addr: sipUri)
            
            // We also need a CallParams object
            // Create call params expects a Call object for incoming calls, but for outgoing we must use null safely
            let params = try mCore.createCallParams(call: nil)
            
            // We can now configure it
            // Here we ask for no encryption but we could ask for ZRTP/SRTP/DTLS
            params.mediaEncryption = MediaEncryption.None
            
            // If we wanted to start the call with video directly
            //params.videoEnabled = true
            
            // Finally we start the call
            let _ = mCore.inviteAddressWithParams(addr: remoteAddress, params: params)
            NSLog("Call successful")
            result(true)
        } catch {
            NSLog(error.localizedDescription)
            result(FlutterError(code: "500", message: error.localizedDescription, details: nil))
        }
    }
    
    func answer(result: FlutterResult) {
        NSLog("Try to answer")
        do {
            let coreCall = mCore.currentCall
            if(coreCall == nil) {
                NSLog("Current call not found")
                return result(false)
            }
            try coreCall!.accept()
            NSLog("Answer successful")
            result(true)
        } catch {
            NSLog(error.localizedDescription)
            result(FlutterError(code: "500", message: error.localizedDescription, details: nil))
        }
    }
    
    func hangup(result: FlutterResult) {
        NSLog("Try to hangup")
        do {
            if (mCore.callsNb == 0) {
                NSLog("Current call not found")
                return result(false)
            }
            
            // If the call state isn't paused, we can get it using core.currentCall
            let coreCall = (mCore.currentCall != nil) ? mCore.currentCall : mCore.calls[0]
            if(coreCall == nil) {
                NSLog("Current call not found")
                return result(false)
            }

            // Terminating a call is quite simple
            try coreCall!.terminate()
            NSLog("Hangup successful")
            result(true)
        } catch {
            NSLog(error.localizedDescription)
            result(FlutterError(code: "500", message: error.localizedDescription, details: nil))
        }
    }
    
    func reject(result: FlutterResult) {
        NSLog("Try to reject")
        do {
            let coreCall = mCore.currentCall
            if(coreCall == nil) {
                NSLog("Current call not found")
                return result(false)
            }
            
            // Reject a call
            // try coreCall!.decline(reason: Reason.Forbidden)
            try coreCall!.terminate()
            NSLog("Reject successful")
            result(true)
        } catch {
            NSLog(error.localizedDescription)
            result(FlutterError(code: "500", message: error.localizedDescription, details: nil))
        }
    }
    
    func pause(result: FlutterResult) {
        NSLog("Try to pause")
        do {
            if (mCore.callsNb == 0) {
                NSLog("Current call not found")
                return result(false)
            }
            
            let coreCall = (mCore.currentCall != nil) ? mCore.currentCall : mCore.calls[0]
            
            if(coreCall == nil) {
                NSLog("Current call not found")
                return result(false)
            }
            
            // Pause a call
            try coreCall!.pause()
            NSLog("Pause successful")
            result(true)
        } catch {
            NSLog(error.localizedDescription)
            result(FlutterError(code: "500", message: error.localizedDescription, details: nil))
        }
    }
    
    func resume(result: FlutterResult) {
        NSLog("Try to resume")
        do {
            if (mCore.callsNb == 0) {
                NSLog("Current call not found")
                return result(false)
            }
            
            let coreCall = (mCore.currentCall != nil) ? mCore.currentCall : mCore.calls[0]
            
            if(coreCall == nil) {
                NSLog("Current call not found")
                result(false)
            }
            
            // Resume a call
            try coreCall!.resume()
            NSLog("Resume successful")
            result(true)
        } catch {
            NSLog(error.localizedDescription)
            result(FlutterError(code: "500", message: error.localizedDescription, details: nil))
        }
    }
    
    func transfer(recipient: String, result: FlutterResult) {
        NSLog("Try to transfer")
        do {
            if (mCore.callsNb == 0) { return }
            
            let coreCall = (mCore.currentCall != nil) ? mCore.currentCall : mCore.calls[0]
            
            let domain: String? = mCore.defaultAccount?.params?.domain
            
            if (domain == nil) {
                NSLog("Can't create sip uri")
                return result(false)
            }
            
            let address = mCore.interpretUrl(url: String("sip:\(recipient)@\(domain!)"))
            if(address == nil) {
                NSLog("Can't create address")
                return result(false)
            }
            
            if(coreCall == nil) {
                NSLog("Current call not found")
                result(false)
            }
            
            // Transfer a call
            try coreCall!.transferTo(referTo: address!)
            NSLog("Transfer successful")
            result(true)
        } catch {
            NSLog(error.localizedDescription)
            result(FlutterError(code: "500", message: error.localizedDescription, details: nil))
        }
    }
    
    func sendDTMF(dtmf: String, result: FlutterResult) {
        do {
            let coreCall = mCore.currentCall
            if(coreCall == nil) {
                NSLog("Current call not found")
                return result(false)
            }
            
            // Send IVR
            try coreCall!.sendDtmf(dtmf: dtmf.utf8CString[0])
            NSLog("Send DTMF successful")
            result(true)
        } catch {
            NSLog(error.localizedDescription)
            result(FlutterError(code: "500", message: error.localizedDescription, details: nil))
        }
    }
    
    func toggleSpeaker(result: FlutterResult) {
        let coreCall = mCore.currentCall
        if(coreCall == nil) {
            return result(FlutterError(code: "404", message: "Current call not found", details: nil))
        }
        let currentAudioDevice = coreCall!.outputAudioDevice
        let speakerEnabled = currentAudioDevice?.type == AudioDevice.Kind.Speaker
        
        // We can get a list of all available audio devices using
        // Note that on tablets for example, there may be no Earpiece device
        for audioDevice in mCore.audioDevices {
            // For IOS, the Speaker is an exception, Linphone cannot differentiate Input and Output.
            // This means that the default output device, the earpiece, is paired with the default phone microphone.
            // Setting the output audio device to the microphone will redirect the sound to the earpiece.
            if (speakerEnabled && audioDevice.type == AudioDevice.Kind.Microphone) {
                coreCall!.outputAudioDevice = audioDevice
                return result(false)
            } else if (!speakerEnabled && audioDevice.type == AudioDevice.Kind.Speaker) {
                coreCall!.outputAudioDevice = audioDevice
                return result(true)
            }
            /* If we wanted to route the audio to a bluetooth headset
             else if (audioDevice.type == AudioDevice.Type.Bluetooth) {
             core.currentCall?.outputAudioDevice = audioDevice
             }*/
        }
    }
    
    func toggleMic(result: FlutterResult) {
        let coreCall = mCore.currentCall
        if(coreCall == nil) {
            return result(FlutterError(code: "404", message: "Current call not found", details: nil))
        }
        mCore.micEnabled = !mCore.micEnabled
        result(mCore.micEnabled)
    }
    
    func refreshSipAccount(result: FlutterResult? = nil) {
        mCore.refreshRegisters()
        result?(true)
    }
    
    func unregisterSipAccount(result: FlutterResult) {
        NSLog("Try to unregister")
        if let account = mCore.defaultAccount {
            let params = account.params
            let clonedParams = params?.clone()
            clonedParams?.registerEnabled = false
            account.params = clonedParams
            mCore.clearProxyConfig()
            deleteSipAccount()
            result(true)
        } else {
            NSLog("Sip account not found")
            result(false)
        }
    }
    
    private func deleteSipAccount() {
        // To completely remove an Account
        if let account = mCore.defaultAccount {
            mCore.removeAccount(account: account)
            
            // To remove all accounts use
            mCore.clearAccounts()
            
            // Same for auth info
            mCore.clearAllAuthInfo()
        }
    }
    
    func getCallId(result: FlutterResult) {
        let callId = mCore.currentCall?.callLog?.callId
        if (callId != nil && !callId!.isEmpty) {
            result(callId)
        } else {
            result(FlutterError(code: "404", message: "Call ID not found", details: nil))
        }
    }
    
    func getMissCalls(result: FlutterResult) {
        result(mCore.missedCallsCount)
    }
    
    func getSipReistrationState(result: FlutterResult) {
        let state = mCore.defaultAccount?.state
        if(state != nil) {
            result(RegisterSipState.allCases[state!.rawValue].rawValue)
        } else {
            result(FlutterError(code: "404", message: "Register state not found", details: nil))
        }
    }
    
    func isMicEnabled(result: FlutterResult) {
        result(mCore.micEnabled)
    }
    
    func isSpeakerEnabled(result: FlutterResult) {
        let currentAudioDevice = mCore.currentCall?.outputAudioDevice
        let speakerEnabled = currentAudioDevice?.type == AudioDevice.Kind.Speaker
        result(speakerEnabled)
    }
    
    private func isMissed(callLog: CallLog?) -> Bool {
        return (callLog?.dir == Call.Dir.Incoming && callLog?.status == Call.Status.Missed)
    }
}
