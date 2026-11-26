import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/router/app_destination.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/providers/local_store_providers.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/buttons/secondary_button.dart';
import '../../../../shared/widgets/confirmation_sheet.dart';
import '../../../sync/domain/sync_models.dart';
import '../../../sync/presentation/providers/sync_providers.dart';
import '../../../sync/presentation/widgets/sync_status_badge.dart';
import '../../domain/auth_models.dart';
import '../providers/account_providers.dart';
import 'account_scaffold.dart';

/// Settings → Account & sync.
class AccountSyncSection extends ConsumerWidget {
  const AccountSyncSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(authControllerProvider);
    return switch (status) {
      AuthUnavailable() => const _InfoCard(
        icon: LucideIcons.smartphone,
        title: 'On this device only',
        message:
            'Cloud backup and sync are not available in this version. Your '
            'subscriptions are stored only on this device.',
      ),
      SignedOut(:final sessionExpired) => _GuestCard(
        sessionExpired: sessionExpired,
      ),
      SignedIn(:final user) => _AccountCard(user: user),
    };
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.message,
    this.children = const [],
  });

  final IconData icon;
  final String title;
  final String message;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: AppSizes.subscriptionIconSm,
                height: AppSizes.subscriptionIconSm,
                decoration: const BoxDecoration(
                  color: AppColors.lavender,
                  borderRadius: AppRadius.smAll,
                ),
                child: Icon(
                  icon,
                  size: AppSizes.iconSm,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Semantics(
                  container: true,
                  header: true,
                  child: Text(title, style: AppTypography.titleSmall),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(message, style: AppTypography.bodySmall),
          ...children,
        ],
      ),
    );
  }
}

class _GuestCard extends ConsumerWidget {
  const _GuestCard({required this.sessionExpired});

  final bool sessionExpired;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void open({required bool create}) {
      ref.read(authControllerProvider.notifier).acknowledgeExpiry();
      context.push(
        AppRoutes.signIn(
          createAccount: create,
          returnTo: AppDestination.settings.path,
        ),
      );
    }

    return _InfoCard(
      icon: LucideIcons.smartphone,
      title: 'Using Billfern without an account',
      message:
          'Your subscriptions are stored only on this device. Create a free '
          'account to back them up and sync them across your devices. '
          'Nothing is uploaded without your permission.',
      children: [
        if (sessionExpired) ...[
          const SizedBox(height: AppSpacing.sm),
          const FormErrorText(
            'Your session ended. Sign in again to keep syncing. Changes you '
            'made are still on this device.',
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        PrimaryButton(
          label: 'Create account',
          icon: LucideIcons.userPlus,
          onPressed: () => open(create: true),
        ),
        const SizedBox(height: AppSpacing.xs),
        SecondaryButton(label: 'Sign in', onPressed: () => open(create: false)),
      ],
    );
  }
}

class _AccountCard extends ConsumerWidget {
  const _AccountCard({required this.user});

  final AccountUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncControllerProvider);
    final conflicts = ref.watch(syncConflictsProvider).value ?? const [];
    final migration = ref.watch(guestMigrationProvider).value;
    final syncing = sync.phase == SyncPhase.syncing;
    final lastSynced = sync.lastSyncedAt;
    final canRetry =
        sync.phase == SyncPhase.failed || sync.phase == SyncPhase.offline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InfoCard(
          icon: LucideIcons.cloud,
          title: user.email.isEmpty ? 'Signed in' : user.email,
          message:
              'Your subscriptions are saved on this device first and backed '
              'up to your account. Only you can access them.',
          children: [
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: SyncStatusBadge(status: sync),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              lastSynced == null
                  ? 'Not synced yet'
                  : 'Last synced ${DateFormat.MMMd().add_jm().format(lastSynced.toLocal())}',
              style: AppTypography.caption,
            ),
            if (sync.pendingCount > 0) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '${sync.pendingCount} pending '
                '${sync.pendingCount == 1 ? 'change' : 'changes'}',
                style: AppTypography.caption,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            SecondaryButton(
              label: canRetry ? 'Retry sync' : 'Sync now',
              icon: LucideIcons.refreshCw,
              isLoading: syncing,
              onPressed: syncing
                  ? null
                  : () => ref
                        .read(syncControllerProvider.notifier)
                        .sync(manual: true),
            ),
          ],
        ),
        if (migration is GuestMigrationNeeded) ...[
          const SizedBox(height: AppSpacing.sm),
          _InfoCard(
            icon: LucideIcons.cloudUpload,
            title: 'Subscriptions from before you signed in',
            message:
                '${migration.summary.total} subscriptions are only on this '
                'device. Choose whether to add them to your account.',
            children: [
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: 'Review',
                onPressed: () => context.push(AppRoutes.importGuestData),
              ),
            ],
          ),
        ],
        for (final conflict in conflicts) ...[
          const SizedBox(height: AppSpacing.sm),
          _ConflictCard(conflict: conflict),
        ],
        const SizedBox(height: AppSpacing.sm),
        SecondaryButton(
          label: 'Sign out',
          icon: LucideIcons.logOut,
          onPressed: () => _signOut(context, ref, sync),
        ),
        const SizedBox(height: AppSpacing.xs),
        LinkButton(
          label: 'Delete account',
          onPressed: () => _deleteAccount(context, ref),
        ),
      ],
    );
  }

  Future<void> _signOut(
    BuildContext context,
    WidgetRef ref,
    SyncStatus sync,
  ) async {
    final unsynced = sync.pendingCount + sync.conflictCount;
    final confirmed = await showConfirmationSheet(
      context,
      title: 'Sign out?',
      message: unsynced > 0
          ? '$unsynced ${unsynced == 1 ? 'change has' : 'changes have'} not '
                'synced yet. They are kept on this device and sync when you '
                'sign in again. Your account data is hidden until then.'
          : 'Your account data is hidden on this device until you sign in '
                'again. You can keep using Billfern without an account.',
      confirmLabel: unsynced > 0 ? 'Sign out anyway' : 'Sign out',
    );
    if (!confirmed) return;
    await ref.read(authControllerProvider.notifier).signOut();
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => const _DeleteAccountSheet(),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(authControllerProvider.notifier).deleteAccount();
    } on AuthFailure catch (failure) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Account not deleted. ${failure.message}')),
      );
    }
  }
}

