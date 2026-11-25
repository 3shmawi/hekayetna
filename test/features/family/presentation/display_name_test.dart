import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/network/result.dart';
import 'package:family_stories/features/auth/presentation/account_page.dart';
import 'package:family_stories/features/family/data/demo_family_repository.dart';
import 'package:family_stories/features/family/presentation/display_name_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

extension on Result<String> {
  bool get ok => this is Success<String>;
  String? get val => switch (this) {
    Success(:final value) => value,
    Failed() => null,
  };
}

void main() {
  test('names are 1 to 40 characters after trimming', () {
    expect(isValidDisplayName('  '), isFalse);
    expect(isValidDisplayName(''), isFalse);
    expect(isValidDisplayName(' Sami '), isTrue);
    expect(isValidDisplayName('x' * 40), isTrue);
    expect(isValidDisplayName('x' * 41), isFalse);
  });

  test('the repository rejects bad names and saves a trimmed one', () async {
    final repo = DemoFamilyRepository();
    expect((await repo.setMyDisplayName('   ')).ok, isFalse);
    expect((await repo.setMyDisplayName('x' * 41)).ok, isFalse);
    expect((await repo.setMyDisplayName('  Sami ')).val, 'Sami');
    expect((await repo.getMyDisplayName()).val, 'Sami');
  });

  testWidgets('AC-7: Your name in Account saves and shows the name', (t) async {
    final repo = DemoFamilyRepository();
    await t.pumpApp(
      ProviderScope(
        overrides: [familyRepositoryProvider.overrideWithValue(repo)],
        child: const AccountPage(),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('account_your_name')));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '   ');
    await t.tap(find.text(l10nEn.displayNameSave));
    await t.pumpAndSettle();
    expect(find.text(l10nEn.displayNameInvalid), findsOneWidget);
    expect((await repo.getMyDisplayName()).val, '');

    await t.enterText(find.byType(TextField), 'Mohamed');
    await t.tap(find.text(l10nEn.displayNameSave));
    await t.pumpAndSettle(const Duration(seconds: 5));
    expect((await repo.getMyDisplayName()).val, 'Mohamed');
    expect(find.textContaining('Mohamed'), findsOneWidget);
  });
}
