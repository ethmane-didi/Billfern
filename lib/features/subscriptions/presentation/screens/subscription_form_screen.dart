import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/money/currency.dart';
import '../../../../core/money/money.dart';
import '../../../../core/money/money_parser.dart';
import '../../../../core/router/app_destination.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_labels.dart';
import '../../../../shared/models/billing_cycle.dart';
import '../../../../shared/models/reminder_preference.dart';
import '../../../../shared/models/subscription.dart';
import '../../../../shared/models/subscription_catalog_item.dart';
import '../../../../shared/models/subscription_category.dart';
import '../../../../shared/providers/catalog_providers.dart';
import '../../../../shared/providers/clock_provider.dart';
import '../../../../shared/providers/currency_providers.dart';
import '../../../../shared/providers/subscription_providers.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/choice_pill.dart';
import '../../../../shared/widgets/coming_soon.dart';
import '../../../../shared/widgets/currency_selector.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/gradient_scaffold.dart';
import '../../../../shared/widgets/pressable_scale.dart';
import '../../../../shared/widgets/screen_header.dart';
import '../../../../shared/widgets/subscription_logo.dart';
import '../../domain/subscription_draft.dart';

enum _FormMode { custom, catalog, edit }

/// Configuration form for adding (from the catalog or custom) or editing a
/// subscription.
class SubscriptionFormScreen extends ConsumerWidget {
  const SubscriptionFormScreen.custom({super.key})
    : _mode = _FormMode.custom,
      catalogId = null,
      subscriptionId = null;

  const SubscriptionFormScreen.catalog({super.key, required this.catalogId})
    : _mode = _FormMode.catalog,
      subscriptionId = null;

  const SubscriptionFormScreen.edit({super.key, required this.subscriptionId})
    : _mode = _FormMode.edit,
      catalogId = null;

  final _FormMode _mode;

  /// Catalog service to pre-fill from (catalog mode).
  final String? catalogId;

  /// Subscription to edit (edit mode).
  final String? subscriptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferred = ref.watch(preferredCurrencyProvider);
    final catalog = ref.watch(subscriptionCatalogProvider);

    Widget body;
    switch (_mode) {
      case _FormMode.custom:
        body = _SubscriptionForm(
          initial: SubscriptionDraft.custom(currencyCode: preferred),
        );
      case _FormMode.catalog:
        body = catalog.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              const _Missing(message: 'The catalog could not load.'),
          data: (catalog) {
            final item = catalog.byId(catalogId);
            if (item == null) {
              return const _Missing(message: 'This service is not available.');
            }
            return _SubscriptionForm(
              catalogItem: item,
              initial: SubscriptionDraft.fromCatalog(
                item,
                currencyCode: preferred,
              ),
            );
          },
        );
      case _FormMode.edit:
        final existing = ref.read(subscriptionByIdProvider(subscriptionId!));
        if (existing == null) {
          body = const _Missing(message: 'This subscription no longer exists.');
        } else {
          body = _SubscriptionForm(
            existing: existing,
            catalogItem: catalog.value?.byId(existing.catalogId),
            initial: SubscriptionDraft.fromSubscription(
              existing,
              today: ref.read(todayProvider),
            ),
          );
        }
    }

    return GradientScaffold(body: SafeArea(bottom: false, child: body));
  }
}

class _Missing extends StatelessWidget {
  const _Missing({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.screenPadding,
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xs),
          ScreenHeader(title: 'Subscription', onBack: () => _leave(context)),
          const SizedBox(height: AppSpacing.xl),
          EmptyStateCard(
            icon: LucideIcons.searchX,
            title: 'Not found',
            message: message,
          ),
        ],
      ),
    );
  }
}

void _leave(BuildContext context) => context.canPop()
    ? context.pop()
    : context.go(AppDestination.subscriptions.path);

class _SubscriptionForm extends ConsumerStatefulWidget {
  const _SubscriptionForm({
    required this.initial,
    this.catalogItem,
    this.existing,
  });

  final SubscriptionDraft initial;
  final SubscriptionCatalogItem? catalogItem;
  final Subscription? existing;

  @override
  ConsumerState<_SubscriptionForm> createState() => _SubscriptionFormState();
}

