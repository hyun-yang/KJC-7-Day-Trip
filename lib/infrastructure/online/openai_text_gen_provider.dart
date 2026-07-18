import 'dart:convert';
import 'dart:io';

import '../../domain/providers/online_text_gen_exception.dart';
import '../../domain/providers/text_gen_provider.dart';
import 'json_extractor.dart';

/// OpenAI Chat Completions adapter for JSON conversation generation.
class OpenAiTextGenProvider implements TextGenProvider {
  OpenAiTextGenProvider({
    required this.apiKey,
    required this.model,
    Uri? endpointOverride,
    this.requestTimeout = const Duration(seconds: 120),
  }) : _endpointOverride = endpointOverride;

  final String apiKey;
  final String model;
  final Uri? _endpointOverride;
  final Duration requestTimeout;

  static final _endpoint = Uri.parse(
    'https://api.openai.com/v1/chat/completions',
  );

  @override
  String get name => 'openai';

  @override
  Future<String> generate(String prompt) async {
    final content = await _post(prompt);
    return extractJsonObject(content);
  }

  Future<String> _post(String prompt) async {
    final client = HttpClient();
    try {
      return await _send(client, prompt).timeout(requestTimeout);
    } on OnlineTextGenException {
      rethrow;
    } on Exception catch (error) {
      throw OnlineTextGenException(
        provider: name,
        statusCode: null,
        message: error.toString(),
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _send(HttpClient client, String prompt) async {
    final request = await client.postUrl(_endpointOverride ?? _endpoint);
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
    request.write(
      jsonEncode({
        'model': model,
        'max_completion_tokens': 4096,
        'response_format': {'type': 'json_object'},
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      }),
    );

    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OnlineTextGenException(
        provider: name,
        statusCode: response.statusCode,
        message: _errorMessage(body),
      );
    }

    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final choices = decoded['choices'] as List<dynamic>;
      final message =
          (choices.first as Map<String, dynamic>)['message']
              as Map<String, dynamic>;
      return message['content'] as String;
    } catch (error) {
      throw OnlineTextGenException(
        provider: name,
        statusCode: response.statusCode,
        message: 'Unexpected response shape: $error',
      );
    }
  }

  String _errorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic> && error['message'] is String) {
          return error['message'] as String;
        }
      }
    } catch (_) {
      // The raw response is more useful when the provider did not return JSON.
    }
    return body;
  }
}
