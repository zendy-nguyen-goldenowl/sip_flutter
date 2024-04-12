import 'package:sip_flutter/src/utils/string.ext.dart';

enum SipEvent {
  ring,
  up,
  paused,
  resuming,
  missed,
  hangup,
  error;

  String get title {
    return name.capitalize();
  }

  static SipEvent? fromTitle(String title) {
    return values
        .cast<SipEvent?>()
        .firstWhere((e) => e?.title == title, orElse: () => null);
  }
}
