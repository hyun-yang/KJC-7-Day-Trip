/// Produces a generated conversation as a JSON string from a prompt.
abstract interface class TextGenProvider {
  String get name;

  Future<String> generate(String prompt);
}
