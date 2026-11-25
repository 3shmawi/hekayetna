import 'package:family_stories/core/adaptive/adaptive.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_text_styles.dart';
import 'package:family_stories/core/theme/app_theme.dart';
import 'package:family_stories/core/ui/app_ui.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// One interrupted recording on the "Continue a recording" screen
/// (artboard RecordResume). Plain data so the view needs no recorder.
@immutable
class ResumeItem {
  const ResumeItem({
    required this.id,
    required this.title,
    required this.narratorName,
    required this.stoppedAtLabel,
    required this.segmentMs,
  });

  final String id;

  /// The topic, or a neutral "Unfinished recording".
  final String title;
  final String? narratorName;

  /// Already localized: "yesterday at 8:40 pm".
  final String stoppedAtLabel;

  /// Kept duration of each segment, in recording order.
  final List<int> segmentMs;

  int get keptMs => segmentMs.fold(0, (a, b) => a + b);
}

String formatKept(int ms) {
  final d = Duration(milliseconds: ms);
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString();
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.padLeft(2, '0')}:$s' : '$m:$s';
}

/// The screen the user lands on after the app closed mid-recording: the
/// recording is safe, here is what was kept, and three plain choices.
/// With several interrupted recordings each row carries the same actions,
/// newest first.
class ContinueRecordingView extends StatelessWidget {
  const ContinueRecordingView({
    required this.items,
    required this.playingId,
    required this.onPlayToggle,
    required this.onContinue,
    required this.onSave,
    required this.onDelete,
    required this.onClose,
    super.key,
  });

  final List<ResumeItem> items;

