import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kjc_7day_chat/domain/providers/online_text_gen_exception.dart';
import 'package:kjc_7day_chat/infrastructure/online/openai_text_gen_provider.dart';

void main() {
  HttpServer? server;

  tearDown(() async {
    await server?.close(force: true);
    server = null;
  });

  Future<Uri> serve(Future<void> Function(HttpRequest request) handler) async {
    final nextServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server = nextServer;
    nextServer.listen(handler);
    return Uri.parse('http://127.0.0.1:${nextServer.port}/v1/chat/completions');
  }

  test('정상 응답에서 요청과 인증을 구성하고 content JSON을 추출한다', () async {
    late Map<String, dynamic> captured;
    final uri = await serve((request) async {
      expect(request.method, 'POST');
      expect(request.headers.contentType?.mimeType, ContentType.json.mimeType);
      expect(request.headers.value('authorization'), 'Bearer test-key');
      captured =
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>;
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'choices': [
              {
                'message': {'content': '```json\n{"lines": []}\n```'},
              },
            ],
          }),
        );
      await request.response.close();
    });

    final provider = OpenAiTextGenProvider(
      apiKey: 'test-key',
      model: 'test-model',
      endpointOverride: uri,
    );

    expect(provider.name, 'openai');
    expect(await provider.generate('PROMPT'), '{"lines": []}');
    expect(captured['model'], 'test-model');
    expect(captured['max_completion_tokens'], 4096);
    expect(captured['response_format'], {'type': 'json_object'});
    expect((captured['messages'] as List).single, {
      'role': 'user',
      'content': 'PROMPT',
    });
  });

  test('401 응답의 상태와 API 오류 메시지를 매핑한다', () async {
    final uri = await serve((request) async {
      await request.drain<void>();
      request.response
        ..statusCode = HttpStatus.unauthorized
        ..write(
          jsonEncode({
            'error': {'message': 'bad key'},
          }),
        );
      await request.response.close();
    });
    final provider = OpenAiTextGenProvider(
      apiKey: 'k',
      model: 'm',
      endpointOverride: uri,
    );

    await expectLater(
      provider.generate('p'),
      throwsA(
        isA<OnlineTextGenException>()
            .having((error) => error.provider, 'provider', 'openai')
            .having((error) => error.statusCode, 'statusCode', 401)
            .having((error) => error.message, 'message', 'bad key')
            .having(
              (error) => error.userMessage,
              'userMessage',
              'Invalid API key — check it in Settings',
            ),
      ),
    );
  });

  test('429 HTTP 응답을 사용량 제한 오류로 매핑한다', () async {
    final uri = await serve((request) async {
      await request.drain<void>();
      request.response
        ..statusCode = HttpStatus.tooManyRequests
        ..write(
          jsonEncode({
            'error': {'message': 'slow down'},
          }),
        );
      await request.response.close();
    });
    final provider = OpenAiTextGenProvider(
      apiKey: 'k',
      model: 'm',
      endpointOverride: uri,
    );

    await expectLater(
      provider.generate('p'),
      throwsA(
        isA<OnlineTextGenException>()
            .having((error) => error.statusCode, 'statusCode', 429)
            .having(
              (error) => error.userMessage,
              'userMessage',
              'Rate limit exceeded — try again shortly',
            ),
      ),
    );
  });

  test('500 이상 HTTP 응답을 제공자 오류로 매핑한다', () async {
    final uri = await serve((request) async {
      await request.drain<void>();
      request.response
        ..statusCode = HttpStatus.badGateway
        ..write('upstream unavailable');
      await request.response.close();
    });
    final provider = OpenAiTextGenProvider(
      apiKey: 'k',
      model: 'm',
      endpointOverride: uri,
    );

    await expectLater(
      provider.generate('p'),
      throwsA(
        isA<OnlineTextGenException>()
            .having((error) => error.statusCode, 'statusCode', 502)
            .having(
              (error) => error.userMessage,
              'userMessage',
              'Provider error — try again shortly',
            ),
      ),
    );
  });

  test('응답 제한 시간을 넘기면 네트워크 오류로 매핑하고 종료한다', () async {
    final handlerDone = Completer<void>();
    final uri = await serve((request) async {
      try {
        await request.drain<void>();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await request.response.close();
      } catch (_) {
        // The provider force-closes its client when its deadline expires.
      } finally {
        handlerDone.complete();
      }
    });
    final provider = OpenAiTextGenProvider(
      apiKey: 'k',
      model: 'm',
      endpointOverride: uri,
      requestTimeout: const Duration(milliseconds: 20),
    );

    await expectLater(
      provider.generate('p').timeout(const Duration(seconds: 1)),
      throwsA(
        isA<OnlineTextGenException>()
            .having((error) => error.statusCode, 'statusCode', isNull)
            .having(
              (error) => error.userMessage,
              'userMessage',
              'Check your network connection',
            ),
      ),
    );
    await handlerDone.future.timeout(const Duration(seconds: 1));
  });

  test('연결이 거부되면 네트워크 오류로 매핑한다', () async {
    final closedServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final closedPort = closedServer.port;
    await closedServer.close(force: true);
    final provider = OpenAiTextGenProvider(
      apiKey: 'k',
      model: 'm',
      endpointOverride: Uri.parse(
        'http://127.0.0.1:$closedPort/v1/chat/completions',
      ),
      requestTimeout: const Duration(seconds: 1),
    );

    await expectLater(
      provider.generate('p').timeout(const Duration(seconds: 2)),
      throwsA(
        isA<OnlineTextGenException>()
            .having((error) => error.statusCode, 'statusCode', isNull)
            .having(
              (error) => error.userMessage,
              'userMessage',
              'Check your network connection',
            ),
      ),
    );
  });

  test('정상 상태의 예상하지 못한 응답 구조를 제공자 오류로 매핑한다', () async {
    final uri = await serve((request) async {
      await request.drain<void>();
      request.response
        ..statusCode = HttpStatus.ok
        ..write(jsonEncode({'choices': []}));
      await request.response.close();
    });
    final provider = OpenAiTextGenProvider(
      apiKey: 'k',
      model: 'm',
      endpointOverride: uri,
    );

    await expectLater(
      provider.generate('p'),
      throwsA(
        isA<OnlineTextGenException>()
            .having((error) => error.statusCode, 'statusCode', 200)
            .having(
              (error) => error.message,
              'message',
              startsWith('Unexpected response shape:'),
            ),
      ),
    );
  });

  test('상태 코드별 사용자 메시지를 제공한다', () {
    String messageFor(int? statusCode) => OnlineTextGenException(
      provider: 'openai',
      statusCode: statusCode,
      message: 'details',
    ).userMessage;

    expect(messageFor(null), 'Check your network connection');
    expect(messageFor(403), 'Invalid API key — check it in Settings');
    expect(messageFor(429), 'Rate limit exceeded — try again shortly');
    expect(messageFor(500), 'Provider error — try again shortly');
    expect(messageFor(400), 'details');
  });
}
