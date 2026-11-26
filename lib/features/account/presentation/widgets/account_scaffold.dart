import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/theme.dart';
import '../../../../shared/widgets/gradient_scaffold.dart';
import '../../../../shared/widgets/screen_header.dart';

/// Layout shared by the account screens: gradient background, back button,
/// an icon tile, title, explanation and content, centred on wide screens.
class AccountScaffold extends StatelessWidget {
  const AccountScaffold({
    super.key,
    required this.title,
    required this.icon,
    required this.heading,
    required this.message,
    required this.children,
    this.onBack,
  });

  final String title;
  final IconData icon;
  final String heading;
  final String message;
  final List<Widget> children;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return GradientScaffold(
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final inset = math.max(
              AppSpacing.screenHorizontal,
              (constraints.maxWidth - AppSizes.contentMaxWidth) / 2,
            );
            return ListView(
              padding: EdgeInsets.fromLTRB(
                inset,
                AppSpacing.xs,
                inset,
                bottomInset + AppSpacing.xl,
              ),
              children: [
                ScreenHeader(title: title, onBack: onBack),
                const SizedBox(height: AppSpacing.xl),
                ExcludeSemantics(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: AppSizes.illustrationTile,
                      height: AppSizes.illustrationTile,
                      decoration: const BoxDecoration(
                        gradient: AppGradients.accent,
                        borderRadius: AppRadius.lgAll,
                      ),
                      child: Icon(
                        icon,
                        size: AppSizes.iconXl,
                        color: AppColors.textOnAccent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Semantics(
                  container: true,
                  header: true,
                  child: Text(heading, style: AppTypography.headlineMedium),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                ...children,
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Inline error message (announced by screen readers).
class FormErrorText extends StatelessWidget {
  const FormErrorText(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.xxs / 2),
            child: Icon(
              LucideIcons.circleAlert,
              size: AppSizes.iconSm,
              color: AppColors.dangerStrong,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.dangerStrong,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small text link button (48 px tap target).
class LinkButton extends StatelessWidget {
  const LinkButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTypography.labelLarge.copyWith(
                color: enabled ? AppColors.textPrimary : AppColors.textMuted,
                decoration: enabled ? TextDecoration.underline : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
