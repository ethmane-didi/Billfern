import 'dart:math';

/// RFC 4122 version 4 UUIDs from a cryptographically secure source.
abstract final class Uuid {
  static final Random _random = Random.secure();

  /// A new random UUID, e.g. `3f1c8a52-6c1e-4d7a-9b5e-0c2f4a8d9e17`.
  static String v4([Random? random]) {
    final source = random ?? _random;
    final bytes = List<int>.generate(16, (_) => source.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
    final hex = [
      for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0'),
    ].join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  static final RegExp _pattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );

  /// Whether [value] is a lowercase canonical UUID.
  static bool isValid(String value) => _pattern.hasMatch(value);
}
