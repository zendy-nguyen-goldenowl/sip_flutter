import Flutter
import UIKit
import PushKit
import CallKit

public class SwiftSipFlutterPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    
    private var sipManager: SipManager = SipManager.instance
    static var eventSink: FlutterEventSink?
    private var provider: CXProvider?
    private var voipRegistry: PKPushRegistry?
    
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SwiftSipFlutterPlugin()
        
        let methodChannel = FlutterMethodChannel(name: "sip_flutter_method_channel", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        
        let eventChannel = FlutterEventChannel(name: "sip_flutter_event_channel", binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(instance)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch(call.method) {
        case "initSipModule":
            let jsonString = toJson(from: (call.arguments as? [String:Any])?["sipConfiguration"])
            if(jsonString == nil) {
                return NSLog("Sip configuration is not valid")
            }
            let sipConfiguration = SipConfiguration.toObject(JSONString: jsonString!)
            if(sipConfiguration == nil) {
                return NSLog("Sip configuration is not valid")
            }
            sipManager.initSipModule(sipConfiguration: sipConfiguration!)
            initPushKit()
            break
        case "call":
            let phoneNumber = (call.arguments as? [String:Any])?["recipient"] as? String
            if(phoneNumber == nil) {
                return result(FlutterError(code: "404", message: "Recipient is not valid", details: nil))
            }
            sipManager.call(recipient: phoneNumber!, result: result)
            break
        case "hangup":
            sipManager.hangup(result: result)
            break
        case "answer":
            sipManager.answer(result: result)
            break
        case "reject":
            sipManager.reject(result: result)
            break
        case "transfer":
            let ext = (call.arguments as? [String:Any])?["extension"] as? String
            if(ext == nil) {
                return result(FlutterError(code: "404", message: "Extension is not valid", details: nil))
            }
            sipManager.transfer(recipient: ext!, result: result)
            break
        case "pause":
            sipManager.pause(result: result)
            break
        case "resume":
            sipManager.resume(result: result)
            break
        case "sendDTMF":
            let dtmf = (call.arguments as? [String:Any])?["recipient"] as? String
            if(dtmf == nil) {
                return result(FlutterError(code: "404", message: "DTMF is not valid", details: nil))
            }
            sipManager.sendDTMF(dtmf: dtmf!, result: result)
            break
        case "toggleSpeaker":
            sipManager.toggleSpeaker(result: result)
            break
        case "toggleMic":
            sipManager.toggleMic(result: result)
            break
        case "refreshSipAccount":
            sipManager.refreshSipAccount(result: result)
            break
        case "unregisterSipAccount":
            sipManager.unregisterSipAccount(result: result)
            break
        case "getCallId":
            sipManager.getCallId(result: result)
            break
        case "getMissedCalls":
            sipManager.getMissCalls(result: result)
            break
        case "getSipRegistrationState":
            sipManager.getSipReistrationState(result: result)
            break
        case "isMicEnabled":
            sipManager.isMicEnabled(result: result)
            break
        case "isSpeakerEnabled":
            sipManager.isSpeakerEnabled(result: result)
            break
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        SwiftSipFlutterPlugin.eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        SwiftSipFlutterPlugin.eventSink = nil
        return nil
    }
    
    private func setupVOIP(){
        //Setup VOIP
        voipRegistry = PKPushRegistry(queue: nil)
        voipRegistry?.delegate = self
        voipRegistry?.desiredPushTypes = [.voIP]
    }
    
    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _  in
                print(">> requestNotificationAuthorization granted: \(granted)")
            }
    }
    
    private func initPushKit() {
        UNUserNotificationCenter.current().delegate = self
        requestNotificationAuthorization()
//        setupVOIP()
        
        let config = CXProviderConfiguration(localizedName: "call-app")
        config.supportsVideo = false
        config.supportedHandleTypes = [.generic]
        config.maximumCallsPerCallGroup = 1
        config.maximumCallGroups = 1
        self.provider = CXProvider(configuration: config)
    }
}

extension SwiftSipFlutterPlugin: PKPushRegistryDelegate {
    
    public func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        if type == .voIP {
            var stringifiedToken = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
            stringifiedToken.append(String(":remote"))
            NSLog(stringifiedToken)
            NSLog("------------")
            sipManager.mCore.didRegisterForRemotePushWithStringifiedToken(deviceTokenStr: stringifiedToken)
        }
    }
    
    public func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        
    }
    
    public func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        
    }
}

extension SwiftSipFlutterPlugin: UNUserNotificationCenterDelegate {
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: (UNNotificationPresentationOptions) -> Void
    ) {
        print(">> willPresent: \(notification)")
        completionHandler([.alert, .sound, .badge])
    }
}
