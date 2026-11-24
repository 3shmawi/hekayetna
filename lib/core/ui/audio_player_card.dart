import 'package:family_stories/core/adaptive/adaptive.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_text_styles.dart';

import 'package:flutter/material.dart';

/// The story's voice, front and centre on the story page (Design System
/// card): a big play button, a waveform that doubles as the scrubber,
/// times and speed. The waveform mirrors in RTL; it is a semantics slider.
class AudioPlayerCard extends StatelessWidget {
  const AudioPlayerCard({
    required this.subtitle,
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.speed,
    required this.onToggle,
    required this.onSeek,
    required this.onSpeed,
    required this.waveform,
    this.title,
    super.key,
  });

  final String? title;
  final String subtitle;

  /// Already formatted ("1:12").
  final String position;

  /// Already formatted ("2:34").
  final String duration;
  final bool isPlaying;

  /// Already formatted ("1×").
  final String speed;
  final VoidCallback onToggle;

  /// 0..1 through the story.
  final ValueChanged<double> onSeek;
  final VoidCallback onSpeed;

  /// Bar heights, 0..1.
  final List<double> waveform;

  double get _progress {
    final p = _parse(position) / _parse(duration);
    return p.isFinite ? p.clamp(0.0, 1.0) : 0;
  }

  static double _parse(String mmss) {
    final parts = mmss.split(':');
    if (parts.length != 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 +
        (double.tryParse(parts[1]) ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = _progress;
    return Semantics(
      container: true,
      child: Container(
        padding: EdgeInsets.all(AppDimens.lg),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(title!, maxLines: 1, style: AppTextStyles.title),
              SizedBox(height: AppDimens.xs),
            ],
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: AppDimens.lg),
            Row(
              children: [
                IconButton.filled(
                  onPressed: onToggle,
                  iconSize: AppDimens.playButton / 2,
                  constraints: BoxConstraints.tightFor(
                    width: AppDimens.playButton,
                    height: AppDimens.playButton,
                  ),
                  icon: Icon(
                    isPlaying
                        ? AdaptiveIcons.pause(context)
                        : AdaptiveIcons.play(context),
                  ),
                ),
                SizedBox(width: AppDimens.lg),
                Expanded(
                  child: _WaveformScrubber(
                    waveform: waveform,
                    progress: progress,
                    onSeek: onSeek,
                  ),
                ),
                SizedBox(width: AppDimens.lg),
                TextButton(
                  onPressed: onSpeed,
                  child: Text(speed, style: AppTextStyles.label),
                ),
              ],
            ),
            SizedBox(height: AppDimens.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  position,
                  style: AppTextStyles.caption.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  duration,
                  style: AppTextStyles.caption.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WaveformScrubber extends StatelessWidget {
  const _WaveformScrubber({
    required this.waveform,
    required this.progress,
    required this.onSeek,
  });

  final List<double> waveform;
  final double progress;
  final ValueChanged<double> onSeek;

  void _seekAt(Offset local, double width, TextDirection direction) {
    // The bars are drawn with Directionality, so the widget's own layout is
    // always LTR; convert the reading-direction position to time.
    var dx = local.dx / width;
    if (direction == TextDirection.rtl) dx = 1 - dx;
    onSeek(dx.clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      slider: true,
      value: '${(progress * 100).round()}%',
      increasedValue: '${(((progress + 0.05).clamp(0.0, 1.0)) * 100).round()}%',
      decreasedValue: '${(((progress - 0.05).clamp(0.0, 1.0)) * 100).round()}%',
      onIncrease: () => onSeek((progress + 0.05).clamp(0.0, 1.0)),
      onDecrease: () => onSeek((progress - 0.05).clamp(0.0, 1.0)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final direction = Directionality.of(context);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) =>
                _seekAt(d.localPosition, constraints.maxWidth, direction),
            onHorizontalDragUpdate: (d) =>
                _seekAt(d.localPosition, constraints.maxWidth, direction),
            child: SizedBox(
              height: AppDimens.playButton,
              child: CustomPaint(
                key: const Key('waveform-scrubber'),
                size: Size(constraints.maxWidth, AppDimens.playButton),
                painter: _WaveformPainter(
                  waveform: waveform,
                  progress: progress,
                  played: scheme.primary,
                  rest: scheme.outlineVariant,
                  direction: Directionality.of(context),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.waveform,
    required this.progress,
    required this.played,
    required this.rest,
    required this.direction,
  });

  final List<double> waveform;
  final double progress;
  final Color played;
  final Color rest;
  final TextDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    if (waveform.isEmpty) return;
    final count = waveform.length;
    final barWidth = size.width / (count * 1.5);
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < count; i++) {
      final t = count == 1 ? 0.0 : i / (count - 1);
      // Reading direction: the story starts at the start edge, so in RTL
      // the first bar is on the right.
      final logicalT = direction == TextDirection.rtl ? 1 - t : t;
      final x = logicalT * (size.width - barWidth) + barWidth / 2;
      final h = (waveform[i].clamp(0.08, 1.0)) * size.height;
      paint.color = t <= progress ? played : rest;
      canvas.drawLine(
        Offset(x, (size.height - h) / 2),
        Offset(x, (size.height + h) / 2),
        paint..strokeWidth = barWidth,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress || old.waveform != waveform;
}
