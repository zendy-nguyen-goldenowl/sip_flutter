import 'dart:async';
import 'package:flutter/services.dart';
import 'package:sip_flutter/src/model/sip_configuration.dart';
import 'package:sip_flutter/src/model/sip_event.dart';
import 'package:sip_flutter/src/model/sip_flutter_event.dart';

class CallModule {
  CallModule._privateConstructor();

  static final CallModule _instance = CallModule._privateConstructor();

  static CallModule get instance => _instance;

  static const MethodChannel _methodChannel =
      MethodChannel('sip_flutter_method_channel');

  static const EventChannel _eventChannel =
      EventChannel('sip_flutter_event_channel');

  static Stream broadcastStream = _eventChannel.receiveBroadcastStream();

  final StreamController<SipFlutterEvent> _eventStreamController =
      StreamController.broadcast();

  StreamController<SipFlutterEvent> get eventStreamController =>
      _eventStreamController;

  Future<void> initSipModule(SipConfiguration sipConfiguration) async {
    if (!_eventStreamController.hasListener) {
      broadcastStream.listen(_listener);
    }
    await _methodChannel.invokeMethod(
        'initSipModule', {"sipConfiguration": sipConfiguration.toMap()});
  }

  void _listener(dynamic event) {
    final eventName = event['event'] as String;

    final type = SipEvent.fromTitle(eventName);
    if (type == null) return;
    final body = event['body'];
    _eventStreamController.add(SipFlutterEvent(type: type, body: body));
  }

  Future<bool> call(String phoneNumber) async {
    return await _methodChannel
        .invokeMethod('call', {"recipient": phoneNumber});
  }

  Future<bool> hangup() async {
    return await _methodChannel.invokeMethod('hangup');
  }

  Future<bool> answer() async {
    return await _methodChannel.invokeMethod('answer');
  }

  Future<bool> reject() async {
    return await _methodChannel.invokeMethod('reject');
  }

  Future<bool> transfer(String extension) async {
    return await _methodChannel
        .invokeMethod('transfer', {"extension": extension});
  }

  Future<bool> pause() async {
    return await _methodChannel.invokeMethod('pause');
  }

  Future<bool> resume() async {
    return await _methodChannel.invokeMethod('resume');
  }

  Future<bool> sendDTMF(String dtmf) async {
    return await _methodChannel.invokeMethod('sendDTMF', {"recipient": dtmf});
  }

  Future<bool> toggleSpeaker() async {
    return await _methodChannel.invokeMethod('toggleSpeaker');
  }

  Future<bool> toggleMic() async {
    return await _methodChannel.invokeMethod('toggleMic');
  }

  Future<bool> refreshSipAccount() async {
    return await _methodChannel.invokeMethod('refreshSipAccount');
  }

  Future<bool> unregisterSipAccount() async {
    return await _methodChannel.invokeMethod('unregisterSipAccount');
  }

  Future<String> getCallId() async {
    return await _methodChannel.invokeMethod('getCallId');
  }

  Future<int> getMissedCalls() async {
    return await _methodChannel.invokeMethod('getMissedCalls');
  }

  Future<String> getSipRegistrationState() async {
    return await _methodChannel.invokeMethod('getSipRegistrationState');
  }

  Future<bool> isMicEnabled() async {
    return await _methodChannel.invokeMethod('isMicEnabled');
  }

  Future<bool> isSpeakerEnabled() async {
    return await _methodChannel.invokeMethod('isSpeakerEnabled');
  }
}
