import 'dart:convert';

class SipConfiguration {
  final String username;
  final String domain;
  final String password;
  final int? expires;

  const SipConfiguration({
    required this.username,
    required this.domain,
    required this.password,
    this.expires,
  });

  SipConfiguration copyWith({
    String? username,
    String? domain,
    String? password,
    int? expires,
  }) {
    return SipConfiguration(
      username: username ?? this.username,
      domain: domain ?? this.domain,
      password: password ?? this.password,
      expires: expires ?? this.expires,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'username': username,
      'domain': domain,
      'password': password,
      'expires': expires,
    };
  }

  factory SipConfiguration.fromMap(Map<String, dynamic> map) {
    return SipConfiguration(
      username: map['username'] != null ? map['username'] as String : "",
      domain: map['domain'] != null ? map['domain'] as String : "",
      password: map['password'] != null ? map['password'] as String : "",
      expires: map['expires'],
    );
  }

  String toJson() => json.encode(toMap());

  factory SipConfiguration.fromJson(String source) =>
      SipConfiguration.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'SipConfiguration(username: $username, domain: $domain, password: $password, expires: $expires)';
  }

  @override
  bool operator ==(covariant SipConfiguration other) {
    if (identical(this, other)) return true;

    return other.username == username &&
        other.domain == domain &&
        other.password == password &&
        other.expires == expires;
  }

  @override
  int get hashCode {
    return username.hashCode ^
        domain.hashCode ^
        password.hashCode ^
        expires.hashCode;
  }
}
