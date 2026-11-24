import 'package:family_stories/core/adaptive/adaptive.dart';
import 'package:family_stories/core/router/app_routes.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_text_styles.dart';
import 'package:family_stories/core/ui/app_ui.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shown for unknown routes, e.g. an outdated deep link.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppScaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(AppDimens.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.notFoundTitle,
                style: AppTextStyles.headline,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppDimens.xl),
              AdaptiveButton(
                onPressed: () => context.go(AppRoutes.home),
                child: Text(l10n.notFoundGoHome),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
