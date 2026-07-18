import '../../domain/providers/text_gen_provider.dart';

/// Test and development provider that records prompts and returns fixed text.
class FakeTextGenProvider implements TextGenProvider {
  FakeTextGenProvider(this.response);

  final String response;
  final prompts = <String>[];

  @override
  String get name => 'fake';

  @override
  Future<String> generate(String prompt) async {
    prompts.add(prompt);
    return response;
  }
}
