import 'package:family_stories/features/stories/data/models.dart';

/// Limits of the save-story form (spec 04). The database enforces its own
/// checks; these keep the form honest before anything is uploaded.
abstract final class StoryFormLimits {
  static const titleMax = 140;
  static const descriptionMax = 2000;
  static const dateLabelMax = 60;
  static const yearMin = 1800;
  static const yearMax = 2100;
}

enum StoryFormError {
  titleEmpty,
  titleTooLong,
  descriptionTooLong,
  dateLabelTooLong,
  yearInvalid,
  noRecipients,
}

/// What the user typed. Text is kept exactly as typed (only the ends are
/// trimmed); it is rendered as plain text, never as markup or a query.
class StoryFormInput {
  const StoryFormInput({
    required this.title,
    required this.visibility,
    this.description = '',
    this.dateLabel = '',
    this.yearText = '',
    this.recipientCount = 0,
  });

  final String title;
  final String description;
  final String dateLabel;

  /// Raw year field; empty means "no year".
  final String yearText;
  final StoryVisibility visibility;
  final int recipientCount;

  /// The parsed year, or null when empty or invalid (see validateStoryForm).
  int? get year => int.tryParse(yearText.trim());
}

/// Every problem with [input], in form order; empty means it can be saved.
List<StoryFormError> validateStoryForm(StoryFormInput input) {
  final title = input.title.trim();
  final year = input.yearText.trim();
  return [
    if (title.isEmpty) StoryFormError.titleEmpty,
    if (title.runes.length > StoryFormLimits.titleMax)
      StoryFormError.titleTooLong,
    if (input.description.trim().runes.length > StoryFormLimits.descriptionMax)
      StoryFormError.descriptionTooLong,
    if (input.dateLabel.trim().runes.length > StoryFormLimits.dateLabelMax)
      StoryFormError.dateLabelTooLong,
    if (year.isNotEmpty &&
        (int.tryParse(year) == null ||
            int.parse(year) < StoryFormLimits.yearMin ||
            int.parse(year) > StoryFormLimits.yearMax))
      StoryFormError.yearInvalid,
    if (input.visibility == StoryVisibility.selected &&
        input.recipientCount == 0)
      StoryFormError.noRecipients,
  ];
}
