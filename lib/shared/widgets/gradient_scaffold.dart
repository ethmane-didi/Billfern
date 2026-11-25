import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/theme.dart';

/// Scaffold painted with Billfern's soft pastel gradient and ambient glows.
///
/// Use it as the root of every full-screen page instead of a bare [Scaffold].
/// With [extendBody] the body scrolls behind a floating
/// [bottomNavigationBar]; the scaffold then adds the bar's height to the
/// body's bottom `MediaQuery` padding so content can clear it.
class GradientScaffold extends StatelessWidget {
  const GradientScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.extendBody = false,
    this.gradient = AppGradients.background,
    this.showAmbientGlow = true,
    this.resizeToAvoidBottomInset = true,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool extendBody;
  final Gradient gradient;
  final bool showAmbientGlow;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: AppColors.transparent,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: gradient),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (showAmbientGlow) const _AmbientGlow(),
            Scaffold(
              backgroundColor: AppColors.transparent,
              extendBody: extendBody,
              resizeToAvoidBottomInset: resizeToAvoidBottomInset,
              appBar: appBar,
              body: body,
              bottomNavigationBar: bottomNavigationBar,
              floatingActionButton: floatingActionButton,
            ),
          ],
        ),
      ),
    );
  }
}

/// Two large, blurred-looking radial glows that give the background depth.
class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow();

  static const double _primarySize = 360;
  static const double _secondarySize = 300;

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -_primarySize * 0.35,
            right: -_primarySize * 0.3,
            child: _GlowCircle(
              size: _primarySize,
              gradient: AppGradients.glowYellow,
            ),
          ),
          Positioned(
            top: _primarySize * 0.9,
            left: -_secondarySize * 0.45,
            child: _GlowCircle(
              size: _secondarySize,
              gradient: AppGradients.glowMint,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.gradient});

  final double size;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient),
      ),
    );
  }
}
