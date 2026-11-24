import 'package:family_stories/core/network/connectivity.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_text_styles.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Shows a slim banner at the bottom of every screen while offline.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({required this.child, this.onlineChanges, super.key});

  final Widget child;

  /// Defaults to the device connectivity; tests pass their own stream.
  final Stream<bool>? onlineChanges;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: onlineChanges ?? ConnectivityStatus.onlineChanges,
      initialData: true,
      builder: (context, snapshot) {
        final offline = snapshot.data == false;
        final scheme = Theme.of(context).colorScheme;
        return Column(
          children: [
            Expanded(child: child),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: offline
                  ? Material(
                      color: scheme.inverseSurface,
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppDimens.lg,
                            vertical: AppDimens.sm,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.cloud_off_outlined,
                                color: scheme.onInverseSurface,
                                size: AppDimens.iconMd,
                              ),
                              SizedBox(width: AppDimens.sm),
                              Expanded(
                                child: Text(
                                  context.l10n.offlineBanner,
                                  style: AppTextStyles.body.copyWith(
                                    color: scheme.onInverseSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        );
      },
    );
  }
}
