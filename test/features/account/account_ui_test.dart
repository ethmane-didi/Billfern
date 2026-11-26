import 'package:billfern/app.dart';
import 'package:billfern/core/router/app_destination.dart';
import 'package:billfern/features/account/data/auth_repository.dart';
import 'package:billfern/features/account/presentation/providers/account_providers.dart';
import 'package:billfern/features/account/presentation/screens/import_guest_data_screen.dart';
import 'package:billfern/features/account/presentation/screens/sign_in_screen.dart';
import 'package:billfern/features/account/presentation/screens/verify_email_screen.dart';
import 'package:billfern/features/settings/presentation/screens/settings_screen.dart';
import 'package:billfern/features/sync/presentation/providers/sync_providers.dart';
import 'package:billfern/shared/data/local_store.dart';
import 'package:billfern/shared/models/billing_cycle.dart';
import 'package:billfern/shared/models/subscription.dart';
import 'package:billfern/shared/models/subscription_category.dart';
import 'package:billfern/shared/providers/catalog_providers.dart';
import 'package:billfern/shared/providers/local_store_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fake_cloud.dart';
import '../../helpers/fixed_clock.dart';

const double _dpr = 3;

Subscription _sub(String id) => Subscription(
  id: id,
  name: 'Netflix',
  plan: '',
  priceMinor: 1549,
  currencyCode: 'USD',
  billingCycle: BillingCycle.monthly,
  category: SubscriptionCategory.entertainment,
  startedOn: DateTime(2026, 1, 1),
);

/// Pumps the app wired like `main` with a fake backend.
Future<({FakeAuthRepository auth, FakeCloud cloud})> _pump(
  WidgetTester tester, {
  bool configured = true,
  bool onboarded = true,
  List<Subscription> guestSeed = const [],
  Size size = const Size(393, 1400),
  double textScale = 1,
  String authCode = '123456',
}) async {
  tester.view
    ..physicalSize = size * _dpr
    ..devicePixelRatio = _dpr
    ..padding = const FakeViewPadding(top: 59 * _dpr, bottom: 34 * _dpr)
    ..viewPadding = const FakeViewPadding(top: 59 * _dpr, bottom: 34 * _dpr);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final auth = FakeAuthRepository(validCode: authCode);
  final cloud = FakeCloud();
  final opener = memoryOpener(clock: () => fixedNow);
  final guest = (await tester.runAsync(() async {
    final store = await opener.open(LocalIdentity.guest);
    for (final s in guestSeed) {
      await store.subscriptions.save(s);
    }
    return store;
  }))!;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...baseTestOverrides,
        ...preferenceOverrides(onboarded: onboarded),
        authRepositoryProvider.overrideWithValue(
          configured ? auth : const LocalOnlyAuthRepository(),
        ),
        syncRemoteProvider.overrideWithValue(
          configured ? FakeSyncRemote(cloud) : null,
        ),
        localStoreOpenerProvider.overrideWithValue(opener),
        initialLocalStoreProvider.overrideWithValue(guest),
        syncDebounceProvider.overrideWithValue(Duration.zero),
      ],
      child: const BillfernApp(),
    ),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(BillfernApp)),
  );
  await tester.runAsync(
    () => container.read(subscriptionCatalogProvider.future),
  );
  await tester.pumpAndSettle();
  return (auth: auth, cloud: cloud);
}

/// Scrolls the Settings list (the Home tab's list stays mounted offstage).
Future<void> _scrollSettingsTo(
  WidgetTester tester,
  Finder finder, {
  double delta = 200,
}) async {
  await tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: find
        .descendant(
          of: find.byType(SettingsScreen),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }
}

Future<void> _signIn(
  WidgetTester tester,
  String email, {
  String code = '123456',
}) async {
  await openTab(tester, AppDestination.settings);
  if (find.text('Sign in').evaluate().isEmpty) {
    await _scrollSettingsTo(tester, find.text('Sign in'), delta: -200);
  }
  await tapVisible(tester, find.text('Sign in'));
  expect(find.byType(SignInScreen), findsOneWidget);
  await tester.enterText(find.byType(TextField), email);
  await tapVisible(tester, find.text('Email me a code'));
  await _settle(tester);
  expect(find.byType(VerifyEmailScreen), findsOneWidget);
  await tester.enterText(find.byType(TextField), code);
  await tapVisible(tester, find.text('Verify and continue'));
  await _settle(tester);
}

/// Opens the verification screen for [email] (code requested).
Future<void> _openVerify(WidgetTester tester, String email) async {
  await openTab(tester, AppDestination.settings);
  await tapVisible(tester, find.text('Sign in'));
  await tester.enterText(find.byType(TextField), email);
  await tapVisible(tester, find.text('Email me a code'));
  await _settle(tester);
  expect(find.byType(VerifyEmailScreen), findsOneWidget);
}

String _codeFieldText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

