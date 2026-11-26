import 'package:family_stories/core/adaptive/adaptive.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_text_styles.dart';
import 'package:family_stories/core/theme/app_theme.dart';
import 'package:family_stories/core/ui/app_ui.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Number of bars in the live level meter.
const kLevelBars = 20;

/// The recording screen, as pure display: every value comes in and every tap
/// goes out, so goldens and widget tests need no recorder.
class RecordView extends StatelessWidget {
  const RecordView({
    required this.buttonState,
    required this.elapsed,
    required this.levels,
    required this.narratorName,
    required this.draftSaved,
    required this.canFinish,
    required this.onClose,
    required this.onToggle,
    required this.onPickNarrator,
    required this.onPickTopic,
    required this.onDone,
    this.topicLabel,
    this.promptText,
    this.onDifferentQuestion,
    this.onMoreQuestions,
    this.note,
    super.key,
  });

  final RecordButtonState buttonState;
  final Duration elapsed;

  /// Latest loudness values, 0..1, oldest first; padded to [kLevelBars].
  final List<double> levels;
  final String? narratorName;
  final bool draftSaved;
  final bool canFinish;
  final String? topicLabel;

  /// The question card; null hides it (prompts turned off).
  final String? promptText;
  final VoidCallback? onDifferentQuestion;

  /// Opens "Questions to ask" (spec 07); null hides the link. Only shown
  /// before a take starts.
  final VoidCallback? onMoreQuestions;

  /// Why the take paused when it was not the user's choice.
  final String? note;
  final VoidCallback onClose;
  final VoidCallback onToggle;
  final VoidCallback onPickNarrator;
  final VoidCallback onPickTopic;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final hk = context.hk;
    final recording = buttonState == RecordButtonState.recording;
    return AppScaffold(
      leading: AppIconButton(
        icon: AdaptiveIcons.close(context),
        tooltip: s.recordClose,
        onPressed: onClose,
      ),
      bottom: Row(
        children: [
          Expanded(
            child: AppButton.secondary(
              label: s.recordTopic,
              onPressed: onPickTopic,
            ),
          ),
          SizedBox(width: AppDimens.md),
          Expanded(
            child: AppButton.primary(
              label: s.done,
              onPressed: canFinish ? onDone : null,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsetsDirectional.fromSTEB(
          AppDimens.lg,
          0,
          AppDimens.lg,
          AppDimens.lg,
        ),
        children: [
          if (draftSaved)
            Center(
              child: Text(
                s.recordDraftSaved,
                style: AppTextStyles.caption.copyWith(color: hk.inkSoft),
              ),
            ),
          SizedBox(height: AppDimens.lg),
          Wrap(
            spacing: AppDimens.sm,
            runSpacing: AppDimens.sm,
            children: [
              AppChip(
                label:
                    '${s.recordSpeaking}: ${narratorName ?? s.recordAddPerson}',
                selected: false,
                onTap: onPickNarrator,
              ),
              if (topicLabel != null)
                AppChip(label: topicLabel!, selected: true, onTap: onPickTopic),
            ],
          ),
          if (promptText != null) ...[
            SizedBox(height: AppDimens.lg),
            _PromptCard(text: promptText!, onDifferent: onDifferentQuestion),
          ],
          if (onMoreQuestions != null &&
              buttonState == RecordButtonState.idle) ...[
            SizedBox(height: AppDimens.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: onMoreQuestions,
                child: Text(s.promptsTitle),
              ),
            ),
          ],
          SizedBox(height: AppDimens.xl),
          Center(
            child: Text(
              _format(elapsed),
              style: AppTextStyles.timer,
              textDirection: TextDirection.ltr,
            ),
          ),
          SizedBox(height: AppDimens.sm),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (recording)
                  Container(
                    width: 10.r,
                    height: 10.r,
                    margin: EdgeInsetsDirectional.only(end: AppDimens.sm),
                    decoration: BoxDecoration(
                      color: hk.record,
                      shape: BoxShape.circle,
                    ),
                  ),
                Text(switch (buttonState) {
                  RecordButtonState.idle => s.tapToStart,
                  RecordButtonState.recording => s.recordingStatus,
                  RecordButtonState.paused => s.recordingPausedStatus,
                }, style: AppTextStyles.label.copyWith(color: hk.inkSoft)),
              ],
            ),
          ),
          if (note != null) ...[
            SizedBox(height: AppDimens.sm),
            Text(
              note!,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(color: hk.inkSoft),
            ),
          ],
          SizedBox(height: AppDimens.lg),
          _LevelMeter(levels: levels, active: recording),
          SizedBox(height: AppDimens.lg),
          Center(
            child: RecordButton(state: buttonState, onPressed: onToggle),
          ),
        ],
      ),
    );
  }

  static String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$sec' : '$m:$sec';
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({required this.text, this.onDifferent});

  final String text;
  final VoidCallback? onDifferent;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final hk = context.hk;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        border: Border.all(color: hk.line),
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppDimens.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.recordAskLabel,
              style: AppTextStyles.label.copyWith(color: hk.inkSoft),
            ),
            SizedBox(height: AppDimens.xs),
            Text(text, style: AppTextStyles.bodyLarge),
            if (onDifferent != null)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: onDifferent,
                  child: Text(s.recordDifferentQuestion),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 20 bars driven by the live level. Plain containers: no implicit
/// animation, so it already honors Reduce Motion.
class _LevelMeter extends StatelessWidget {
  const _LevelMeter({required this.levels, required this.active});

  final List<double> levels;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final hk = context.hk;
    final padded = [
      for (var i = 0; i < kLevelBars - levels.length; i++) 0.0,
      ...levels.skip(
        levels.length > kLevelBars ? levels.length - kLevelBars : 0,
      ),
    ];
    final maxHeight = 48.h;
    final minHeight = 4.h;
    return Semantics(
      label: context.l10n.recordMeterLabel,
      child: ExcludeSemantics(
        child: SizedBox(
          height: maxHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final v in padded)
                Container(
                  width: 6.w,
                  height:
                      minHeight + (maxHeight - minHeight) * v.clamp(0.0, 1.0),
                  margin: EdgeInsets.symmetric(horizontal: 2.w),
                  decoration: BoxDecoration(
                    color: active
                        ? Theme.of(context).colorScheme.primary
                        : hk.line,
                    borderRadius: BorderRadius.circular(3.r),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
