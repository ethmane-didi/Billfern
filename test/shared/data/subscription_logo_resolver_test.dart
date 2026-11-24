import 'package:billfern/shared/data/subscription_logo_resolver.dart';
import 'package:billfern/shared/models/billing_cycle.dart';
import 'package:billfern/shared/models/subscription.dart';
import 'package:billfern/shared/models/subscription_branding.dart';
import 'package:billfern/shared/models/subscription_catalog_item.dart';
import 'package:billfern/shared/models/subscription_category.dart';
import 'package:billfern/shared/models/subscription_glyph.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _red = Color(0xFFE50914);

SubscriptionCatalogItem _item({String? logo, Color? color = _red}) =>
    SubscriptionCatalogItem(
      id: 'netflix',
      name: 'Netflix',
      domain: 'netflix.com',
      category: SubscriptionCategory.entertainment,
      brandColor: color,
      logoAsset: logo,
    );

Subscription _custom({
  String name = 'Local Gym',
  Color? color,
  SubscriptionGlyph? glyph,
  String? domain,
}) => Subscription(
  id: 'custom',
  name: name,
  plan: 'Monthly',
  priceMinor: 3000,
  currencyCode: 'NOK',
  billingCycle: BillingCycle.monthly,
  category: SubscriptionCategory.health,
  startedOn: DateTime(2026),
  customColor: color,
  customGlyph: glyph,
  websiteDomain: domain,
);

class _FakeRemote implements RemoteLogoProvider {
  @override
  Uri? logoFor(String domain) => Uri.parse('https://logos.example/$domain');
}

void main() {
  const resolver = SubscriptionLogoResolver();

  test('1. bundled SVG wins, with initials as load fallback', () {
    final branding = resolver.forCatalogItem(
      _item(logo: 'assets/logos/netflix.svg'),
    );
    expect(branding.logo, isA<SvgAssetLogo>());
    expect(
      (branding.logo as SvgAssetLogo).assetPath,
      'assets/logos/netflix.svg',
    );
    expect(branding.fallback, isA<InitialsLogo>());
    expect(branding.color, _red);
  });

  test('2. raster assets are supported', () {
    final branding = resolver.forCatalogItem(_item(logo: 'assets/logos/x.png'));
    expect(branding.logo, isA<RasterAssetLogo>());
  });

  test('3. remote provider is consulted only without a bundled logo', () {
    final remote = SubscriptionLogoResolver(remoteProvider: _FakeRemote());
    expect(remote.forCatalogItem(_item()).logo, isA<RemoteLogo>());
    expect(
      remote.forCatalogItem(_item(logo: 'assets/logos/netflix.svg')).logo,
      isA<SvgAssetLogo>(),
    );
    expect(
      (remote.forSubscription(_custom(domain: 'gym.no')).logo as RemoteLogo)
          .url,
      Uri.parse('https://logos.example/gym.no'),
    );
  });

  test('default resolver never produces remote logos (offline)', () {
    expect(resolver.forCatalogItem(_item()).logo, isA<InitialsLogo>());
    expect(
      resolver.forSubscription(_custom(domain: 'gym.no')).logo,
      isA<InitialsLogo>(),
    );
  });

  test('4. falls back to initials in the brand colour when no logo', () {
    final branding = resolver.forCatalogItem(_item());
    expect((branding.logo as InitialsLogo).initials, 'N');
    expect(branding.color, _red);
  });

  test('uses the category colour when the brand colour is unknown', () {
    final branding = resolver.forCatalogItem(_item(color: null));
    expect(branding.color, SubscriptionCategory.entertainment.color);
  });

  test('custom subscriptions use their glyph and colour', () {
    const teal = Color(0xFF00897B);
    final branding = resolver.forSubscription(
      _custom(color: teal, glyph: SubscriptionGlyph.dumbbell),
    );
    expect(branding.color, teal);
    expect((branding.logo as GlyphLogo).icon, SubscriptionGlyph.dumbbell.icon);
  });

  test('catalog branding overrides the subscription name', () {
    final sub = _custom(name: 'netflix family');
    final branding = resolver.forSubscription(
      sub,
      catalogItem: _item(logo: 'assets/logos/netflix.svg'),
    );
    expect(branding.name, 'Netflix');
    expect(branding.logo, isA<SvgAssetLogo>());
  });

  test('names without letters fall back to the category icon', () {
    final branding = resolver.forSubscription(_custom(name: '++ ..'));
    expect((branding.logo as GlyphLogo).icon, SubscriptionCategory.health.icon);
  });

  group('initialsFor', () {
    test('takes up to two words', () {
      expect(SubscriptionLogoResolver.initialsFor('Apple Music'), 'AM');
      expect(
        SubscriptionLogoResolver.initialsFor('Nintendo Switch Online'),
        'NS',
      );
      expect(SubscriptionLogoResolver.initialsFor('Netflix'), 'N');
    });

    test('ignores punctuation and keeps digits and accents', () {
      expect(SubscriptionLogoResolver.initialsFor('TV 2 Play'), 'T2');
      expect(SubscriptionLogoResolver.initialsFor('Disney+'), 'D');
      expect(SubscriptionLogoResolver.initialsFor('1Password'), '1');
      expect(SubscriptionLogoResolver.initialsFor('Ørsted Energi'), 'ØE');
      expect(SubscriptionLogoResolver.initialsFor('  '), '');
    });
  });
}
