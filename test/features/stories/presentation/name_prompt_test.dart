import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/network/result.dart';
import 'package:family_stories/features/family/data/demo_family_repository.dart';
import 'package:family_stories/features/family/data/models.dart';
import 'package:family_stories/features/stories/presentation/story_feed_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

/// A signed-in person with no family yet; creating or joining gives one.
class _NoFamilyYet extends DemoFamilyRepository {
  _NoFamilyYet([this._name = '']);

  String _name;
  FamilySpace? _mine;

  @override
  Future<Result<FamilySpace?>> getMySpace() async => Success(_mine);

  @override
  Future<Result<FamilySpace>> createSpace(String name) async {
    final r = await super.createSpace(name);
    if (r case Success(:final value)) _mine = value;
    return r;
  }

  @override
  Future<Result<String>> getMyDisplayName() async => Success(_name);

  @override
  Future<Result<String>> setMyDisplayName(String name) async {
    _name = name.trim();
    return Success(_name);
  }
}

void main() {
  Future<void> createFamily(WidgetTester t, _NoFamilyYet repo) async {
    await t.pumpApp(
      ProviderScope(
        overrides: [familyRepositoryProvider.overrideWithValue(repo)],
        child: const StoryFeedPage(),
      ),
    );
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, 'The Ashmawis');
    await t.tap(find.text(l10nEn.createSpace));
    await t.pumpAndSettle();
  }

  testWidgets('after creating a family, asks what the family calls you', (
    t,
  ) async {
    final repo = _NoFamilyYet();
    await createFamily(t, repo);
    expect(find.text(l10nEn.displayNameTitle), findsOneWidget);

    await t.enterText(find.byType(TextField), 'Mohamed');
    await t.tap(find.text(l10nEn.displayNameSave));
    await t.pumpAndSettle(const Duration(seconds: 5));
    expect((await repo.getMyDisplayName()).unwrap(), 'Mohamed');
    expect(find.text(l10nEn.displayNameTitle), findsNothing);
  });

  testWidgets('cancelling skips it and the family still opens', (t) async {
    final repo = _NoFamilyYet();
    await createFamily(t, repo);
    await t.tap(find.text(l10nEn.cancel));
    await t.pumpAndSettle();
    expect((await repo.getMyDisplayName()).unwrap(), '');
    expect(find.text(l10nEn.displayNameTitle), findsNothing);
  });

  testWidgets('does not ask when the person already has a name', (t) async {
    await createFamily(t, _NoFamilyYet('Sami'));
    expect(find.text(l10nEn.displayNameTitle), findsNothing);
  });

  testWidgets('the join code field capitalizes and skips autocorrect', (
    t,
  ) async {
    await t.pumpApp(
      ProviderScope(
        overrides: [familyRepositoryProvider.overrideWithValue(_NoFamilyYet())],
        child: const StoryFeedPage(),
      ),
    );
    await t.pumpAndSettle();
    final field = t.widget<TextField>(find.byType(TextField).last);
    expect(field.textCapitalization, TextCapitalization.characters);
    expect(field.autocorrect, isFalse);
  });
}
