import 'dart:convert';
import 'dart:io';

import 'package:family_stories/features/prompts/domain/interview_prompt.dart';
import 'package:family_stories/features/stories/domain/story_topics.dart';
import 'package:flutter_test/flutter_test.dart';

PromptLibrary _load() => PromptLibrary.fromJson(
  jsonDecode(File('assets/prompts/prompts.json').readAsStringSync())
      as Map<String, dynamic>,
);

void main() {
  final lib = _load();

  test('the file is versioned', () => expect(lib.version, 1));

  test('ids are unique, stable-shaped and at most 64 characters', () {
    final ids = lib.prompts.map((p) => p.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final id in ids) {
      expect(id, matches(RegExp(r'^[a-z0-9_]+$')));
      expect(id.length, lessThanOrEqualTo(64));
    }
  });

  test('every prompt has a known topic', () {
    for (final p in lib.prompts) {
      expect(kStoryTopics, contains(p.topic), reason: p.id);
    }
  });

  test('every topic has at least 12 prompts', () {
    for (final t in kStoryTopics) {
      expect(lib.forTopic(t).length, greaterThanOrEqualTo(12), reason: t);
    }
  });

  test('both languages: no empty strings, at most two follow-ups, '
      'at most 140 characters', () {
    for (final p in lib.prompts) {
      for (final t in [p.en, p.ar]) {
        expect(t.question.trim(), isNotEmpty, reason: p.id);
        expect(t.question.length, lessThanOrEqualTo(140), reason: p.id);
        expect(t.followUps.length, lessThanOrEqualTo(2), reason: p.id);
        for (final f in t.followUps) {
          expect(f.trim(), isNotEmpty, reason: p.id);
          expect(f.length, lessThanOrEqualTo(140), reason: p.id);
        }
      }
      expect(p.en.followUps.length, p.ar.followUps.length, reason: p.id);
    }
  });

  test('the Arabic is Arabic script and the English is not', () {
    final arabic = RegExp('[\u0600-\u06FF]');
    for (final p in lib.prompts) {
      expect(arabic.hasMatch(p.ar.question), isTrue, reason: p.id);
      expect(arabic.hasMatch(p.en.question), isFalse, reason: p.id);
    }
  });

  test('the example question from spec 07 is present', () {
    expect(
      lib.byId('ramadan_cooking')?.ar.question,
      'كانت أمك بتطبخ إيه في رمضان؟',
    );
  });

  test('text picks Arabic for ar and English for anything else', () {
    final p = lib.byId('ramadan_cooking')!;
    expect(p.text('ar'), same(p.ar));
    expect(p.text('en'), same(p.en));
    expect(p.text('fr'), same(p.en));
  });
}
