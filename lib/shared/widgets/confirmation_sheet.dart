import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import 'buttons/base_button.dart';
import 'buttons/secondary_button.dart';

/// Asks the user to confirm an action in a bottom sheet. Resolves to `true`
/// only when the confirm button is tapped.
Future<bool> showConfirmationSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    builder: (context) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          0,
          AppSpacing.screenHorizontal,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              container: true,
              header: true,
              child: Text(title, style: AppTypography.sectionTitle),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            BaseButton(
              label: confirmLabel,
              onPressed: () => Navigator.of(context).pop(true),
              backgroundColor: destructive
                  ? AppColors.dangerStrong
                  : AppColors.midnight,
              foregroundColor: AppColors.textOnDark,
              shadows: AppShadows.none,
            ),
            const SizedBox(height: AppSpacing.sm),
            SecondaryButton(
              label: cancelLabel,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    ),
  );
  return confirmed ?? false;
}
