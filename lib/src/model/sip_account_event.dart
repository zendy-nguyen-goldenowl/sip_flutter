import 'package:sip_flutter/src/utils/string.ext.dart';

enum SipAccountEventType {
  /// Initial state for registrations.
  none,

  /// Registration is in progress.

  progress,

  /// Registration is successful.

  ok,

  /// Unregistration succeeded.

  cleared,

  /// Registration failed.

  failed,

  /// Registration refreshing.
  refreshing;

  String get title {
    return name.capitalize();
  }

  static SipAccountEventType fromTitle(String title) {
    return values.firstWhere((e) => e.title == title, orElse: () => failed);
  }
}

class SipAccountEvent {
  final SipAccountEventType type;
  final String message;

  const SipAccountEvent({
    required this.type,
    this.message = '',
  });

  SipAccountEvent copyWith({
    SipAccountEventType? type,
    String? message,
  }) {
    return SipAccountEvent(
      type: type ?? this.type,
      message: message ?? this.message,
    );
  }

  @override
  String toString() => 'SipAccountEvent(type: $type, message: $message)';

  @override
  bool operator ==(covariant SipAccountEvent other) {
    if (identical(this, other)) return true;

    return other.type == type && other.message == message;
  }

  @override
  int get hashCode => type.hashCode ^ message.hashCode;
}
