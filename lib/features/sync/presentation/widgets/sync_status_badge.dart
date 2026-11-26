import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/theme.dart';
import '../../domain/sync_models.dart';

/// Plain-language label for a sync phase.
String syncPhaseLabel(SyncStatus status) => switch (status.phase) {
  SyncPhase.localOnly => 'On this device only',
  SyncPhase.offline => 'Offline · changes are saved on this device',
  SyncPhase.syncing => 'Syncing…',
  SyncPhase.synced => 'Synced',
  SyncPhase.pending =>
    '${status.pendingCount} ${status.pendingCount == 1 ? 'change' : 'changes'} waiting to sync',
  SyncPhase.conflict =>
    '${status.conflictCount} ${status.conflictCount == 1 ? 'conflict needs' : 'conflicts need'} your decision',
  SyncPhase.failed => switch (status.error) {
    SyncFailureKind.unauthorized => 'Sync paused · sign in again',
    _ when status.parkedCount > 0 =>
      '${status.parkedCount} ${status.parkedCount == 1 ? 'change was' : 'changes were'} not accepted',
    _ => 'Sync failed · will retry',
  },
};

/// Pill showing the sync phase with an icon and accessible label.
class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({super.key, required this.status});

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, foreground, background) = switch (status.phase) {
      SyncPhase.synced => (
        LucideIcons.cloudCheck,
        AppColors.successStrong,
        AppColors.mintSoft,
      ),
      SyncPhase.syncing => (
        LucideIcons.refreshCw,
        AppColors.textPrimary,
        AppColors.lavender,
      ),
      SyncPhase.pending => (
        LucideIcons.cloudUpload,
        AppColors.textPrimary,
        AppColors.yellowSoft,
      ),
      SyncPhase.offline => (
        LucideIcons.cloudOff,
        AppColors.textMuted,
        AppColors.lavender,
      ),
      SyncPhase.conflict || SyncPhase.failed => (
        LucideIcons.triangleAlert,
        AppColors.dangerStrong,
        AppColors.dangerSoft,
      ),
      SyncPhase.localOnly => (
        LucideIcons.smartphone,
        AppColors.textMuted,
        AppColors.lavender,
      ),
    };
    final label = syncPhaseLabel(status);
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Sync status: $label',
      excludeSemantics: true,
      child: Container(
        padding: AppSpacing.badgePadding,
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppRadius.pillAll,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppSizes.iconXs, color: foreground),
            const SizedBox(width: AppSpacing.xxs),
            Flexible(
              child: Text(
                label,
                style: AppTypography.labelMedium.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