void main() {
  testWidgets('local-only builds explain that data stays on the device', (
    tester,
  ) async {
    await pumpBillfern(tester);
    await openTab(tester, AppDestination.settings);
    await _scrollSettingsTo(tester, find.text('On this device only'));
    expect(find.text('On this device only'), findsOneWidget);
    expect(find.text('Create account'), findsNothing);
  });

  testWidgets('guests see the account explanation and actions', (tester) async {
    await _pump(tester);
    await openTab(tester, AppDestination.settings);
    expect(find.text('Using Billfern without an account'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.textContaining('without your permission'), findsOneWidget);
    expect(find.text('Erase data on this device'), findsOneWidget);
  });

  testWidgets('signing in with an emailed code', (tester) async {
    final fake = await _pump(tester);
    await _signIn(tester, 'alex@example.test');
    expect(fake.auth.requestedEmails, ['alex@example.test']);
    expect(find.text('alex@example.test'), findsOneWidget);
    expect(find.textContaining('Sync status'), findsNothing); // label only
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);
  });

  testWidgets('8-digit codes with leading zeros are verified in full', (
    tester,
  ) async {
    final fake = await _pump(tester, authCode: '01234567');
    await _openVerify(tester, 'alex@example.test');
    expect(
      find.textContaining('Enter the verification code we sent'),
      findsOneWidget,
    );
    expect(find.textContaining('6-digit'), findsNothing);

    await tester.enterText(find.byType(TextField), '01234567');
    expect(_codeFieldText(tester), '01234567');
    await tapVisible(tester, find.text('Verify and continue'));
    await _settle(tester);

    expect(fake.auth.verifiedCodes, ['01234567']);
    expect(find.byType(VerifyEmailScreen), findsNothing);
    await openTab(tester, AppDestination.settings);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('pasting the verification email line enters the whole code', (
    tester,
  ) async {
    final fake = await _pump(tester, authCode: '00987654');
    await _openVerify(tester, 'alex@example.test');

    await tester.enterText(
      find.byType(TextField),
      'Your Billfern code is 0098 7654. It expires in 10 minutes.',
    );
    await tester.pump();
    expect(_codeFieldText(tester), '00987654');
    await tapVisible(tester, find.text('Verify and continue'));
    await _settle(tester);
    expect(fake.auth.verifiedCodes, ['00987654']);
  });

  testWidgets('codes are limited to 10 digits and short codes are refused', (
    tester,
  ) async {
    final fake = await _pump(tester);
    await _openVerify(tester, 'alex@example.test');

    await tester.enterText(find.byType(TextField), '123456789012');
    expect(_codeFieldText(tester), '1234567890');

    await tester.enterText(find.byType(TextField), '12345');
    await tapVisible(tester, find.text('Verify and continue'));
    await tester.pump();
    expect(
      find.text('Enter the verification code from the email.'),
      findsOneWidget,
    );
    expect(fake.auth.verifiedCodes, isEmpty);
  });

  testWidgets('sign-in errors are shown, not swallowed', (tester) async {
    await _pump(tester);
    await openTab(tester, AppDestination.settings);
    await tapVisible(tester, find.text('Sign in'));
    await tester.enterText(find.byType(TextField), 'not-an-email');
    await tapVisible(tester, find.text('Email me a code'));
    expect(find.text('Enter a valid email address.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'nobody@example.test');
    await tapVisible(tester, find.text('Email me a code'));
    await _settle(tester);
    expect(find.textContaining('No account uses that email'), findsOneWidget);

    await tapVisible(tester, find.text('New to Billfern? Create an account'));
    await tapVisible(tester, find.text('Email me a code'));
    await _settle(tester);
    await tester.enterText(find.byType(TextField), '999999');
    await tapVisible(tester, find.text('Verify and continue'));
    await _settle(tester);
    expect(find.textContaining('incorrect or has expired'), findsOneWidget);
    expect(find.textContaining('Resend code in'), findsOneWidget);
  });

  testWidgets('existing guest data needs consent before upload', (
    tester,
  ) async {
    final fake = await _pump(tester, guestSeed: [_sub('n1'), _sub('n2')]);
    await _signIn(tester, 'alex@example.test');
    expect(find.byType(ImportGuestDataScreen), findsOneWidget);
    expect(find.text('2 current'), findsOneWidget);
    expect(find.text('Keep them on this device only'), findsOneWidget);
    expect(fake.cloud.rowCount, 0);

    await tapVisible(tester, find.text('Upload 2 and sync'));
    await _settle(tester);
    expect(find.text('alex@example.test'), findsOneWidget);
    expect(fake.cloud.rowCount, 2);
  });

  testWidgets('account deletion requires typing DELETE', (tester) async {
    final fake = await _pump(tester);
    await _signIn(tester, 'alex@example.test');
    await tapVisible(tester, find.text('Delete account'));
    expect(find.text('Delete your account?'), findsOneWidget);

    await tester.tap(find.text('Delete account permanently'));
    await tester.pumpAndSettle();
    expect(fake.auth.deleteCalls, 0); // disabled until confirmed

    await tester.enterText(find.byType(TextField).last, 'DELETE');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete account permanently'));
    await _settle(tester);
    expect(fake.auth.deleteCalls, 1);
    expect(find.text('Using Billfern without an account'), findsOneWidget);
  });

  testWidgets('offline sync is shown honestly', (tester) async {
    final fake = await _pump(tester);
    fake.cloud.offline = true;
    await _signIn(tester, 'alex@example.test');
    await _settle(tester);
    expect(
      find.text('Offline · changes are saved on this device'),
      findsOneWidget,
    );
    expect(find.text('Synced'), findsNothing);
    expect(find.text('Retry sync'), findsOneWidget);
  });

  testWidgets('the welcome screen offers accounts only when configured', (
    tester,
  ) async {
    await _pump(tester, onboarded: false);
    expect(find.text('Sign in or create an account'), findsOneWidget);
    expect(
      find.text(
        'Your data stays on this device unless you turn on cloud sync.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('new account screens fit small phones at large text', (
    tester,
  ) async {
    await _pump(
      tester,
      guestSeed: [_sub('n1')],
      size: const Size(375, 667),
      textScale: 1.35,
    );
    await openTab(tester, AppDestination.settings);
    await _scrollSettingsTo(tester, find.text('Erase data on this device'));
    expect(tester.takeException(), isNull);
    await _signIn(tester, 'alex@example.test');
    expect(find.byType(ImportGuestDataScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sign-in screen meets tap-target and label guidelines', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    await openTab(tester, AppDestination.settings);
    await tapVisible(tester, find.text('Create account'));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