class _ConflictCard extends ConsumerWidget {
  const _ConflictCard({required this.conflict});

  final SyncConflict conflict;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(activeLocalStoreProvider);
    final local = store?.subscriptions.find(conflict.subscriptionId);
    final remote = conflict.remote;
    final name = local?.name ?? remote?.subscription?.name ?? 'A subscription';
    final message = switch ((local, remote)) {
      (_, null) =>
        'It was permanently removed from your account on another device.',
      (null, _) => 'You deleted it here, but it changed on another device.',
      (_, final r?) when r.isDeleted =>
        'You changed it here, but it was deleted on another device.',
      _ => 'It was changed both here and on another device.',
    };
    final notifier = ref.read(syncControllerProvider.notifier);

    return _InfoCard(
      icon: LucideIcons.gitCompare,
      title: '$name needs your decision',
      message: '$message Nothing changes until you choose.',
      children: [
        const SizedBox(height: AppSpacing.md),
        PrimaryButton(
          label: local == null
              ? 'Keep it deleted'
              : (remote?.isDeleted ?? true)
              ? 'Restore my version'
              : 'Keep this device\'s version',
          onPressed: () => notifier.resolveConflict(
            conflict.subscriptionId,
            ConflictChoice.keepThisDevice,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SecondaryButton(
          label: remote == null || remote.isDeleted
              ? 'Accept the deletion'
              : 'Use the other device\'s version',
          onPressed: () => notifier.resolveConflict(
            conflict.subscriptionId,
            ConflictChoice.useCloud,
          ),
        ),
      ],
    );
  }
}

class _DeleteAccountSheet extends StatefulWidget {
  const _DeleteAccountSheet();

  static const String phrase = 'DELETE';

  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matches =
        _controller.text.trim().toUpperCase() == _DeleteAccountSheet.phrase;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        0,
        AppSpacing.screenHorizontal,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            header: true,
            child: Text(
              'Delete your account?',
              style: AppTypography.sectionTitle,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'This permanently deletes your account and everything stored in '
            'it: subscriptions, history, preferences and pending changes. '
            'The account\'s data on this device is erased too. This cannot '
            'be undone. Backups kept by our database provider expire on '
            'their own schedule.\n\nTo keep using Billfern without an '
            'account, sign out instead.',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            autocorrect: false,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Type DELETE to confirm',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Delete account permanently',
            onPressed: matches ? () => Navigator.of(context).pop(true) : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}

/// Settings → Data on this device: explicitly confirmed local reset.
class LocalDataSection extends ConsumerWidget {
  const LocalDataSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(currentAccountProvider) != null;
    final sync = ref.watch(syncControllerProvider);
    return _InfoCard(
      icon: LucideIcons.hardDrive,
      title: 'Data on this device',
      message: signedIn
          ? 'Erasing removes this device\'s copy. Your account keeps its '
                'data and downloads it again.'
          : 'Erasing permanently deletes the subscriptions and spending '
                'history stored on this device.',
      children: [
        const SizedBox(height: AppSpacing.md),
        SecondaryButton(
          label: 'Erase data on this device',
          icon: LucideIcons.trash2,
          onPressed: () async {
            final pending = sync.pendingCount + sync.conflictCount;
            final confirmed = await showConfirmationSheet(
              context,
              title: 'Erase data on this device?',
              message: signedIn
                  ? (pending > 0
                        ? '$pending unsynced '
                              '${pending == 1 ? 'change' : 'changes'} will be '
                              'lost. Your account\'s synced data is kept.'
                        : 'Your account\'s synced data is kept and downloads '
                              'again.')
                  : 'All subscriptions and spending history on this device '
                        'are permanently deleted. This cannot be undone.',
              confirmLabel: 'Erase',
              destructive: true,
            );
            if (!confirmed) return;
            await ref.read(authControllerProvider.notifier).eraseThisDevice();
          },
        ),
      ],
    );
  }
}
