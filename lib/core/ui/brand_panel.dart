import 'package:family_stories/core/theme/app_colors.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The same green panel language as the Welcome screen, compact: sticks, the
/// terracotta microphone and the gold dot. Decorative, not mirrored.
class BrandPanel extends StatelessWidget {
  const BrandPanel({super.key});

  static const _sticks = <(double, double, double)>[
    (0.10, 0.35, -0.75),
    (0.27, 0.22, 0.6),
    (0.84, 0.30, -0.75),
    (0.69, 0.68, 0.6),
    (0.16, 0.74, 0.6),
  ];

  @override
  Widget build(BuildContext context) {
    final height = 112.h;
    return ExcludeSemantics(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          child: SizedBox(
            height: height,
            child: ColoredBox(
              color: AppColors.olive,
              child: LayoutBuilder(
                builder: (context, c) {
                  final w = c.maxWidth;
                  final r = height * 0.26;
                  final stickW = height * 0.07;
                  final stickH = height * 0.26;
                  return Stack(
                    children: [
                      for (final (x, y, a) in _sticks)
                        Positioned(
                          left: w * x - stickW / 2,
                          top: height * y - stickH / 2,
                          child: Transform.rotate(
                            angle: a,
                            child: Container(
                              width: stickW,
                              height: stickH,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(stickW),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        left: w * 0.5 - r,
                        top: height * 0.5 - r,
                        child: Container(
                          width: r * 2,
                          height: r * 2,
                          decoration: const BoxDecoration(
                            color: AppColors.terracotta,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.mic_none_rounded,
                            color: Colors.white,
                            size: r * 1.1,
                          ),
                        ),
                      ),
                      Positioned(
                        left: w * 0.62,
                        top: height * 0.5 - height * 0.07,
                        child: Container(
                          width: height * 0.14,
                          height: height * 0.14,
                          decoration: const BoxDecoration(
                            color: AppColors.gold,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
