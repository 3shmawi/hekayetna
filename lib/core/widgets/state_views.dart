import 'package:family_stories/core/adaptive/adaptive.dart';
import 'package:family_stories/core/network/app_failure.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_text_styles.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Loading / empty / error views every screen uses, so the states look the
/// same across the app (CLAUDE.md → every screen has all states).
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator.adaptive());
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    required this.message,
    this.title,
    this.actionLabel,
    this.onAction,
    this.icon,
    super.key,
  });

  /// One short line above the suggestion.
  final String? title;

  /// One sentence that suggests what to do (with a real example).
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return _CenteredMessage(
      icon: icon ?? AdaptiveIcons.empty(context),
      title: title,
      message: message,
      tint: Theme.of(context).colorScheme.primaryContainer,
      action: actionLabel == null
          ? null
          : AdaptiveButton(onPressed: onAction, child: Text(actionLabel!)),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({required this.failure, this.onRetry, super.key});

  final AppFailure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return _CenteredMessage(
      icon: failure is NetworkFailure
          ? AdaptiveIcons.offline(context)
          : AdaptiveIcons.problem(context),
      message: failure.message(context.l10n),
      tint: Theme.of(context).colorScheme.errorContainer,
      action: onRetry == null
          ? null
          : AdaptiveButton(onPressed: onRetry, child: Text(context.l10n.retry)),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.message,
    required this.tint,
    this.title,
    this.action,
  });

  final IconData icon;
  final String? title;
  final String message;

  /// The icon sits on a tint circle (olive for empty, error for failure).
  final Color tint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppDimens.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: AppDimens.playButton,
              height: AppDimens.playButton,
              decoration: BoxDecoration(shape: BoxShape.circle, color: tint),
              child: Icon(icon, size: AppDimens.iconMd * 1.5),
            ),
            SizedBox(height: AppDimens.lg),
            if (title != null) ...[
              Text(
                title!,
                style: AppTextStyles.title,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppDimens.sm),
            ],
            Text(
              message,
              style: AppTextStyles.body.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[SizedBox(height: AppDimens.xl), action!],
          ],
        ),
      ),
    );
  }
}

/// User-facing message for a failure, in the current language.
extension AppFailureMessage on AppFailure {
  String message(AppLocalizations l10n) => switch (this) {
    NetworkFailure() => l10n.errorNetwork,
    TimeoutFailure() => l10n.errorTimeout,
    UnauthorizedFailure() => l10n.errorUnauthorized,
    NotFoundFailure() => l10n.errorNotFound,
    ValidationFailure() => l10n.errorValidation,
    ServerFailure() || UnknownFailure() => l10n.errorUnknown,
    AuthFailure(:final reason) => switch (reason) {
      AuthFailureReason.invalidCredentials => l10n.authErrorInvalidCredentials,
      AuthFailureReason.emailInUse => l10n.authErrorEmailInUse,
      AuthFailureReason.weakPassword => l10n.authErrorWeakPassword,
      AuthFailureReason.invalidEmail => l10n.authErrorInvalidEmail,
      AuthFailureReason.emailNotConfirmed => l10n.authErrorEmailNotConfirmed,
      AuthFailureReason.recentLoginRequired => l10n.authErrorRecentLogin,
      AuthFailureReason.cancelled => '',
      AuthFailureReason.notConfigured => l10n.authErrorNotConfigured,
    },
  };
}
