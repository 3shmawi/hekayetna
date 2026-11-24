import 'package:family_stories/core/adaptive/adaptive.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_text_styles.dart';
import 'package:family_stories/core/theme/app_theme.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The heart of the app (Design System card): one huge terracotta button
/// that starts, pauses and resumes a recording. A 140px halo breathes
/// (scale 1 → 1.08, 1.6s) while recording; Reduce Motion
/// (`MediaQuery.disableAnimations`) stops the breathing.
class RecordButton extends StatefulWidget {
  const RecordButton({required this.state, required this.onPressed, super.key});

  final RecordButtonState state;
  final VoidCallback onPressed;

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

enum RecordButtonState { idle, recording, paused }

class _RecordButtonState extends State<RecordButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _halo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void dispose() {
    _halo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hk = context.hk;
    final s = context.l10n;
    final recording = widget.state == RecordButtonState.recording;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (recording && !reduceMotion) {
      _halo.repeat(reverse: true);
    } else {
      _halo
        ..stop()
        ..value = 0;
    }
    final label = switch (widget.state) {
      RecordButtonState.idle => s.recordStart,
      RecordButtonState.recording => s.recordPause,
      RecordButtonState.paused => s.recordResume,
    };
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: SizedBox.square(
          dimension: AppDimens.recordHalo,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ScaleTransition(
                key: const Key('record-halo'),
                scale: Tween<double>(begin: 1, end: 1.08).animate(
                  CurvedAnimation(parent: _halo, curve: Curves.easeInOut),
                ),
                child: Container(
                  width: AppDimens.recordHalo,
                  height: AppDimens.recordHalo,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: recording
                        ? hk.recordTint
                        : hk.recordTint.withValues(alpha: 0),
                  ),
                ),
              ),
              Container(
                width: AppDimens.recordButton,
                height: AppDimens.recordButton,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: switch (widget.state) {
                    RecordButtonState.recording => hk.record,
                    RecordButtonState.paused => Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHigh,
                    RecordButtonState.idle => hk.record,
                  },
                  border: widget.state == RecordButtonState.paused
                      ? Border.all(color: hk.record, width: 2)
                      : null,
                  boxShadow: recording
                      ? [
                          BoxShadow(
                            color: hk.record.withValues(alpha: 0.35),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  switch (widget.state) {
                    RecordButtonState.recording => AdaptiveIcons.pause(context),
                    _ => AdaptiveIcons.record(context),
                  },
                  size: AppDimens.iconMd * 1.5,
                  color: switch (widget.state) {
                    RecordButtonState.paused => hk.record,
                    _ => hk.onRecord,
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The status line above/below the button: a dot and "Recording"/"Paused".
class RecordButtonStatus extends StatelessWidget {
  const RecordButtonStatus({required this.state, super.key});

  final RecordButtonState state;

  @override
  Widget build(BuildContext context) {
    if (state == RecordButtonState.idle) return const SizedBox.shrink();
    final hk = context.hk;
    final s = context.l10n;
    final recording = state == RecordButtonState.recording;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: AppDimens.sm,
          height: AppDimens.sm,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: recording ? hk.record : context.hk.inkSoft,
          ),
        ),
        SizedBox(width: AppDimens.sm),
        Text(
          recording ? s.recordingStatus : s.recordingPausedStatus,
          style: AppTextStyles.caption.copyWith(
            color: recording ? hk.record : hk.inkSoft,
          ),
        ),
      ],
    );
  }
}
