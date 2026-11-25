import 'dart:ui' show Locale;
import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/auth/auth_redirect.dart';
import 'package:family_stories/core/network/result.dart';
import 'package:family_stories/features/family/data/demo_family_repository.dart';
import 'package:family_stories/features/family/data/models.dart';
import 'package:family_stories/features/family/presentation/join_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

class _Spy extends DemoFamilyRepository {
  final previews = <String>[];
  final joins = <String>[];
  @override
  Future<Result<FamilyPreview>> previewFamily(String inviteCode) {
    previews.add(inviteCode);
    return super.previewFamily(inviteCode);
  }

  @override
  Future<Result<FamilySpace>> joinSpace(String inviteCode) {
    joins.add(inviteCode);
    return super.joinSpace(inviteCode);
  }
}

class _Preview extends DemoFamilyRepository {
  _Preview(this.name, this.count);
  final String name;
  final int count;
  @override
  Future<Result<FamilyPreview>> previewFamily(String inviteCode) async =>
      Success(FamilyPreview(name: name, memberCount: count));
}

void main() {
  for (final locale in ['en', 'ar']) {
    for (final name in ['Ashmawy family', 'عيلة أشماوي', 'عيلة Ashmawy']) {
      for (final count in [1, 2, 5, 12]) {
        testWidgets(
          'preview $locale "$name" x$count: name and count on own lines',
          (t) async {
            await t.pumpApp(
              ProviderScope(
                overrides: [
                  familyRepositoryProvider.overrideWithValue(
                    _Preview(name, count),
                  ),
                ],
                child: const JoinScreen(rawCode: '7K4QM9X'),
              ),
              locale: Locale(locale),
            );
            await t.pumpAndSettle();
            final nameBox = t.getRect(find.text(name));
            final countFinder = find.textContaining(
              RegExp(r'\d|واحد|عضوين|^1 '),
            );
            expect(find.text(name), findsOneWidget);
            expect(countFinder, findsWidgets);
            expect(t.takeException(), isNull);
            expect(nameBox.height, lessThan(60));
          },
        );
      }
    }
  }

  for (final hostile in [
    '../../etc/passwd',
    "7K4'; drop table",
    '<script>alert(1)</script>',
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
    '',
  ]) {
    testWidgets('hostile code "$hostile" never reaches the backend', (t) async {
      final spy = _Spy();
      await t.pumpApp(
        ProviderScope(
          overrides: [familyRepositoryProvider.overrideWithValue(spy)],
          child: JoinScreen(rawCode: hostile),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text(l10nEn.joinInvalid), findsOneWidget);
      expect(spy.previews, isEmpty);
      expect(spy.joins, isEmpty);
    });
  }

  testWidgets('a good code previews first and joins only on tap', (t) async {
    final spy = _Spy();
    await t.pumpApp(
      ProviderScope(
        overrides: [familyRepositoryProvider.overrideWithValue(spy)],
        child: const JoinScreen(rawCode: '7K4QM9X'),
      ),
    );
    await t.pumpAndSettle();
    expect(spy.previews, ['7K4QM9X']);
    expect(spy.joins, isEmpty);
    expect(find.text(l10nEn.joinConfirmButton), findsOneWidget);
    await t.expectAccessible();
  });

  test('signed-out join link goes to sign-in and keeps the link', () {
    final to = authRedirect(Uri.parse('/join/7K4QM9X'), signedIn: false);
    expect(to, startsWith('/sign-in?from='));
    expect(Uri.parse(to!).queryParameters['from'], '/join/7K4QM9X');
  });
}
