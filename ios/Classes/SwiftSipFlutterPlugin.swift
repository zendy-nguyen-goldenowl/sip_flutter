import Flutter
import UIKit

public class SwiftSipFlutterPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    
    private var sipManager: SipManager = SipManager.instance
    static var eventSink: FlutterEventSink?
    
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
        case "pause":
            sipManager.pause(result: result)
            break
        case "resume":
            sipManager.resume(result: result)
            break
        case "setSpeaker":
            let enable = (call.arguments as? [String:Any])?["enable"] as? Bool
            sipManager.setSpeaker(enable: enable, result: result)
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
}
