import 'dart:convert';

class SipConfiguration {
  final String username;
  final String domain;
  final String password;

  const SipConfiguration({
    required this.username,
    required this.domain,
    required this.password,
  });

  SipConfiguration copyWith({
    String? username,
    String? domain,
    String? password,
  }) {
    return SipConfiguration(
      username: username ?? this.username,
      domain: domain ?? this.domain,
      password: password ?? this.password,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'username': username,
      'domain': domain,
      'password': password,
    };
  }

  factory SipConfiguration.fromMap(Map<String, dynamic> map) {
    return SipConfiguration(
      username: map['username'] != null ? map['username'] as String : "",
      domain: map['domain'] != null ? map['domain'] as String : "",
      password: map['password'] != null ? map['password'] as String : "",
    );
  }

  String toJson() => json.encode(toMap());

  factory SipConfiguration.fromJson(String source) =>
      SipConfiguration.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() =>
      'SipConfiguration(username: $username, domain: $domain, password: $password)';

  @override
  bool operator ==(covariant SipConfiguration other) {
    if (identical(this, other)) return true;

    return other.username == username &&
        other.domain == domain &&
        other.password == password;
  }

  @override
  int get hashCode => username.hashCode ^ domain.hashCode ^ password.hashCode;
}
