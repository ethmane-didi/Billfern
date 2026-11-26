import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/sync_models.dart';
import '../domain/sync_remote.dart';

/// [SyncRemote] backed by the `sync_push` / `sync_pull` PostgreSQL functions
/// (SECURITY DEFINER, empty search_path; every statement is filtered by
/// `auth.uid()`, and clients have no direct write privileges).
///
/// Never logs payloads, emails or tokens.
class SupabaseSyncRemote implements SyncRemote {
  SupabaseSyncRemote(
    this._client, {
    this.timeout = const Duration(seconds: 20),
  });

  final SupabaseClient _client;
  final Duration timeout;

  @override
  Future<PushResult> push({
    required String opId,
    required String subscriptionId,
    required OutboxKind kind,
    required int? baseVersion,
    Map<String, Object?>? payload,
  }) async {
    final response = await _call(
      () => _client.rpc<dynamic>(
        'sync_push',
        params: {
          'p_op_id': opId,
          'p_subscription_id': subscriptionId,
          'p_kind': kind.name,
          'p_base_version': baseVersion,
          'p_payload': payload == null ? null : toWire(payload),
        },
      ),
    );
    final map = _asMap(response);
    switch (map['status']) {
      case 'applied':
        return PushApplied(
          version: (map['version']! as num).toInt(),
          deleted: map['deleted'] == true,
        );
      case 'conflict':
        final record = map['record'];
        return PushConflict(
          record == null ? null : recordFromWire(_asMap(record)),
        );
      default:
        throw const SyncRemoteException(
          SyncFailureKind.rejected,
          'Unexpected push response',
        );
    }
  }

  @override
  Future<PullPage> pull({required String? cursor, required int limit}) async {
    final (xid, seq) = decodeCursor(cursor);
    final response = await _call(
      () => _client.rpc<dynamic>(
        'sync_pull',
        params: {'p_after_xid': xid, 'p_after_seq': seq, 'p_limit': limit},
      ),
    );
    final map = _asMap(response);
    final records = [
      for (final item in (map['records'] as List? ?? const []))
        recordFromWire(_asMap(item)),
    ];
    final next = map['cursor'];
    return PullPage(
      records: records,
      hasMore: map['hasMore'] == true,
      cursor: next is Map ? encodeCursor(next['xid'], next['seq']) : null,
    );
  }

  /// Cursor text: `"<xid>:<seq>"`.
  static String encodeCursor(Object? xid, Object? seq) => '$xid:$seq';

  static (String?, int) decodeCursor(String? cursor) {
    if (cursor == null) return (null, 0);
    final parts = cursor.split(':');
    if (parts.length != 2 || int.tryParse(parts[0]) == null) return (null, 0);
    return (parts[0], int.tryParse(parts[1]) ?? 0);
  }

  String _userId() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const SyncRemoteException(
        SyncFailureKind.unauthorized,
        'No session',
      );
    }
    return userId;
  }

  @override
  Future<RemoteProfile?> fetchProfile() async {
    final userId = _userId();
    final row = await _call(
      () => _client
          .from('profiles')
          .select('display_currency, updated_at')
          .eq('user_id', userId)
          .maybeSingle(),
    );
    return row == null ? null : _profile(row);
  }

  @override
  Future<RemoteProfile> saveProfile({required String displayCurrency}) async {
    final userId = _userId();
    final row = await _call(
      () => _client
          .from('profiles')
          .upsert({'user_id': userId, 'display_currency': displayCurrency})
          .select('display_currency, updated_at')
          .single(),
    );
    return _profile(row);
  }

  static RemoteProfile _profile(Map<String, dynamic> row) => RemoteProfile(
    displayCurrency: row['display_currency'] as String?,
    updatedAt: '${row['updated_at']}',
  );

  /// Local record → wire: event timestamps are sent in UTC.
  static Map<String, Object?> toWire(Map<String, Object?> payload) {
    final wire = Map<String, Object?>.of(payload);
    final created = payload['createdAt'];
    if (created is String) {
      final parsed = DateTime.tryParse(created);
      wire['createdAt'] = parsed?.toUtc().toIso8601String();
    }
    return wire;
  }

  /// Wire → local record: UTC event timestamps become local times again, so
  /// a round trip yields an identical subscription.
  static RemoteSubscription recordFromWire(Map<String, Object?> map) {
    final payload = (map['payload'] as Map?)?.cast<String, Object?>();
    Map<String, Object?>? local;
    if (payload != null) {
      local = Map<String, Object?>.of(payload);
      final created = payload['createdAt'];
      if (created is String) {
        local['createdAt'] = DateTime.tryParse(created)
            ?.toLocal()
            .toIso8601String();
      }
    }
    return RemoteSubscription(
      id: map['id']! as String,
      version: (map['version']! as num).toInt(),
      serverSequence: (map['serverSequence'] as num?)?.toInt() ?? 0,
      payload: local,
      deletedAt: map['deletedAt'] == null
          ? null
          : DateTime.parse(map['deletedAt']! as String),
    );
  }

  static Map<String, Object?> _asMap(Object? value) {
    if (value is Map) return value.cast<String, Object?>();
    throw const SyncRemoteException(
      SyncFailureKind.rejected,
      'Malformed server response',
    );
  }

  Future<T> _call<T>(Future<T> Function() request) async {
    try {
      return await request().timeout(timeout);
    } on SyncRemoteException {
      rethrow;
    } on TimeoutException {
      throw const SyncRemoteException(SyncFailureKind.network, 'Timed out');
    } on SocketException {
      throw const SyncRemoteException(SyncFailureKind.network, 'No connection');
    } on AuthException catch (error) {
      throw SyncRemoteException(
        error is AuthRetryableFetchException
            ? SyncFailureKind.network
            : SyncFailureKind.unauthorized,
        'Authentication error ${error.statusCode ?? ''}'.trim(),
      );
    } on PostgrestException catch (error) {
      throw SyncRemoteException(
        classifyPostgrestCode(error.code),
        'Server error ${error.code ?? ''}'.trim(),
      );
    } on Exception {
      // Other client/transport failures (e.g. connection reset): retry later.
      throw const SyncRemoteException(
        SyncFailureKind.network,
        'Request failed',
      );
    }
  }

  /// Maps PostgreSQL / PostgREST error codes to a retry decision.
  static SyncFailureKind classifyPostgrestCode(String? code) {
    if (code == null) return SyncFailureKind.network;
    // Session missing/expired or not allowed.
    if (code == '28000' ||
        code == 'PGRST301' ||
        code == 'PGRST302' ||
        code == '42501') {
      return SyncFailureKind.unauthorized;
    }
    // Unique violation: a concurrent duplicate delivery; retry returns the
    // stored result.
    if (code == '23505') return SyncFailureKind.network;
    // Integrity / data errors: retrying the same data will not help.
    if (code.startsWith('22') || code.startsWith('23')) {
      return SyncFailureKind.rejected;
    }
    // Server or connection class errors.
    if (code.startsWith('08') ||
        code.startsWith('53') ||
        code.startsWith('57')) {
      return SyncFailureKind.network;
    }
    return SyncFailureKind.rejected;
  }
}
