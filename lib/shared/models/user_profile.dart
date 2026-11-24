import 'package:flutter/widgets.dart';

/// The signed-in user. Mocked until authentication lands.
@immutable
class UserProfile {
  const UserProfile({required this.firstName, required this.lastName});

  final String firstName;
  final String lastName;

  String get initials =>
      '${firstName.characters.first}${lastName.characters.first}'.toUpperCase();
}
