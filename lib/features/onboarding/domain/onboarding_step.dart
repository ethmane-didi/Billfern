/// Steps of first-launch onboarding, in order.
///
/// Only [welcome] exists today. Future steps (display currency, reminder
/// permission, account) are added here and routed by `OnboardingFlow`, so
/// the router keeps a single "is onboarding complete?" gate.
enum OnboardingStep {
  welcome('/welcome');

  const OnboardingStep(this.path);

  /// Top-level route of the step (outside the tab shell).
  final String path;

  static OnboardingStep get first => values.first;

  /// Whether [location] belongs to onboarding.
  static bool isOnboardingLocation(String location) =>
      values.any((step) => location == step.path);
}
