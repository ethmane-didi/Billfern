import 'package:flutter/widgets.dart';

import '../../core/theme/theme.dart';

/// Fades [child] in while sliding it up slightly the first time it builds.
///
/// [index] staggers siblings: each step delays the start a little. Motion is
/// skipped when the platform asks to reduce animations.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  static const double _offset = AppSpacing.md;
  static const double _staggerFraction = 0.12;
  static const int _maxStaggerSteps = 5;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    final steps = index.clamp(0, _maxStaggerSteps);
    final delay = steps * _staggerFraction;
    final curve = Interval(delay / (1 + delay), 1, curve: AppMotion.emphasized);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.slow * (1 + delay),
      curve: curve,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * _offset),
          child: child,
        ),
      ),
    );
  }
}
