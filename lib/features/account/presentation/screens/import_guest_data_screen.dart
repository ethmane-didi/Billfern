import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/router/app_destination.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/buttons/secondary_button.dart';
import '../../domain/guest_migration.dart';
import '../providers/account_providers.dart';
import '../widgets/account_scaffold.dart';

/// Asks for explicit consent before uploading subscriptions that were
/// tracked on this device without an account.
class ImportGuestDataScreen extends ConsumerStatefulWidget {
  const ImportGuestDataScreen({super.key});

  @override
  ConsumerState<ImportGuestDataScreen> createState() =>
      _ImportGuestDataScreenState();
}

class _ImportGuestDataScreenState extends ConsumerState<ImportGuestDataScreen> {
  bool _busy = false;
  String? _error;

  void _done() => context.go(AppDestination.settings.path);

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) _done();
    } on Object {
      if (mounted) {
        setState(
          () => _error =
              'Your subscriptions could not be copied. Nothing was lost; '
              'please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(guestMigrationProvider);
    final notifier = ref.read(guestMigrationProvider.notifier);
    final summary = switch (state.value) {
      GuestMigrationNeeded(:final summary) => summary,
      _ => null,
    };
    final error = _error;

    return AccountScaffold(
      title: 'Your subscriptions',
      icon: LucideIcons.cloudUpload,
      onBack: _done,
      heading: 'Upload this device\'s subscriptions?',
      message:
          'You tracked subscriptions on this device before signing in. You '
          'choose whether they are copied to your account.',
      children: [
        if (state.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (summary == null) ...[
          Text('There is nothing to upload.', style: AppTypography.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(label: 'Continue', onPressed: _done),
        ] else ...[
          _SummaryCard(summary: summary),
          const SizedBox(height: AppSpacing.md),
          if (summary.accountHasData) ...[
            Text(
              'Your account already has subscriptions. Uploading adds this '
              'device\'s subscriptions next to them. Nothing is removed, and '
              'subscriptions are never combined just because they share a '
              'name.',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (error != null) ...[
            FormErrorText(error),
            const SizedBox(height: AppSpacing.md),
          ],
          PrimaryButton(
            label: summary.accountHasData
                ? 'Add ${summary.total} to my account'
                : 'Upload ${summary.total} and sync',
            icon: LucideIcons.cloudUpload,
            isLoading: _busy,
            onPressed: _busy ? null : () => _run(() async => notifier.merge()),
          ),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            label: 'Keep them on this device only',
            onPressed: _busy ? null : () => _run(notifier.decline),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Either way, the copy on this device is kept. Sample data is '
            'never uploaded.',
            textAlign: TextAlign.center,
            style: AppTypography.caption,
          ),
        ],
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final GuestDataSummary summary;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${summary.currentCount} current'
            '${summary.endedCount > 0 ? ' · ${summary.endedCount} removed (history)' : ''}',
            style: AppTypography.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'What is uploaded: names, plans, amounts and currencies, billing '
            'cycles, renewal dates, categories, notes, reminders, pause '
            'periods and price history. Stored securely in your account; '
            'only you can access it.',
            style: AppTypography.bodySmall,
          ),
        ],
      ),
    );
  }
}
