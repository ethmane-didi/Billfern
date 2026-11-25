import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';

/// The signed-in user. Mocked until authentication is integrated.
final currentUserProvider = Provider<UserProfile>(
  (ref) => const UserProfile(firstName: 'Alex', lastName: 'Morgan'),
);
