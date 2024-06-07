import 'dart:async';
import 'package:flutter/services.dart';
import 'package:sip_flutter/sip_flutter.dart';

class CallModule {
  CallModule._privateConstructor();

  static final CallModule _instance = CallModule._privateConstructor();

  static CallModule get instance => _instance;

  static const MethodChannel _methodChannel =
      MethodChannel('sip_flutter_method_channel');

  static const EventChannel _eventChannel =
      EventChannel('sip_flutter_event_channel');

  static Stream broadcastStream = _eventChannel.receiveBroadcastStream();

  final StreamController<SipFlutterEvent> _eventCallStreamController =
      StreamController.broadcast();

  StreamController<SipFlutterEvent> get eventCallStreamController =>
      _eventCallStreamController;

  final StreamController<SipAccountEvent> _eventAccountStreamController =
      StreamController.broadcast();

  StreamController<SipAccountEvent> get eventAccountStreamController =>
      _eventAccountStreamController;

  Future<void> initSipModule(SipConfiguration sipConfiguration) async {
    if (!_eventCallStreamController.hasListener) {
      broadcastStream.listen(_listener);
    }
    await _methodChannel.invokeMethod(
        'initSipModule', {"sipConfiguration": sipConfiguration.toMap()});
  }

  void _listener(dynamic event) {
    final eventName = event['event'] as String;
    final body = event['body'];
    if (eventName == 'AccountRegistrationStateChanged') {
      final status = body['registrationState'];
      if (status != null) {
        final type = SipAccountEventType.fromTitle(status);
        _eventAccountStreamController.add(SipAccountEvent(type: type));
      }
      return;
    }
    final type = SipEvent.fromTitle(eventName);
    if (type == null) return;
    switch (type) {
      case SipEvent.ring:
        eventCallStreamController.add(
          SipFlutterEvent(
            type: type,
            body: body,
            callType: CallType.fromName(body['callType']),
            caller: body['username'],
          ),
        );
      default:
        eventCallStreamController.add(SipFlutterEvent(type: type, body: body));
    }
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

  Future<bool> setSpeaker(bool enable) async {
    return await _methodChannel.invokeMethod('setSpeaker', {"enable": enable});
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