class _SubscriptionFormState extends ConsumerState<_SubscriptionForm> {
  late SubscriptionDraft _draft = widget.initial;
  late final TextEditingController _name = TextEditingController(
    text: widget.initial.name,
  );
  late final TextEditingController _plan = TextEditingController(
    text: widget.initial.plan,
  );
  late final TextEditingController _amount = TextEditingController(
    text: widget.initial.amountMinor == null
        ? ''
        : MoneyParser.toInput(
            Money(widget.initial.amountMinor!, widget.initial.currencyCode),
          ),
  );
  late final TextEditingController _interval = TextEditingController(
    text: '${widget.initial.billingCycle.count}',
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.initial.notes,
  );
  late final TextEditingController _website = TextEditingController(
    text: widget.initial.website,
  );

  late bool _customCycle =
      widget.initial.billingCycle.kind == BillingCycleKind.custom;
  late BillingUnit _customUnit = widget.initial.billingCycle.unit;
  String? _amountError;
  String? _intervalError;
  bool _showErrors = false;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _plan,
      _amount,
      _interval,
      _notes,
      _website,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _update(SubscriptionDraft draft) => setState(() => _draft = draft);

  void _onAmountChanged(String text) {
    final result = MoneyParser.parse(text, _draft.currencyCode);
    setState(() {
      switch (result) {
        case ParsedMoney(:final money):
          _amountError = null;
          _draft = _draft.copyWith(amountMinor: money.minorUnits);
        case MoneyParseError(:final message):
          _amountError = text.trim().isEmpty ? null : message;
          _draft = _draft.copyWith(clearAmount: true);
      }
    });
  }

  void _onCurrencyChanged(String code) {
    _update(_draft.copyWith(currencyCode: code));
    // Re-parse: precision differs between currencies.
    _onAmountChanged(_amount.text);
  }

  void _setCustomInterval() {
    final count = int.tryParse(_interval.text.trim());
    setState(() {
      if (count == null || count < 1 || count > BillingCycle.maxCount) {
        _intervalError = 'Enter a number from 1 to ${BillingCycle.maxCount}';
      } else {
        _intervalError = null;
        _draft = _draft.copyWith(
          billingCycle: BillingCycle.custom(count, _customUnit),
        );
      }
    });
  }

  Future<void> _pickDate() async {
    final today = ref.read(todayProvider);
    final initial =
        _draft.nextRenewal != null && !_draft.nextRenewal!.isBefore(today)
        ? _draft.nextRenewal!
        : _draft.billingCycle.advance(today, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: DateTime(today.year + 5, today.month, today.day),
      helpText: 'Next renewal date',
    );
    if (picked != null) _update(_draft.copyWith(nextRenewal: picked));
  }

