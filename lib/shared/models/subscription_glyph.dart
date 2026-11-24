import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Icons a user can pick for a custom subscription that has no brand logo.
///
/// The enum [name] is the persisted key, so never rename existing values.
enum SubscriptionGlyph {
  sparkles(LucideIcons.sparkles),
  tv(LucideIcons.tv),
  music(LucideIcons.music),
  cloud(LucideIcons.cloud),
  briefcase(LucideIcons.briefcase),
  code(LucideIcons.code),
  gamepad(LucideIcons.gamepad2),
  dumbbell(LucideIcons.dumbbell),
  bookOpen(LucideIcons.bookOpen),
  shield(LucideIcons.shieldCheck),
  newspaper(LucideIcons.newspaper),
  car(LucideIcons.car),
  home(LucideIcons.house),
  phone(LucideIcons.smartphone),
  wifi(LucideIcons.wifi),
  creditCard(LucideIcons.creditCard);

  const SubscriptionGlyph(this.icon);

  final IconData icon;
}
