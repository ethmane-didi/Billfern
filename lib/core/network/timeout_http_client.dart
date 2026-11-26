import 'dart:async';

import 'package:http/http.dart' as http;

/// An HTTP client that never waits forever.
///
/// Neither `dart:io` nor Supabase Auth put a time limit on requests. A
/// request sent just before the network drops can therefore hang
/// indefinitely, and Supabase Auth shares one token refresh between all
/// requests: a single hung refresh would block every later request, even
/// after the connection comes back. This client fails such requests with a
/// [http.ClientException] instead (treated as a retryable network failure),
/// which releases the shared refresh so the next attempt starts a new one.
///
/// [timeout] limits the wait for the response headers and for each chunk of
/// the body. The abandoned request is left to the platform to clean up.
class TimeoutHttpClient extends http.BaseClient {
  TimeoutHttpClient(this._inner, {this.timeout = const Duration(seconds: 15)});

  final http.Client _inner;
  final Duration timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner
        .send(request)
        .timeout(
          timeout,
          onTimeout: () =>
              throw http.ClientException('Request timed out', request.url),
        );
    final body = response.stream.timeout(
      timeout,
      onTimeout: (sink) {
        sink
          ..addError(http.ClientException('Response timed out', request.url))
          ..close();
      },
    );
    return http.StreamedResponse(
      http.ByteStream(body),
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() => _inner.close();
}