  Future<void> _save() async {
    final today = ref.read(todayProvider);
    final errors = _draft.validate(today: today);
    setState(() => _showErrors = true);
    if (errors.isNotEmpty || _amountError != null || _intervalError != null) {
      return;
    }

    setState(() => _saving = true);
    final subscription = _draft.toSubscription(
      id: ref.read(subscriptionIdGeneratorProvider)(),
      today: today,
      now: ref.read(clockProvider)(),
      existing: widget.existing,
    );
    final notifier = ref.read(subscriptionsProvider.notifier);
    if (_isEdit) {
      await notifier.update(subscription);
    } else {
      await notifier.add(subscription);
    }
    if (!mounted) return;
    if (_isEdit) {
      _leave(context);
    } else {
      context.go(AppRoutes.subscriptionDetails(subscription.id));
    }
    showComingSoon(
      context,
      _isEdit ? 'Changes saved.' : '${subscription.name} added.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    final errors = _showErrors ? _draft.validate(today: today) : const {};
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final branding = ref
        .watch(subscriptionLogoResolverProvider)
        .resolve(
          name: _draft.name.trim().isEmpty ? '?' : _draft.name,
          category: _draft.category,
          catalogItem: widget.catalogItem,
          websiteDomain: SubscriptionDraft.normalizeDomain(_draft.website),
          customColor: _draft.customColor,
          customGlyph: _draft.customGlyph,
        );

    return LayoutBuilder(
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
            ScreenHeader(
              title: _isEdit ? 'Edit subscription' : 'New subscription',
              onBack: () => _leave(context),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Row(
                children: [
                  SubscriptionLogo(
                    branding: branding,
                    size: SubscriptionLogoSize.large,
                    shape: SubscriptionLogoShape.squircle,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _TextInput(
                      label: 'Name',
                      controller: _name,
                      hint: 'e.g. Local gym',
                      error: errors[DraftField.name],
                      maxLength: SubscriptionDraft.maxNameLength,
                      onChanged: (value) =>
                          _update(_draft.copyWith(name: value)),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.catalogItem != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'From the catalog: ${widget.catalogItem!.name} · '
                '${widget.catalogItem!.domain}',
                style: AppTypography.caption,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            _Section(
              label: 'Price',
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _TextInput(
                      label: 'Amount',
                      controller: _amount,
                      hint: '0.00',
                      error: _amountError ?? errors[DraftField.amount],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.,\s]')),
                      ],
                      onChanged: _onAmountChanged,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _CurrencyField(
                    code: _draft.currencyCode,
                    onChanged: _onCurrencyChanged,
                  ),
                ],
              ),
            ),
            _ConvertedHint(draft: _draft),
            const SizedBox(height: AppSpacing.lg),
            _Section(
              label: 'Billing cycle',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.xs,
                    children: [
                      for (final preset in BillingCycle.presets)
                        ChoicePill(
                          label: preset.label,
                          selected:
                              !_customCycle && _draft.billingCycle == preset,
                          onSelected: () {
                            setState(() => _customCycle = false);
                            _update(_draft.copyWith(billingCycle: preset));
                          },
                        ),
                      ChoicePill(
                        label: 'Custom',
                        selected: _customCycle,
                        onSelected: () {
                          setState(() => _customCycle = true);
                          _setCustomInterval();
                        },
                      ),
                    ],
                  ),
                  if (_customCycle) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: AppSizes.numberFieldWidth,
                          child: _TextInput(
                            label: 'Every',
                            controller: _interval,
                            error: _intervalError,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (_) => _setCustomInterval(),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Wrap(
                            spacing: AppSpacing.xs,
                            children: [
                              for (final unit in BillingUnit.values)
                                ChoicePill(
                                  label: unit.plural,
                                  selected: unit == _customUnit,
                                  onSelected: () {
                                    setState(() => _customUnit = unit);
                                    _setCustomInterval();
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _Section(
              label: 'Next renewal',
              child: _DateField(
                date: _draft.nextRenewal,
                error: errors[DraftField.nextRenewal],
                onTap: _pickDate,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _Section(
              label: 'Category',
              child: Wrap(
                spacing: AppSpacing.xs,
                children: [
                  for (final category in SubscriptionCategory.values)
                    ChoicePill(
                      label: category.label,
                      icon: category.icon,
                      selected: category == _draft.category,
                      onSelected: () =>
                          _update(_draft.copyWith(category: category)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _Section(
              label: 'Reminder',
              caption: 'Saved now; notifications arrive in a later update.',
              child: Wrap(
                spacing: AppSpacing.xs,
                children: [
                  for (final reminder in ReminderPreference.values)
                    ChoicePill(
                      label: reminder.label,
                      selected: reminder == _draft.reminder,
                      onSelected: () =>
                          _update(_draft.copyWith(reminder: reminder)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _Section(
              label: 'Details (optional)',
              child: Column(
                children: [
                  _TextInput(
                    label: 'Plan',
                    controller: _plan,
                    hint: 'e.g. Premium',
                    onChanged: (value) => _update(_draft.copyWith(plan: value)),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _TextInput(
                    label: 'Website',
                    controller: _website,
                    hint: 'example.com',
                    error: errors[DraftField.website],
                    keyboardType: TextInputType.url,
                    onChanged: (value) =>
                        _update(_draft.copyWith(website: value)),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _TextInput(
                    label: 'Notes',
                    controller: _notes,
                    hint: 'Shared with family, cancel before trial ends…',
                    error: errors[DraftField.notes],
                    maxLines: 3,
                    maxLength: SubscriptionDraft.maxNotesLength,
                    onChanged: (value) =>
                        _update(_draft.copyWith(notes: value)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (_showErrors &&
                (errors.isNotEmpty ||
                    _amountError != null ||
                    _intervalError != null)) ...[
              Semantics(
                container: true,
                liveRegion: true,
                child: Text(
                  'Check the highlighted fields.',
                  textAlign: TextAlign.center,
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.dangerStrong,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            PrimaryButton(
              label: _isEdit ? 'Save changes' : 'Add subscription',
              icon: _isEdit ? LucideIcons.check : LucideIcons.plus,
              isLoading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child, this.caption});

  final String label;
  final String? caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          container: true,
          header: true,
          child: Text(label, style: AppTypography.titleSmall),
        ),
        if (caption != null) Text(caption!, style: AppTypography.caption),
        const SizedBox(height: AppSpacing.xs),
        child,
      ],
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.hint,
    this.error,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.maxLength,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? hint;
  final String? error;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      maxLength: maxLength,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      style: AppTypography.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textMuted,
        ),
        floatingLabelStyle: AppTypography.labelMedium.copyWith(
          color: AppColors.textPrimary,
        ),
        hintText: hint,
        errorText: error,
        counterText: '',
      ),
    );
  }
}

class _CurrencyField extends ConsumerWidget {
  const _CurrencyField({required this.code, required this.onChanged});

  final String code;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = Currency.of(code);
    return Semantics(
      container: true,
      button: true,
      label: 'Currency, ${currency.name}. Change',
      excludeSemantics: true,
      child: PressableScale(
        onPressed: () async {
          final picked = await showCurrencyPicker(
            context,
            selectedCode: code,
            suggestedCode: ref.read(suggestedCurrencyProvider).code,
            title: 'Subscription currency',
            description:
                'The currency you are charged in. Totals are converted to '
                'your display currency.',
          );
          if (picked != null) onChanged(picked);
        },
        child: Container(
          height: AppSizes.inputHeight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(currency.code, style: AppTypography.labelLarge),
              const SizedBox(width: AppSpacing.xxs),
              const Icon(
                LucideIcons.chevronDown,
                size: AppSizes.iconSm,
                color: AppColors.textPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Live preview of the parsed price ("kr 199.00 per month"), plus the
/// converted monthly estimate when the form currency differs from the
/// display currency. Makes typos such as a misplaced separator obvious.
class _ConvertedHint extends ConsumerWidget {
  const _ConvertedHint({required this.draft});

  final SubscriptionDraft draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amount = draft.amountMinor;
    if (amount == null) return const SizedBox.shrink();
    final converter = ref.watch(moneyConverterProvider);
    final price = Money(amount, draft.currencyCode);
    final parts = <String>[
      '${CurrencyFormatter.format(price)} '
          '${draft.billingCycle.label.toLowerCase()}',
    ];
    if (draft.currencyCode != converter.targetCurrency) {
      final converted = converter.convert(
        draft.billingCycle.monthlyCost(price),
      );
      parts.add(
        converted == null
            ? 'no ${draft.currencyCode} rate, excluded from '
                  '${converter.targetCurrency} totals'
            : '≈ ${CurrencyFormatter.format(converted)}/mo in '
                  '${converter.targetCurrency}'
                  '${converter.usesMockRates ? ' (mock rates)' : ''}',
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs, left: AppSpacing.md),
      child: Text(parts.join(' · '), style: AppTypography.caption),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.onTap, this.error});

  final DateTime? date;
  final VoidCallback onTap;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final date = this.date;
    final text = date == null ? 'Choose a date' : DateLabels.weekdayDate(date);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          container: true,
          button: true,
          label: 'Next renewal date, $text',
          excludeSemantics: true,
          child: PressableScale(
            onPressed: onTap,
            child: Container(
              height: AppSizes.inputHeight,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.mdAll,
                border: Border.all(
                  color: error == null
                      ? AppColors.border
                      : AppColors.dangerStrong,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.calendarDays,
                    size: AppSizes.iconMd,
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      text,
                      style: AppTypography.bodyMedium.copyWith(
                        color: date == null
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.md,
              top: AppSpacing.xxs,
            ),
            child: Text(
              error!,
              style: AppTypography.caption.copyWith(
                color: AppColors.dangerStrong,
              ),
            ),
          ),
      ],
    );
  }
}
