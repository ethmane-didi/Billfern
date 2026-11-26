import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../domain/auth_models.dart';
import '../providers/account_providers.dart';
import '../widgets/account_scaffold.dart';

/// Create an account or sign in with an emailed one-time code.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key, this.createAccount = false, this.returnTo});

  /// Whether new accounts may be created for unknown emails.
  final bool createAccount;

  /// Where to go after signing in (defaults to Home).
  final String? returnTo;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  late bool _create = widget.createAccount;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (!isPlausibleEmail(email)) {
      setState(() => _error = AuthFailureKind.invalidEmail.message);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .requestCode(email, createAccount: _create);
      if (!mounted) return;
      context.push(
        AppRoutes.verifyEmail,
        extra: VerifyEmailArgs(
          email: email,
          createAccount: _create,
          returnTo: widget.returnTo,
        ),
      );
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _back() => context.canPop() ? context.pop() : context.go('/');

  @override
  Widget build(BuildContext context) {
    final unavailable = ref.watch(authControllerProvider) is AuthUnavailable;
    final error = _error;

    return AccountScaffold(
      title: _create ? 'Create account' : 'Sign in',
      icon: _create ? LucideIcons.userPlus : LucideIcons.logIn,
      onBack: _back,
      heading: _create ? 'Back up and sync' : 'Welcome back',
      message: _create
          ? 'An account backs up your subscriptions and keeps them in sync '
                'across your devices. Billfern works fully without one.'
          : 'Sign in to sync your subscriptions with this device.',
      children: [
        if (unavailable) ...[
          FormErrorText(AuthFailureKind.notConfigured.message),
        ] else ...[
          TextField(
            controller: _email,
            enabled: !_sending,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _submit(),
            style: AppTypography.bodyMedium,
            decoration: InputDecoration(
              labelText: 'Email',
              labelStyle: AppTypography.bodyMedium.copyWith(
                color: AppColors.textMuted,
              ),
              hintText: 'you@example.com',
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            FormErrorText(error),
          ],
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Email me a code',
            icon: LucideIcons.mail,
            isLoading: _sending,
            onPressed: _sending ? null : _submit,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'We\'ll send a verification code to your email. No password '
            'needed.',
            textAlign: TextAlign.center,
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.md),
          LinkButton(
            label: _create
                ? 'Already have an account? Sign in'
                : 'New to Billfern? Create an account',
            onPressed: _sending
                ? null
                : () => setState(() {
                    _create = !_create;
                    _error = null;
                  }),
          ),
        ],
      ],
    );
  }
}

/// Arguments for [AppRoutes.verifyEmail].
class VerifyEmailArgs {
  const VerifyEmailArgs({
    required this.email,
    required this.createAccount,
    this.returnTo,
  });

  final String email;
  final bool createAccount;
  final String? returnTo;
}
