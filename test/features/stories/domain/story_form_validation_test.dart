import 'package:family_stories/features/stories/data/models.dart';
import 'package:family_stories/features/stories/domain/story_form_validation.dart';
import 'package:flutter_test/flutter_test.dart';

StoryFormInput _input({
  String title = 'The first Om Ali',
  String description = '',
  String dateLabel = '',
  String year = '',
  StoryVisibility visibility = StoryVisibility.private,
  int recipients = 0,
}) => StoryFormInput(
  title: title,
  description: description,
  dateLabel: dateLabel,
  yearText: year,
  visibility: visibility,
  recipientCount: recipients,
);

void main() {
  test('a normal form is valid', () {
    expect(validateStoryForm(_input()), isEmpty);
  });

  test('empty or blank title is rejected', () {
    expect(validateStoryForm(_input(title: '')), [StoryFormError.titleEmpty]);
    expect(validateStoryForm(_input(title: '  \n ')), [
      StoryFormError.titleEmpty,
    ]);
  });

  test('title is limited to 140 characters after trimming', () {
    expect(validateStoryForm(_input(title: ' ${'a' * 140} ')), isEmpty);
    expect(validateStoryForm(_input(title: 'a' * 141)), [
      StoryFormError.titleTooLong,
    ]);
  });

  test('length counts characters, not UTF-16 units', () {
    // 140 emoji are 280 UTF-16 units but 140 characters.
    expect(validateStoryForm(_input(title: '😀' * 140)), isEmpty);
    expect(validateStoryForm(_input(title: '😀' * 141)), [
      StoryFormError.titleTooLong,
    ]);
  });

  test('description, date label and year limits', () {
    expect(validateStoryForm(_input(description: 'x' * 2000)), isEmpty);
    expect(validateStoryForm(_input(description: 'x' * 2001)), [
      StoryFormError.descriptionTooLong,
    ]);
    expect(validateStoryForm(_input(dateLabel: 'x' * 61)), [
      StoryFormError.dateLabelTooLong,
    ]);
    for (final ok in ['', '1800', '2100', ' 1975 ']) {
      expect(validateStoryForm(_input(year: ok)), isEmpty, reason: ok);
    }
    for (final bad in ['1799', '2101', 'abc', '19.5', '-5']) {
      expect(validateStoryForm(_input(year: bad)), [
        StoryFormError.yearInvalid,
      ], reason: bad);
    }
  });

  test('"Selected people" needs at least one person', () {
    expect(validateStoryForm(_input(visibility: StoryVisibility.selected)), [
      StoryFormError.noRecipients,
    ]);
    expect(
      validateStoryForm(
        _input(visibility: StoryVisibility.selected, recipients: 2),
      ),
      isEmpty,
    );
    // Other choices do not care about recipients.
    expect(
      validateStoryForm(_input(visibility: StoryVisibility.family)),
      isEmpty,
    );
  });

  group('hostile input is valid text, never interpreted', () {
    final hostile = <String, String>{
      'script': '<script>alert(1)</script>',
      'sql': "Robert'); DROP TABLE stories;--",
      'rtl override': 'abc\u202Edef\u202C',
      'null and control': 'a\u0000b\u0007c',
      'markdown': '[x](javascript:alert(1)) **bold**',
    };
    for (final MapEntry(:key, :value) in hostile.entries) {
      test(key, () {
        expect(
          validateStoryForm(
            _input(title: value, description: value, dateLabel: value),
          ),
          isEmpty,
        );
      });
    }

    test('10 000 characters are rejected by the length limits only', () {
      final big = 'x' * 10000;
      expect(
        validateStoryForm(_input(title: big, description: big, dateLabel: big)),
        [
          StoryFormError.titleTooLong,
          StoryFormError.descriptionTooLong,
          StoryFormError.dateLabelTooLong,
        ],
      );
    });
  });
}
