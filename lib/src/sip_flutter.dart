import 'dart:async';
import 'package:flutter/services.dart';
import 'package:sip_flutter/src/call_module.dart';

class SipFlutter {
  static const MethodChannel _channel =
      MethodChannel('sip_flutter_method_channel');

  static Future<String?> get platformVersion async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  static CallModule callModule = CallModule.instance;
}
