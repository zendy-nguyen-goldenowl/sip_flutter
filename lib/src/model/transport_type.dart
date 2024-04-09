import 'package:sip_flutter/src/utils/string.ext.dart';

enum TransportType {
  tcp,
  udp,
  tls;

  String get title {
    return name.capitalize();
  }

  static TransportType fromTitle(String title) {
    return values.firstWhere((e) => e.title == title, orElse: () => tcp);
  }
}
