enum CallType {
  inbound,
  outbound;

  static CallType? fromName(String? name) {
    return values
        .cast<CallType?>()
        .firstWhere((e) => e?.name == name, orElse: () => null);
  }
}
