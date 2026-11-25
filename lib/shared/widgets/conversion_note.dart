import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/theme.dart';

/// Small caption explaining how a converted total was produced: an estimate
/// (mock or live rates), stale rates, or subscriptions left out because no
/// rate was available. Renders nothing when no conversion was involved.
class ConversionNote extends StatelessWidget {
  const ConversionNote({
    super.key,
    required this.isEstimate,
    required this.usesMockRates,
    required this.ratesAreStale,
    this.excludedCount = 0,
    this.missingCurrencies = const {},
    this.textAlign = TextAlign.start,
  });

  final bool isEstimate;
  final bool usesMockRates;
  final bool ratesAreStale;
  final int excludedCount;
  final Set<String> missingCurrencies;
  final TextAlign textAlign;

  /// The note text, or `null` when there is nothing to explain.
  static String? describe({
    required bool isEstimate,
    required bool usesMockRates,
    required bool ratesAreStale,
    int excludedCount = 0,
    Set<String> missingCurrencies = const {},
  }) {
    final parts = <String>[];
    if (isEstimate) {
      parts.add(
        usesMockRates
            ? 'Estimate · mock exchange rates'
            : (ratesAreStale
                  ? 'Estimate · rates may be outdated'
                  : 'Estimate · converted'),
      );
    }
    if (excludedCount > 0) {
      final codes = (missingCurrencies.toList()..sort()).join(', ');
      parts.add(
        'Excludes $excludedCount '
        '${excludedCount == 1 ? 'subscription' : 'subscriptions'} in $codes '
        '(no rate)',
      );
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final text = describe(
      isEstimate: isEstimate,
      usesMockRates: usesMockRates,
      ratesAreStale: ratesAreStale,
      excludedCount: excludedCount,
      missingCurrencies: missingCurrencies,
    );
    if (text == null) return const SizedBox.shrink();
    final warning = excludedCount > 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          warning ? LucideIcons.triangleAlert : LucideIcons.info,
          size: AppSizes.iconXs,
          color: warning ? AppColors.dangerStrong : AppColors.textMuted,
        ),
        const SizedBox(width: AppSpacing.xxs),
        Flexible(
          child: Text(
            text,
            textAlign: textAlign,
            style: AppTypography.caption.copyWith(
              color: warning ? AppColors.dangerStrong : AppColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}
