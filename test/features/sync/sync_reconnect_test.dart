import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:billfern/core/network/timeout_http_client.dart';
import 'package:billfern/features/sync/data/supabase_sync_remote.dart';
import 'package:billfern/features/sync/domain/sync_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, SupabaseClient;

/// Regression tests for "sync does not recover after reconnecting".
///
/// Root cause: Supabase Auth shares ONE access-token refresh between all
/// requests and has no request timeout. A refresh sent while the network
/// was down could hang forever, so after reconnecting every request (and
/// every "Retry sync") waited on it and timed out without reaching the
/// server. These tests run the real Supabase client against a local server
/// that can simulate a dead network (requests that never get a response).

const _userId = '0a000000-0000-4000-8000-00000000000a';

String _b64(Map<String, Object?> value) =>
    base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

/// A synthetic session (the local server does not check signatures).
Map<String, Object?> _session(int expiresInSeconds) {
  final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + expiresInSeconds;
  final token = [
    _b64({'alg': 'HS256', 'typ': 'JWT'}),
    _b64({'sub': _userId, 'exp': exp, 'role': 'authenticated'}),
    'signature',
  ].join('.');
  return {
    'access_token': token,
    'token_type': 'bearer',
    'expires_in': expiresInSeconds,
    'expires_at': exp,
    'refresh_token': 'refresh-${DateTime.now().microsecondsSinceEpoch}',
    'user': {
      'id': _userId,
      'aud': 'authenticated',
      'created_at': '2026-01-01T00:00:00Z',
      'app_metadata': <String, Object?>{},
      'user_metadata': <String, Object?>{},
    },
  };
}

/// Minimal stand-in for Supabase Auth and the `sync_push` RPC.
class _LocalSupabase {
  late final HttpServer _server;

  /// Simulates a dead network: requests are accepted but never answered.
  bool offline = false;

  /// Lifetime of tokens issued by refreshes (negative = already expired).
  int refreshExpiresIn = 3600;
  final List<String> answered = [];

  String get url => 'http://127.0.0.1:${_server.port}';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((request) async {
      if (offline) return;
      await utf8.decodeStream(request);
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path.startsWith('/auth/v1/token')) {
        request.response.write(jsonEncode(_session(refreshExpiresIn)));
        answered.add('refresh');
      } else {
        request.response.write(
          jsonEncode({'status': 'applied', 'version': 1, 'deleted': false}),
        );
        answered.add('push');
      }
      await request.response.close();
    });
  }

  Future<void> stop() => _server.close(force: true);
}

void main() {
  late _LocalSupabase backend;
  final clients = <SupabaseClient>[];

  setUp(() async {
    HttpOverrides.global = null; // real sockets, local server only
    backend = _LocalSupabase();
    await backend.start();
  });

  tearDown(() async {
    for (final client in clients) {
      await client.dispose();
    }
    clients.clear();
    await backend.stop();
  });

  /// The app's wiring (see `main`) with short test timeouts.
  Future<(SupabaseClient, SupabaseSyncRemote)> connect({
    required int sessionExpiresIn,
  }) async {
    final client = SupabaseClient(
      backend.url,
      'sb_publishable_local_test',
      httpClient: TimeoutHttpClient(
        http.Client(),
        timeout: const Duration(milliseconds: 600),
      ),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    clients.add(client);
    await client.auth.recoverSession(jsonEncode(_session(sessionExpiresIn)));
    return (
      client,
      SupabaseSyncRemote(client, timeout: const Duration(seconds: 3)),
    );
  }

  Future<Object> push(SupabaseSyncRemote remote) async {
    try {
      return await remote.push(
        opId: '10000000-0000-4000-8000-000000000001',
        subscriptionId: 'sub-1',
        kind: OutboxKind.upsert,
        baseVersion: null,
        payload: {'id': 'sub-1'},
      );
    } on SyncRemoteException catch (error) {
      return error.kind;
    }
  }

  test('a dead network is reported as offline, then recovers', () async {
    final (_, remote) = await connect(sessionExpiresIn: 3600);
    backend.offline = true;
    expect(await push(remote), SyncFailureKind.network);

    backend.offline = false;
    expect(await push(remote), isA<PushApplied>());
  });

  test('a token refresh that hung while offline does not block sync after '
      'reconnecting', () async {
    // Expires within Supabase Auth's 30-second margin: the next request
    // must refresh the token first.
    final (client, remote) = await connect(sessionExpiresIn: 31);
    await Future<void>.delayed(const Duration(milliseconds: 1200));

    backend.offline = true;
    expect(await push(remote), SyncFailureKind.network);

    // A refresh is still in flight on the dead connection when the
    // network returns; every request shares it.
    unawaited(client.auth.getSession().then((_) {}, onError: (_) {}));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    backend.offline = false;

    // First manual retry after reconnecting succeeds.
    expect(await push(remote), isA<PushApplied>());
    expect(backend.answered, containsAllInOrder(['refresh', 'push']));
  });

  test('an expired session is refreshed on the first retry after '
      'reconnecting', () async {
    final (client, remote) = await connect(sessionExpiresIn: 31);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    // The device now holds a token that has fully expired.
    backend.refreshExpiresIn = -60;
    await client.auth.getSession();
    backend.refreshExpiresIn = 3600;

    backend.offline = true;
    unawaited(client.auth.getSession().then((_) {}, onError: (_) {}));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    backend.offline = false;

    // The hung refresh now fails, so Supabase Auth's own retry sends a new
    // one on a fresh connection, and the push goes through.
    expect(await push(remote), isA<PushApplied>());
    expect(backend.answered.last, 'push');
  });

  test('changes made offline stay pending until the server confirms', () async {
    final (_, remote) = await connect(sessionExpiresIn: 31);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    backend.offline = true;
    for (var i = 0; i < 2; i++) {
      expect(await push(remote), SyncFailureKind.network);
    }
    expect(backend.answered, isEmpty);
    backend.offline = false;
    expect(await push(remote), isA<PushApplied>());
  });

  group('TimeoutHttpClient', () {
    test('fails a request that never gets a response', () async {
      backend.offline = true;
      final client = TimeoutHttpClient(
        http.Client(),
        timeout: const Duration(milliseconds: 300),
      );
      addTearDown(client.close);
      await expectLater(
        client.get(Uri.parse('${backend.url}/rest/v1/x')),
        throwsA(isA<http.ClientException>()),
      );
    });

    test('passes normal responses through unchanged', () async {
      final client = TimeoutHttpClient(http.Client());
      addTearDown(client.close);
      final response = await client.post(
        Uri.parse('${backend.url}/rest/v1/rpc/sync_push'),
        body: '{}',
      );
      expect(response.statusCode, 200);
      expect(jsonDecode(response.body), containsPair('status', 'applied'));
    });
  });
}