  /// The item whose audio is playing now, if any.
  final String? playingId;
  final ValueChanged<ResumeItem> onPlayToggle;
  final ValueChanged<ResumeItem> onContinue;
  final ValueChanged<ResumeItem> onSave;
  final ValueChanged<ResumeItem> onDelete;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final hk = context.hk;
    final first = items.isEmpty ? null : items.first;
    final title = first?.narratorName == null
        ? s.resumeTitleNoNarrator
        : s.resumeTitle(first!.narratorName!);
    // One recording: its actions are the screen's footer, as in the artboard.
    final pinned = items.length == 1;
    return AppScaffold(
      bottom: pinned
          ? Padding(
              padding: EdgeInsets.symmetric(vertical: AppDimens.sm),
              child: _Actions(
                item: items.first,
                onContinue: onContinue,
                onSave: onSave,
                onDelete: onDelete,
              ),
            )
          : null,
      leading: IconButton(
        key: const Key('resume_close'),
        tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
        icon: Icon(AdaptiveIcons.close(context)),
        onPressed: onClose,
      ),
      body: ListView(
        padding: EdgeInsetsDirectional.fromSTEB(
          AppDimens.lg,
          AppDimens.md,
          AppDimens.lg,
          AppDimens.xl,
        ),
        children: [
          Semantics(
            header: true,
            child: Text(title, style: AppTextStyles.headline),
          ),
          SizedBox(height: AppDimens.sm),
          if (first != null)
            Text(
              s.resumeBody(first.stoppedAtLabel),
              style: AppTextStyles.body.copyWith(color: hk.inkSoft),
            ),
          SizedBox(height: AppDimens.lg),
          for (final item in items) ...[
            _ResumeCard(
              item: item,
              playing: playingId == item.id,
              onPlayToggle: () => onPlayToggle(item),
              onContinue: () => onContinue(item),
            ),
            SizedBox(height: AppDimens.md),
            _PrivacyNote(text: s.resumePrivate),
            if (!pinned) ...[
              SizedBox(height: AppDimens.xl),
              _Actions(
                item: item,
                onContinue: onContinue,
                onSave: onSave,
                onDelete: onDelete,
              ),
            ],
            if (item != items.last) ...[
              SizedBox(height: AppDimens.lg),
              Divider(color: hk.line),
              SizedBox(height: AppDimens.lg),
            ],
          ],
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.item,
    required this.onContinue,
    required this.onSave,
    required this.onDelete,
  });

  final ResumeItem item;
  final ValueChanged<ResumeItem> onContinue;
  final ValueChanged<ResumeItem> onSave;
  final ValueChanged<ResumeItem> onDelete;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton.record(
          key: Key('resume_continue_${item.id}'),
          label: s.resumeContinue,
          icon: AdaptiveIcons.record(context),
          onPressed: () => onContinue(item),
        ),
        SizedBox(height: AppDimens.md),
        AppButton.secondary(
          key: Key('resume_save_${item.id}'),
          label: s.resumeSave,
          onPressed: () => onSave(item),
        ),
        SizedBox(height: AppDimens.xs),
        TextButton(
          key: Key('resume_delete_${item.id}'),
          style: TextButton.styleFrom(
            minimumSize: Size.fromHeight(AppDimens.targetMin),
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => onDelete(item),
          child: Text(s.resumeDelete, maxLines: 1),
        ),
      ],
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({
    required this.item,
    required this.playing,
    required this.onPlayToggle,
    required this.onContinue,
  });

  final ResumeItem item;
  final bool playing;
  final VoidCallback onPlayToggle;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final hk = context.hk;
    final scheme = Theme.of(context).colorScheme;
    final parts = s.resumeParts(item.segmentMs.length);
    final duration = formatKept(item.keptMs);
    final meta = item.narratorName == null
        ? s.resumeMetaNoNarrator(parts, duration)
        : s.resumeMeta(item.narratorName!, parts, duration);
    return Container(
      padding: EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: hk.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (item.narratorName != null) ...[
                PersonAvatar(name: item.narratorName!, size: AppDimens.avatar),
                SizedBox(width: AppDimens.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: AppTextStyles.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      meta,
                      style: AppTextStyles.caption.copyWith(color: hk.inkSoft),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: AppDimens.sm),
              Semantics(
                button: true,
                label: playing ? s.resumePause : s.resumePlay,
                excludeSemantics: true,
                child: InkResponse(
                  key: Key('resume_play_${item.id}'),
                  onTap: onPlayToggle,
                  radius: AppDimens.targetMin / 2,
                  child: Container(
                    width: AppDimens.targetMin,
                    height: AppDimens.targetMin,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hk.sand,
                      border: Border.all(color: hk.line),
                    ),
                    child: Icon(
                      playing
                          ? AdaptiveIcons.pause(context)
                          : AdaptiveIcons.play(context),
                      color: scheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppDimens.md),
          _SegmentBar(segmentMs: item.segmentMs),
          SizedBox(height: AppDimens.sm),
          // A Wrap, not a Row: on a narrow screen or at large text the link
          // drops under "Kept" instead of being cut off.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                s.resumeKept(formatKept(item.keptMs)),
                style: AppTextStyles.caption.copyWith(color: hk.inkSoft),
              ),
              TextButton(
                key: Key('resume_from_here_${item.id}'),
                style: TextButton.styleFrom(
                  minimumSize: Size(0, AppDimens.targetMin),
                  foregroundColor: hk.record,
                  padding: EdgeInsets.symmetric(horizontal: AppDimens.sm),
                ),
                onPressed: onContinue,
                child: Text(s.resumeContinueFromHere),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One filled bar per kept segment (width follows its length), then a dashed
/// empty one: where the recording picks up again.
class _SegmentBar extends StatelessWidget {
  const _SegmentBar({required this.segmentMs});

  final List<int> segmentMs;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hk = context.hk;
    final total = segmentMs.fold<int>(0, (a, b) => a + b);
    return ExcludeSemantics(
      child: SizedBox(
        height: 6,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final ms in segmentMs)
              Expanded(
                flex: total == 0 ? 1 : (ms * 1000 ~/ total).clamp(1, 1000000),
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 3),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            Expanded(
              flex: (segmentMs.length * 1000 ~/ 4).clamp(120, 400),
              child: DecoratedBox(
                decoration: const BoxDecoration(),
                child: CustomPaint(
                  key: const Key('resume_dashed_segment'),
                  painter: _DashedPillPainter(color: hk.record),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The unfinished segment: a dashed outline, as in the artboard.
class _DashedPillPainter extends CustomPainter {
  const _DashedPillPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(0.5),
      Radius.circular(size.height / 2),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 3), paint);
        d += 5;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPillPainter old) => old.color != color;
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final hk = context.hk;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimens.md,
        vertical: AppDimens.sm,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      ),
      child: Row(
        children: [
          Icon(
            AdaptiveIcons.lock(context),
            size: AppDimens.iconMd * 0.75,
            color: hk.inkSoft,
          ),
          SizedBox(width: AppDimens.sm),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.caption.copyWith(color: hk.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}
