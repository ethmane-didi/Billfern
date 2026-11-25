import 'package:billfern/core/theme/theme.dart';
import 'package:billfern/shared/models/subscription_branding.dart';
import 'package:billfern/shared/widgets/subscription_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../helpers/pump_themed.dart';

void main() {
  testWidgets('renders a bundled SVG mark', (tester) async {
    await tester.pumpThemed(
      const SubscriptionLogo(
        branding: SubscriptionBranding(
          name: 'Spotify',
          color: Color(0xFF1ED760),
          logo: SvgAssetLogo('assets/logos/spotify.svg'),
          fallback: InitialsLogo('S'),
        ),
      ),
    );
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.text('S'), findsNothing);
  });

  testWidgets('falls back to initials when the SVG asset is missing', (
    tester,
  ) async {
    await tester.pumpThemed(
      const SubscriptionLogo(
        branding: SubscriptionBranding(
          name: 'Ghost',
          color: Color(0xFF3693F3),
          logo: SvgAssetLogo('assets/logos/does-not-exist.svg'),
          fallback: InitialsLogo('G'),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('G'), findsOneWidget);
  });

  testWidgets('renders initials and glyph fallbacks', (tester) async {
    await tester.pumpThemed(
      const Row(
        children: [
          SubscriptionLogo(
            branding: SubscriptionBranding(
              name: 'ChatGPT',
              color: Color(0xFF10A37F),
              logo: InitialsLogo('C'),
            ),
          ),
          SubscriptionLogo(
            branding: SubscriptionBranding(
              name: 'Gym',
              color: Color(0xFF00897B),
              logo: GlyphLogo(LucideIcons.dumbbell),
            ),
          ),
        ],
      ),
    );
    expect(find.text('C'), findsOneWidget);
    expect(find.byIcon(LucideIcons.dumbbell), findsOneWidget);
  });

  testWidgets('is decorative unless given a semantic label', (tester) async {
    const branding = SubscriptionBranding(
      name: 'Netflix',
      color: Color(0xFFE50914),
      logo: InitialsLogo('N'),
    );
    await tester.pumpThemed(const SubscriptionLogo(branding: branding));
    expect(find.bySemanticsLabel('Netflix logo'), findsNothing);

    await tester.pumpThemed(
      const SubscriptionLogo(branding: branding, semanticLabel: 'Netflix logo'),
    );
    expect(find.bySemanticsLabel('Netflix logo'), findsOneWidget);
  });

  group('LogoTileColors', () {
    test('tints mid-tone brands and draws the mark in brand colour', () {
      const red = Color(0xFFE50914);
      final colors = LogoTileColors.forBrand(red);
      expect(colors.foreground, red);
      expect(colors.background, isNot(red));
      expect(colors.background.computeLuminance(), greaterThan(0.75));
    });

    test('uses a neutral tile for near-black brands', () {
      final colors = LogoTileColors.forBrand(const Color(0xFF000000));
      expect(colors.background, AppColors.logoTileNeutral);
    });

    test('puts very light brands on a solid tile with a dark mark', () {
      const neon = Color(0xFF00FF84);
      final colors = LogoTileColors.forBrand(neon);
      expect(colors.background, neon);
      expect(colors.foreground, AppColors.midnight);
    });

    test('marks stay distinguishable from their tile', () {
      for (final brand in const [
        Color(0xFFE50914),
        Color(0xFF1ED760),
        Color(0xFFF7B500),
        Color(0xFF000000),
        Color(0xFF00FF84),
        Color(0xFF3693F3),
      ]) {
        final c = LogoTileColors.forBrand(brand);
        expect(
          LogoTileColors.contrastRatio(c.foreground, c.background),
          greaterThan(1.5),
          reason: brand.toString(),
        );
      }
    });
  });
}
