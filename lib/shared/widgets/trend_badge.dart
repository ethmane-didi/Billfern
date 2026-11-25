import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/theme.dart';
import '../../core/utils/currency_formatter.dart';

/// Pill showing a spending change, e.g. "↘ −8.2% vs last month".
///
/// For spending, a decrease is good (mint) and an increase is bad (coral).
class TrendBadge extends StatelessWidget {
  const TrendBadge({
    super.key,
    required this.changePercent,
    this.label,
    this.onDark = false,
  });

  /// Percentage change; negative means spending went down.
  final double changePercent;

  /// Optional suffix such as "vs last month".
  final String? label;

  /// Use colors tuned for midnight surfaces.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final isDecrease = changePercent < 0;
    final isFlat = changePercent == 0;

    final Color foreground;
    final Color background;
    if (onDark) {
      foreground = isFlat
          ? AppColors.textOnDarkMuted
          : (isDecrease ? AppColors.mint : AppColors.dangerOnDark);
      background = AppColors.overlayOnDark;
    } else {
      foreground = isFlat
          ? AppColors.textMuted
          : (isDecrease ? AppColors.successStrong : AppColors.dangerStrong);
      background = isFlat
          ? AppColors.lavender
          : (isDecrease ? AppColors.mintSoft : AppColors.dangerSoft);
    }

    final icon = isFlat
        ? LucideIcons.minus
        : (isDecrease ? LucideIcons.trendingDown : LucideIcons.trendingUp);
    final percent = CurrencyFormatter.signedPercent(changePercent);
    final text = label == null ? percent : '$percent $label';
    final direction = isFlat ? 'unchanged' : (isDecrease ? 'down' : 'up');
    final semantics =
        'Spending $direction ${changePercent.abs().toStringAsFixed(1)} percent'
        '${label == null ? '' : ' $label'}';

    return Semantics(
      label: semantics,
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
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelMedium.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
