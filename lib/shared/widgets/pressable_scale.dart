import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/theme/theme.dart';

/// Wraps [child] with a subtle press-down scale and light haptic feedback.
///
/// This is the shared tap affordance for Billfern surfaces, replacing the
/// default Material ink ripple. When [onPressed] is null the child is inert.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onPressed,
    this.scale = AppMotion.pressScale,
    this.enableHaptics = true,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final double scale;
  final bool enableHaptics;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed == value) return;
    setState(() => _isPressed = value);
  }

  void _handleTap() {
    if (widget.enableHaptics) HapticFeedback.selectionClick();
    widget.onPressed?.call();
  }

  @override
  void didUpdateWidget(PressableScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onPressed == null) _isPressed = false;
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: isEnabled ? (_) => _setPressed(true) : null,
      onTapUp: isEnabled ? (_) => _setPressed(false) : null,
      onTapCancel: isEnabled ? () => _setPressed(false) : null,
      onTap: isEnabled ? _handleTap : null,
      child: AnimatedScale(
        scale: _isPressed ? widget.scale : 1,
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        child: widget.child,
      ),
    );
  }
}
