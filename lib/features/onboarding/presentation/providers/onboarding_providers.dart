import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/data/app_preference_store.dart';
import '../../../../shared/providers/subscription_providers.dart';

/// Whether first-launch onboarding has been completed (persisted).
class OnboardingNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref
          .watch(appPreferenceStoreProvider)
          .read(PreferenceKeys.onboardingCompleted) ==
      'true';

  /// Finishes onboarding, optionally starting with sample data.
  Future<void> finish({bool withSampleData = false}) async {
    if (withSampleData) {
      await ref.read(dataModeProvider.notifier).set(DataMode.sample);
    }
    await complete();
  }

  Future<void> complete() async {
    await ref
        .read(appPreferenceStoreProvider)
        .write(PreferenceKeys.onboardingCompleted, 'true');
    state = true;
  }

  /// Shows onboarding again on the next navigation (e.g. from Settings).
  Future<void> reset() async {
    await ref
        .read(appPreferenceStoreProvider)
        .remove(PreferenceKeys.onboardingCompleted);
    state = false;
  }
}

final onboardingCompletedProvider = NotifierProvider<OnboardingNotifier, bool>(
  OnboardingNotifier.new,
);
