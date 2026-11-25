import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_text_styles.dart';
import 'package:family_stories/core/ui/app_ui.dart' as ui;
import 'package:family_stories/features/stories/data/models.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// "Delete this story?" Returns true only when the member confirms.
Future<bool> confirmDeleteStory(BuildContext context) async {
  final yes = await ui.showAppSheet<bool>(
    context,
    builder: (sheet) {
      final s = sheet.l10n;
      return Padding(
        padding: EdgeInsets.all(AppDimens.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.storyDeleteTitle, style: AppTextStyles.headline),
            SizedBox(height: AppDimens.sm),
            Text(s.storyDeleteBody, style: AppTextStyles.body),
            SizedBox(height: AppDimens.lg),
            ui.AppButton.destructive(
              label: s.delete,
              onPressed: () => Navigator.of(sheet).pop(true),
            ),
            SizedBox(height: AppDimens.sm),
            ui.AppButton.secondary(
              label: s.cancel,
              onPressed: () => Navigator.of(sheet).pop(false),
            ),
          ],
        ),
      );
    },
  );
  return yes ?? false;
}

/// Edits title, description and date label. Spec 04 replaces this with the
/// full story form.
Future<Story?> showEditDetailsSheet(BuildContext context, Story story) {
  return ui.showAppSheet<Story>(
    context,
    builder: (sheet) => _EditDetails(story: story),
  );
}

class _EditDetails extends StatefulWidget {
  const _EditDetails({required this.story});

  final Story story;

  @override
  State<_EditDetails> createState() => _EditDetailsState();
}

class _EditDetailsState extends State<_EditDetails> {
  late final _title = TextEditingController(text: widget.story.title);
  late final _description = TextEditingController(
    text: widget.story.description ?? '',
  );
  late final _date = TextEditingController(
    text: widget.story.approxDateLabel ?? '',
  );

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _date.dispose();
    super.dispose();
  }

  String? _blankToNull(String v) => v.trim().isEmpty ? null : v.trim();

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    return Padding(
      padding: EdgeInsets.all(AppDimens.lg).copyWith(
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppDimens.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.storyEditTitle, style: AppTextStyles.headline),
            SizedBox(height: AppDimens.lg),
            TextField(
              controller: _title,
              decoration: InputDecoration(labelText: s.storyTitle),
            ),
            SizedBox(height: AppDimens.md),
            TextField(
              controller: _description,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(labelText: s.description),
            ),
            SizedBox(height: AppDimens.md),
            TextField(
              controller: _date,
              decoration: InputDecoration(labelText: s.approxDate),
            ),
            SizedBox(height: AppDimens.lg),
            ui.AppButton.primary(
              label: s.save,
              onPressed: () {
                final title = _title.text.trim();
                if (title.isEmpty) return;
                Navigator.of(context).pop(
                  widget.story.copyWith(
                    title: title,
                    description: () => _blankToNull(_description.text),
                    approxDateLabel: () => _blankToNull(_date.text),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// "Who can listen": only me or the whole family. Picking specific people
/// arrives with the story form (spec 04), so that option explains itself
/// instead of saving.
Future<StoryVisibility?> showVisibilitySheet(
  BuildContext context, {
  required StoryVisibility current,
  required String Function(StoryVisibility) consequence,
}) {
  return ui.showAppSheet<StoryVisibility>(
    context,
    builder: (sheet) =>
        _VisibilitySheet(current: current, consequence: consequence),
  );
}

class _VisibilitySheet extends StatefulWidget {
  const _VisibilitySheet({required this.current, required this.consequence});

  final StoryVisibility current;
  final String Function(StoryVisibility) consequence;

  @override
  State<_VisibilitySheet> createState() => _VisibilitySheetState();
}

class _VisibilitySheetState extends State<_VisibilitySheet> {
  late StoryVisibility _value = widget.current;

  static ui.StoryVisibility _toPicker(StoryVisibility v) => switch (v) {
    StoryVisibility.private => ui.StoryVisibility.onlyMe,
    StoryVisibility.selected => ui.StoryVisibility.selectedPeople,
    StoryVisibility.family => ui.StoryVisibility.wholeFamily,
  };

  static StoryVisibility _fromPicker(ui.StoryVisibility v) => switch (v) {
    ui.StoryVisibility.onlyMe => StoryVisibility.private,
    ui.StoryVisibility.selectedPeople => StoryVisibility.selected,
    ui.StoryVisibility.wholeFamily => StoryVisibility.family,
  };

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final pickingPeople =
        _value == StoryVisibility.selected &&
        widget.current != StoryVisibility.selected;
    return Padding(
      padding: EdgeInsets.all(AppDimens.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.storyWhoCanListen, style: AppTextStyles.headline),
          SizedBox(height: AppDimens.lg),
          ui.VisibilityPicker(
            value: _toPicker(_value),
            onChanged: (v) => setState(() => _value = _fromPicker(v)),
            consequenceText: pickingPeople
                ? s.storyPickPeopleSoon
                : widget.consequence(_value),
          ),
          SizedBox(height: AppDimens.lg),
          ui.AppButton.primary(
            label: s.save,
            onPressed: pickingPeople || _value == widget.current
                ? null
                : () => Navigator.of(context).pop(_value),
          ),
        ],
      ),
    );
  }
}
