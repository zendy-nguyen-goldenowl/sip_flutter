import 'package:sip_flutter/src/model/sip_event.dart';

class SipFlutterEvent {
  final SipEvent type;
  final dynamic body;

  const SipFlutterEvent({
    required this.type,
    required this.body,
  });

  SipFlutterEvent copyWith({
    SipEvent? type,
    dynamic body,
  }) {
    return SipFlutterEvent(
      type: type ?? this.type,
      body: body ?? this.body,
    );
  }

  @override
  bool operator ==(covariant SipFlutterEvent other) {
    if (identical(this, other)) return true;

    return other.type == type && other.body == body;
  }

  @override
  int get hashCode => type.hashCode ^ body.hashCode;
}
