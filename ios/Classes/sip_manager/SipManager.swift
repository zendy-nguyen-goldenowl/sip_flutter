import Foundation
import AVFAudio
import Network

class SipManager : NSObject{
    
    static let instance = SipManager()
    var cacheStateAccount = RegisterSipState.None
    
    private var client = SipClient()
    private var calls = Set<SipCall>()
    private var currentCall : SipCall?

    
    override init() {
        super.init()
        self.initBaresip()
    }
    
    deinit{
        client.stop()
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
    
    private func sendAccountEvent(state: RegisterSipState) {
        cacheStateAccount = state
        sendEvent(eventName: EventAccountRegistrationStateChanged, body: ["registrationState": state.rawValue])
    }
    
    public func initBaresip(){
        client.delegate = self
        client.start()
    }
    
    public func initSipModule(sipConfiguration: SipConfiguration) {
        if(client.isRegistered()){
            client.unregister()
        }
        initSipAccount(sipConfiguration: sipConfiguration)
    }
     
    
    private func initSipAccount(sipConfiguration: SipConfiguration) {
        let username = sipConfiguration.username
        let password = sipConfiguration.password
        let domain = sipConfiguration.domain
        let expires = sipConfiguration.expires ?? 900
        client.username = username
        client.password = password
        client.domain = domain
        client.regint = Int32(expires)
        
        registry()
    }
    
    func registry(){
        client.registry()
    }
    
    func unregister(){
        client.unregister()
    }
    
    func call(recipient: String, result: FlutterResult) {
        NSLog("Try to call")
        let sipUri = String("sip:" + recipient)
        let sipCall = client.makeCall(sipUri)
        calls.insert(sipCall)
        currentCall = sipCall
        result(true)
    }
    
    func answer(result: FlutterResult) {
        NSLog("Try to answer")
        if(currentCall == nil) {
            NSLog("Current call not found")
            return result(false)
        }
        currentCall!.answer()
        NSLog("Answer successful")
        result(true)
    }
    
    func hangup(result: FlutterResult) {
        NSLog("Try to hangup")
        if(currentCall == nil) {
            NSLog("Current call not found")
            return result(false)
        }
        // Terminating a call is quite simple
        currentCall!.hangup(487,reason: "Request Terminated")
        NSLog("Hangup successful")
        result(true)
    }
    
    func reject(result: FlutterResult) {
        NSLog("Try to reject")
        if(currentCall == nil) {
            NSLog("Current call not found")
            return result(false)
        }
        currentCall!.hangup(500, reason: "Busy Now")
        NSLog("Reject successful")
        result(true)
    }
    
    func pause(result: FlutterResult) {
        if(currentCall == nil) {
            NSLog( "Current call not found")
              return result(false)
        }
        currentCall?.hold()
        NSLog( "Pause successful")
        result(true)
    }
    
    func resume(result: FlutterResult) {
        if(currentCall == nil) {
            NSLog( "Current call not found")
              return result(false)
        }
        currentCall?.resume()
        NSLog( "Resume successful")
        result(true)
    }
    
    func toggleSpeaker(result: FlutterResult) {
        if(currentCall == nil){
            return result(FlutterError(code: "404", message: "Current call not found", details: nil))
        }
        let isSpeaker = isSpeaker()
        setupAudioSession(isSpeakerEnabled: !isSpeaker)
        result(!isSpeaker)

    }
    
    func toggleMic(result: FlutterResult) {
        if(currentCall == nil) {
            return result(FlutterError(code: "404", message: "Current call not found", details: nil))
        }
        let isMute = currentCall!.isMicMuted()
        currentCall!.setMicMuted(!isMute)
        result(!(currentCall!.isMicMuted()))
    }
    
    func refreshSipAccount(result: FlutterResult) {
        registry()
        result(true)
    }
    
    
    func unregisterSipAccount(result: FlutterResult) {
        unregister()
        result(true)
    }
    
    func getSipReistrationState(result: FlutterResult) {
        result(cacheStateAccount)
    }
    
    func isMicEnabled(result: FlutterResult){
        if(currentCall != nil) {
            let isMute = currentCall!.isMicMuted()
            result(!isMute)
            return
        }
        result(true)
    }
    
    func isSpeakerEnabled(result: FlutterResult) {
        result(isSpeaker())
    }
    
    func isSpeaker() -> Bool{
        let audioSession = AVAudioSession.sharedInstance()
        let currentOutputPort = audioSession.currentRoute.outputs.first?.portType
        return currentOutputPort == .builtInSpeaker
    }
    
    func setupAudioSession(isSpeakerEnabled: Bool) {
        let audioSession = AVAudioSession.sharedInstance()
           do {
               try audioSession.setCategory(.playAndRecord,mode: .voiceChat,options: isSpeakerEnabled ? .defaultToSpeaker : [])
               try audioSession.setActive(true)
           } catch let error as NSError {
               print("Fail: \(error.localizedDescription)")
           }
       }
}

extension SipManager : SipClientDelegate{
    func onWillRegister(_ sipSdk: SipClient) {
        NSLog("Registering...\n")
        sendAccountEvent(state: RegisterSipState.Progress)
    }
    
    func onDidRegister(_ sipSdk: SipClient) {
        NSLog("Registered...\n")
        sendAccountEvent(state: RegisterSipState.Ok)
    }
    
    func onFailedRegister(_ sipSdk: SipClient) {
        NSLog("Failed to register...\n")
        sendAccountEvent(state: RegisterSipState.Failed)
    }
    
    func onWillUnRegister(_ sipSdk: SipClient) {
        NSLog("Unregistering...\n")
        sendAccountEvent(state: RegisterSipState.None)
    }
    
    func onCallOutgoing(_ sipCall: SipCall) {
        NSLog("Outgoing call from \(sipCall.remoteUri)...\n")
        currentCall = sipCall
        sendEvent(eventName: EventRing, body: ["username": sipCall.remoteUri, "callType": CallType.outbound.rawValue])
    }
    
    func onCallIncoming(_ sipCall: SipCall) {
        NSLog("Incomming call from \(sipCall.remoteUri)...\n")
        calls.insert(sipCall)
        currentCall = sipCall
        sendEvent(eventName: EventRing, body: ["username": sipCall.remoteUri, "callType": CallType.inbound.rawValue])
    }
    
    func onCallRinging(_ sipCall: SipCall) {
        NSLog("Call ringing from \(sipCall.remoteUri)...\n")
        currentCall = sipCall
    }
    
    func onCallProcess(_ sipCall: SipCall) {
        NSLog("Call process from \(sipCall.remoteUri)...\n")
        currentCall = sipCall
    }
    
    func onCallEstablished(_ sipCall: SipCall) {
        NSLog("Call established from \(sipCall.remoteUri)...\n")
        currentCall = sipCall
        sendEvent(eventName: EventUp, body: [:])
    }
    
    func onCallClosed(_ sipCall: SipCall) {
        NSLog("Call closed from \(sipCall.remoteUri)...\n")
        sendEvent(eventName: EventHangup,body: [:])
        calls.remove(sipCall)
        currentCall = nil
    }
}
