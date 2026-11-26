import 'dart:math';

import 'package:billfern/core/config/supabase_config.dart';
import 'package:billfern/core/utils/uuid.dart';
import 'package:billfern/features/account/data/supabase_auth_repository.dart';
import 'package:billfern/features/account/domain/auth_models.dart';
import 'package:billfern/features/sync/data/supabase_sync_remote.dart';
import 'package:billfern/features/sync/domain/profile_sync.dart';
import 'package:billfern/features/sync/domain/sync_models.dart';
import 'package:billfern/features/sync/presentation/widgets/sync_status_badge.dart';
import 'package:billfern/shared/data/subscription_codec.dart';
import 'package:billfern/shared/models/billing_cycle.dart';
import 'package:billfern/shared/models/subscription.dart';
import 'package:billfern/shared/models/subscription_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupabaseConfig', () {
    test('missing or placeholder values mean local-only', () {
      expect(SupabaseConfig.none.isConfigured, isFalse);
      expect(SupabaseConfig.fromEnvironment().isConfigured, isFalse);
      expect(
        const SupabaseConfig(
          url: 'https://your-project-ref.supabase.co',
          publishableKey: 'sb_publishable_your_public_client_key',
        ).isConfigured,
        isFalse,
      );
      expect(
        const SupabaseConfig(
          url: 'not a url',
          publishableKey: 'k',
        ).isConfigured,
        isFalse,
      );
    });

    test('a real URL and publishable key enable sync', () {
      expect(
        const SupabaseConfig(
          url: 'https://abcd1234.supabase.co',
          publishableKey: 'sb_publishable_abc123',
        ).isConfigured,
        isTrue,
      );
    });
  });

  test('UUID v4 format and uniqueness', () {
    final ids = {for (var i = 0; i < 500; i++) Uuid.v4()};
    expect(ids, hasLength(500));
    expect(ids.every(Uuid.isValid), isTrue);
    final fixed = Uuid.v4(Random(1));
    expect(fixed[14], '4');
    expect('89ab'.contains(fixed[19]), isTrue);
  });

  group('wire format', () {
    final sub = Subscription(
      id: 'x',
      name: 'Netflix',
      plan: '',
      priceMinor: 1549,
      currencyCode: 'USD',
      billingCycle: BillingCycle.monthly,
      category: SubscriptionCategory.entertainment,
      startedOn: DateTime(2026, 1, 1),
      createdAt: DateTime(2026, 1, 1, 10, 30),
    );

    test('event timestamps travel as UTC and come back identical', () {
      final wire = SupabaseSyncRemote.toWire(SubscriptionCodec.toMap(sub));
      expect((wire['createdAt']! as String).endsWith('Z'), isTrue);
      final record = SupabaseSyncRemote.recordFromWire({
        'id': 'x',
        'version': 3,
        'serverSequence': 42,
        'deletedAt': null,
        'payload': wire,
      });
      expect(record.subscription, sub);
      expect(record.version, 3);
      expect(record.serverSequence, 42);
    });

    test('tombstones decode as deleted without a subscription', () {
      final record = SupabaseSyncRemote.recordFromWire({
        'id': 'x',
        'version': 4,
        'serverSequence': 43,
        'deletedAt': '2026-11-24T12:00:00+00:00',
        'payload': SubscriptionCodec.toMap(sub),
      });
      expect(record.isDeleted, isTrue);
      expect(record.subscription, isNull);
    });

    test('PostgreSQL errors map to retry decisions', () {
      expect(
        SupabaseSyncRemote.classifyPostgrestCode('28000'),
        SyncFailureKind.unauthorized,
      );
      expect(
        SupabaseSyncRemote.classifyPostgrestCode('PGRST301'),
        SyncFailureKind.unauthorized,
      );
      expect(
        SupabaseSyncRemote.classifyPostgrestCode('23505'),
        SyncFailureKind.network,
      );
      expect(
        SupabaseSyncRemote.classifyPostgrestCode('23514'),
        SyncFailureKind.rejected,
      );
      expect(
        SupabaseSyncRemote.classifyPostgrestCode('22023'),
        SyncFailureKind.rejected,
      );
      expect(
        SupabaseSyncRemote.classifyPostgrestCode('57014'),
        SyncFailureKind.network,
      );
    });
  });

  test('Supabase Auth errors map to user-facing failures', () {
    expect(
      SupabaseAuthRepository.classify('otp_expired', '403'),
      AuthFailureKind.invalidCode,
    );
    expect(
      SupabaseAuthRepository.classify('over_email_send_rate_limit', '429'),
      AuthFailureKind.rateLimited,
    );
    expect(
      SupabaseAuthRepository.classify(null, '429'),
      AuthFailureKind.rateLimited,
    );
    expect(
      SupabaseAuthRepository.classify('otp_disabled', '422'),
      AuthFailureKind.accountNotFound,
    );
    expect(
      SupabaseAuthRepository.classify(null, null),
      AuthFailureKind.offline,
    );
    expect(isPlausibleEmail('a@b.co'), isTrue);
    expect(isPlausibleEmail('nope'), isFalse);
    expect(isPlausibleCode('123456'), isTrue);
    expect(isPlausibleCode('12345'), isFalse);
  });

  group('email verification codes', () {
    test('accept 6 to 10 digits, including 8-digit codes', () {
      expect(isPlausibleCode('123456'), isTrue);
      expect(isPlausibleCode('12345678'), isTrue);
      expect(isPlausibleCode('01234567'), isTrue);
      expect(isPlausibleCode('1234567890'), isTrue);
      expect(isPlausibleCode(' 12345678 '), isTrue);
      expect(isPlausibleCode('12345'), isFalse);
      expect(isPlausibleCode('12345678901'), isFalse);
      expect(isPlausibleCode('1234 5678'), isFalse);
      expect(isPlausibleCode('1234567a'), isFalse);
      expect(isPlausibleCode(''), isFalse);
    });

    test('normalize keeps the whole code and its leading zeros', () {
      expect(OtpCode.normalize('01234567'), '01234567');
      expect(OtpCode.normalize('00012345'), '00012345');
      expect(OtpCode.normalize('0123 4567'), '01234567');
      expect(OtpCode.normalize('0123-4567'), '01234567');
      expect(OtpCode.normalize(' 01234567\n'), '01234567');
    });

    test('normalize extracts a code from pasted email text', () {
      expect(OtpCode.normalize('Your code: 01234567'), '01234567');
      expect(
        OtpCode.normalize('Your code is 0123 4567. It expires in 10 minutes.'),
        '01234567',
      );
    });

    test('normalize limits typed input to the maximum length', () {
      expect(OtpCode.normalize('123456789012'), '1234567890');
      expect(OtpCode.normalize('12ab34'), '1234');
      expect(OtpCode.normalize(''), '');
    });
  });

  group('status wording', () {
    test('never claims success while changes are pending', () {
      const pending = SyncStatus(phase: SyncPhase.synced, pendingCount: 2);
      expect(pending.isFullySynced, isFalse);
      expect(
        syncPhaseLabel(
          const SyncStatus(phase: SyncPhase.pending, pendingCount: 2),
        ),
        '2 changes waiting to sync',
      );
      expect(
        syncPhaseLabel(const SyncStatus(phase: SyncPhase.synced)),
        'Synced',
      );
      expect(
        syncPhaseLabel(
          const SyncStatus(
            phase: SyncPhase.failed,
            error: SyncFailureKind.unauthorized,
          ),
        ),
        'Sync paused · sign in again',
      );
      expect(
        syncPhaseLabel(
          const SyncStatus(phase: SyncPhase.conflict, conflictCount: 1),
        ),
        '1 conflict needs your decision',
      );
    });
  });

  group('display currency sync policy', () {
    const remoteNok = RemoteProfile(displayCurrency: 'NOK', updatedAt: 't1');
    ProfileSyncAction decide(
      String local,
      SyncedProfile? synced,
      RemoteProfile? remote,
    ) => ProfileSyncPolicy.decide(
      localCurrency: local,
      synced: synced,
      remote: remote,
    );

    test('uploads when the cloud has no profile', () {
      expect(decide('USD', null, null), isA<PushCurrency>());
    });

    test('a new device adopts the account currency', () {
      final action = decide('USD', null, remoteNok);
      expect(action, isA<ApplyCurrency>());
      expect((action as ApplyCurrency).currency, 'NOK');
    });

    test('a local change is uploaded', () {
      const synced = SyncedProfile(currency: 'NOK', remoteUpdatedAt: 't1');
      final action = decide('EUR', synced, remoteNok);
      expect((action as PushCurrency).currency, 'EUR');
    });

    test('a change from another device is applied here', () {
      const synced = SyncedProfile(currency: 'USD', remoteUpdatedAt: 't0');
      final action = decide('USD', synced, remoteNok);
      expect((action as ApplyCurrency).currency, 'NOK');
    });

    test('when both changed, the cloud wins deterministically', () {
      const synced = SyncedProfile(currency: 'USD', remoteUpdatedAt: 't0');
      final action = decide('EUR', synced, remoteNok);
      expect((action as ApplyCurrency).currency, 'NOK');
    });

    test('nothing changed: only the baseline is kept', () {
      const synced = SyncedProfile(currency: 'NOK', remoteUpdatedAt: 't1');
      expect(decide('NOK', synced, remoteNok), isA<RecordBaseline>());
    });
  });

  test('cursor text round-trips', () {
    expect(SupabaseSyncRemote.decodeCursor(null), (null, 0));
    expect(
      SupabaseSyncRemote.decodeCursor(
        SupabaseSyncRemote.encodeCursor('9223', 17),
      ),
      ('9223', 17),
    );
    expect(SupabaseSyncRemote.decodeCursor('garbage'), (null, 0));
  });
}
