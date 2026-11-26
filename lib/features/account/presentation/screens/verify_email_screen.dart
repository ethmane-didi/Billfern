import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../onboarding/presentation/providers/onboarding_providers.dart';
import '../../domain/auth_models.dart';
import '../providers/account_providers.dart';
import '../widgets/account_scaffold.dart';
import 'sign_in_screen.dart';

/// Enter the verification code (6–10 digits) emailed to the user. Verifying the code proves
/// ownership of the email address and starts the session.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, required this.args});

  final VerifyEmailArgs args;

  /// Minimum wait between resends (Supabase also rate-limits emails).
  static const Duration resendCooldown = Duration(seconds: 60);

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _code = TextEditingController();
  bool _verifying = false;
  bool _resending = false;
  String? _error;
  String? _notice;
  Timer? _timer;
  int _secondsLeft = VerifyEmailScreen.resendCooldown.inSeconds;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _secondsLeft = VerifyEmailScreen.resendCooldown.inSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (!isPlausibleCode(code)) {
      setState(() => _error = 'Enter the verification code from the email.');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
      _notice = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .verifyCode(widget.args.email, code);
      if (!ref.read(onboardingCompletedProvider)) {
        await ref.read(onboardingCompletedProvider.notifier).complete();
      }
      final migration = await ref.read(guestMigrationProvider.future);
      if (!mounted) return;
      if (migration is GuestMigrationNeeded) {
        context.go(AppRoutes.importGuestData);
      } else {
        context.go(widget.args.returnTo ?? '/');
      }
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
      _notice = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .requestCode(
            widget.args.email,
            createAccount: widget.args.createAccount,
          );
      if (!mounted) return;
      setState(() => _notice = 'A new code is on its way.');
      _startCooldown();
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    final notice = _notice;
    final canResend = _secondsLeft <= 0 && !_resending && !_verifying;

    return AccountScaffold(
      title: 'Verify email',
      icon: LucideIcons.mailCheck,
      onBack: () => context.canPop() ? context.pop() : context.go('/'),
      heading: 'Check your email',
      message:
          'Enter the verification code we sent to ${widget.args.email}. Codes '
          'expire after a short time.',
      children: [
        TextField(
          controller: _code,
          enabled: !_verifying,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          // Accepts typed digits or a pasted code (or email line).
          inputFormatters: const [_OtpCodeFormatter()],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _verify(),
          style: AppTypography.amountSmall,
          decoration: InputDecoration(
            labelText: 'Verification code',
            labelStyle: AppTypography.bodyMedium.copyWith(
              color: AppColors.textMuted,
            ),
            hintText: '12345678',
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          FormErrorText(error),
        ],
        if (notice != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            container: true,
            liveRegion: true,
            child: Text(notice, style: AppTypography.bodySmall),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Verify and continue',
          icon: LucideIcons.check,
          isLoading: _verifying,
          onPressed: _verifying ? null : _verify,
        ),
        const SizedBox(height: AppSpacing.md),
        LinkButton(
          label: _secondsLeft > 0
              ? 'Resend code in ${_secondsLeft}s'
              : 'Resend code',
          onPressed: canResend ? _resend : null,
        ),
        LinkButton(
          label: 'Use a different email',
          onPressed: _verifying
              ? null
              : () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ],
    );
  }
}

/// Keeps only the code: digits, at most [OtpCode.maxLength]. A pasted
/// message ("Your code: 0123 4567") becomes the code it contains. Leading
/// zeros are kept.
class _OtpCodeFormatter extends TextInputFormatter {
  const _OtpCodeFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final code = OtpCode.normalize(newValue.text);
    if (code == newValue.text) return newValue;
    return TextEditingValue(
      text: code,
      selection: TextSelection.collapsed(offset: code.length),
    );
  }
}
