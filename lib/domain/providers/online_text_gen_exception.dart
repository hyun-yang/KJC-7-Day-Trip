/// Failure while generating text through an online provider.
///
/// A null [statusCode] identifies a network, TLS, or timeout failure.
class OnlineTextGenException implements Exception {
  const OnlineTextGenException({
    required this.provider,
    required this.statusCode,
    required this.message,
  });

  final String provider;
  final int? statusCode;
  final String message;

  String get userMessage => switch (statusCode) {
    null => 'Check your network connection',
    401 || 403 => 'Invalid API key — check it in Settings',
    429 => 'Rate limit exceeded — try again shortly',
    >= 500 => 'Provider error — try again shortly',
    _ => message,
  };

  @override
  String toString() =>
      'OnlineTextGenException($provider, ${statusCode ?? 'network'}): '
      '$message';
}

/// OpenAI API key has not been configured.
class ApiKeyMissingException implements Exception {
  const ApiKeyMissingException();

  @override
  String toString() =>
      'OpenAI API key is not set — enter it on the Settings screen';
}
