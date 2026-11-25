import 'dart:ui';

import 'currency.dart';

/// Suggests a display currency from the device locale.
abstract final class LocaleCurrency {
  static const Set<String> _euroCountries = {
    'AT',
    'BE',
    'CY',
    'DE',
    'EE',
    'ES',
    'FI',
    'FR',
    'GR',
    'HR',
    'IE',
    'IT',
    'LT',
    'LU',
    'LV',
    'MT',
    'NL',
    'PT',
    'SI',
    'SK',
  };

  static const Map<String, String> _byCountry = {
    'US': 'USD',
    'NO': 'NOK',
    'SJ': 'NOK',
    'GB': 'GBP',
    'SE': 'SEK',
    'DK': 'DKK',
    'GL': 'DKK',
    'FO': 'DKK',
    'CH': 'CHF',
    'LI': 'CHF',
    'CA': 'CAD',
    'AU': 'AUD',
  };

  /// Language-only fallbacks for locales without a region.
  static const Map<String, String> _byLanguage = {
    'nb': 'NOK',
    'nn': 'NOK',
    'no': 'NOK',
    'sv': 'SEK',
    'da': 'DKK',
  };

  /// The supported currency for [locale]'s region (or language), falling
  /// back to [Currency.fallback].
  static Currency suggest(Locale locale) {
    final country = locale.countryCode?.toUpperCase();
    final code =
        (country == null
            ? null
            : (_euroCountries.contains(country)
                  ? 'EUR'
                  : _byCountry[country])) ??
        _byLanguage[locale.languageCode.toLowerCase()];
    return code != null && Currency.isSupported(code)
        ? Currency.of(code)
        : Currency.fallback;
  }
}
