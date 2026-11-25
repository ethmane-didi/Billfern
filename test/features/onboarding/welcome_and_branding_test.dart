import 'dart:io';

import 'package:billfern/app.dart';
import 'package:billfern/core/constants/brand_assets.dart';
import 'package:billfern/core/router/app_destination.dart';
import 'package:billfern/features/dashboard/presentation/widgets/dashboard_header.dart';
import 'package:billfern/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:billfern/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:billfern/shared/data/app_preference_store.dart';
import 'package:billfern/shared/providers/subscription_providers.dart';
import 'package:billfern/shared/widgets/billfern_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_harness.dart';

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(BillfernApp)));

void main() {
  group('first launch', () {
    testWidgets('shows the welcome screen with the Billfern logo', (
      tester,
    ) async {
      await pumpBillfern(tester, onboarded: false);

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.byType(BillfernLogo), findsOneWidget);
      expect(find.bySemanticsLabel('Billfern logo'), findsOneWidget);
      expect(find.text('Track smarter. Spend less.'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('get started completes onboarding and persists it', (
      tester,
    ) async {
      await pumpBillfern(tester, onboarded: false);

      await tapVisible(tester, find.text('Get started'));
      expect(find.byType(WelcomeScreen), findsNothing);
      expect(find.text('Start tracking'), findsOneWidget);

      final container = _container(tester);
      expect(container.read(onboardingCompletedProvider), isTrue);
      expect(
        container
            .read(appPreferenceStoreProvider)
            .read(PreferenceKeys.onboardingCompleted),
        'true',
      );
      expect(container.read(dataModeProvider), DataMode.personal);
    });

    testWidgets('can start with sample data', (tester) async {
      await pumpBillfern(tester, onboarded: false);

      await tapVisible(tester, find.text('Explore with sample data'));
      expect(find.text('Sample data · changes are not saved'), findsOneWidget);
      expect(_container(tester).read(dataModeProvider), DataMode.sample);
    });

    testWidgets('onboarded users never see the welcome screen', (tester) async {
      await pumpBillfern(tester);
      expect(find.byType(WelcomeScreen), findsNothing);
      expect(find.text('Start tracking'), findsOneWidget);
    });

    testWidgets('resetting onboarding shows the welcome screen again', (
      tester,
    ) async {
      await pumpBillfern(tester);
      await _container(tester)
          .read(onboardingCompletedProvider.notifier)
          .reset();
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });
  });

  group('branding', () {
    testWidgets('the dashboard header uses the official logo', (tester) async {
      await pumpBillfern(tester);
      expect(
        find.descendant(
          of: find.byType(DashboardHeader),
          matching: find.byType(BillfernLogo),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Billfern'), findsOneWidget);
    });

    testWidgets('settings shows an About section with the logo', (
      tester,
    ) async {
      await pumpBillfern(tester);
      await openTab(tester, AppDestination.settings);
      expect(find.text('ABOUT'), findsOneWidget);
      expect(find.byType(BillfernLogo), findsOneWidget);
      expect(
        find.textContaining('trademarks of their respective owners'),
        findsOneWidget,
      );
    });

    testWidgets('BillfernLogo preserves the aspect ratio', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Center(child: BillfernLogo(size: 120))),
      );
      final size = tester.getSize(find.byType(BillfernLogo));
      expect(size.width, 120);
      expect(size.height, 120 / BrandAssets.logoAspectRatio);
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.contain);
    });

    test('brand asset is registered and separate from service logos', () {
      expect(File(BrandAssets.logo).existsSync(), isTrue);
      expect(BrandAssets.logo, startsWith('assets/branding/'));
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('- assets/branding/'));
      expect(
        Directory('assets/logos').listSync().map((f) => f.path),
        isNot(contains(contains('billfern'))),
      );
    });
  });
}
