import 'package:family_stories/core/adaptive/adaptive.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_text_styles.dart';
import 'package:family_stories/l10n/l10n.dart';

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
    this.eyebrow,
    this.name,
    super.key,
  });

  final String? title;
  final String subtitle;

  /// With [name], the story page layout: a small [eyebrow] ("Told by") over
  /// the bold narrator [name] beside the play button, the scrubber under
  /// them, and the times with the speed between them. [subtitle] is unused
  /// then.
  final String? eyebrow;
  final String? name;

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
    final s = context.l10n;
    final progress = _progress;
    if (eyebrow != null && name != null) {
      return _narratorLayout(context, scheme, s, progress);
    }
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
                  tooltip: isPlaying ? s.storyPause : s.storyPlay,
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

extension on AudioPlayerCard {
  Widget _narratorLayout(
    BuildContext context,
    ColorScheme scheme,
    AppLocalizations s,
    double progress,
  ) {
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
            Row(
              children: [
                IconButton.filled(
                  onPressed: onToggle,
                  tooltip: isPlaying ? s.storyPause : s.storyPlay,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eyebrow!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        name!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.title,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: AppDimens.lg),
            _WaveformScrubber(
              waveform: waveform,
              progress: progress,
              onSeek: onSeek,
              // Bars need the room; the plain track does not.
              height: waveform.isEmpty ? AppDimens.targetMin : null,
            ),
            SizedBox(height: AppDimens.xs),
            Row(
              children: [
                Text(
                  position,
                  style: AppTextStyles.caption.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: TextButton(
                      onPressed: onSpeed,
                      child: Text(speed, style: AppTextStyles.label),
                    ),
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
    this.height,
  });

  final List<double> waveform;
  final double progress;
  final ValueChanged<double> onSeek;

  /// Defaults to the play button's height.
  final double? height;

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
              height: height ?? AppDimens.playButton,
              child: CustomPaint(
                key: const Key('waveform-scrubber'),
                size: Size(
                  constraints.maxWidth,
                  height ?? AppDimens.playButton,
                ),
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
    if (waveform.isEmpty) {
      // No waveform data yet: a plain progress track of the same height.
      final track = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = size.height / 8;
      final y = size.height / 2;
      final rtl = direction == TextDirection.rtl;
      final startX = rtl ? size.width : 0.0;
      final endX = rtl ? 0.0 : size.width;
      canvas
        ..drawLine(Offset(startX, y), Offset(endX, y), track..color = rest)
        ..drawLine(
          Offset(startX, y),
          Offset(startX + (endX - startX) * progress, y),
          track..color = played,
        );
      return;
    }
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
