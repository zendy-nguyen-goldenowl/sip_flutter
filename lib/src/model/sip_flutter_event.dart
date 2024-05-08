import 'package:sip_flutter/src/model/call_type.dart';
import 'package:sip_flutter/src/model/sip_event.dart';

class SipFlutterEvent {
  final SipEvent type;
  final dynamic body;
  final CallType? callType;
  final String? caller;

  const SipFlutterEvent({
    required this.type,
    required this.body,
    this.callType,
    this.caller,
  });

  SipFlutterEvent copyWith({
    SipEvent? type,
    dynamic body,
    CallType? callType,
    String? caller,
  }) {
    return SipFlutterEvent(
      type: type ?? this.type,
      body: body ?? this.body,
      callType: callType ?? this.callType,
      caller: caller ?? this.caller,
    );
  }

  @override
  bool operator ==(covariant SipFlutterEvent other) {
    if (identical(this, other)) return true;

    return other.type == type &&
        other.body == body &&
        other.callType == callType &&
        other.caller == caller;
  }

  @override
  int get hashCode {
    return type.hashCode ^ body.hashCode ^ callType.hashCode ^ caller.hashCode;
  }
}
