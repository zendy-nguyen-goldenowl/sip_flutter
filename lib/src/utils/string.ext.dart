extension StringExtension on String {
  String capitalize() {
    String remainWord = substring(1);
    return "${this[0].toUpperCase()}$remainWord";
  }
}
