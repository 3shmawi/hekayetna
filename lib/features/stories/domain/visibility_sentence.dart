import 'package:family_stories/features/stories/data/models.dart';
import 'package:family_stories/l10n/l10n.dart';

/// The exact line under "Who can listen?": it says who will hear the story,
/// so it is built in one place and tested in both languages.
///
/// - private: "Only you can hear this"
/// - selected: "3 people can hear this: Mama, Omar, Nour"
/// - family: "Everyone in the family now (8 people)"
String visibilitySentence(
  AppLocalizations s, {
  required StoryVisibility visibility,
  required List<String> selectedNames,
  required int familyCount,
}) => switch (visibility) {
  StoryVisibility.private => s.storyVisPrivate,
  StoryVisibility.selected => s.storyVisSelected(
    selectedNames.length,
    selectedNames.join(s.listSeparator),
  ),
  StoryVisibility.family => s.storyVisFamily(familyCount),
};
