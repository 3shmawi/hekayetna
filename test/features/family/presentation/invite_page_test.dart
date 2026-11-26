import 'package:family_stories/features/family/data/invite_actions.dart';
import 'package:family_stories/features/family/domain/invite_code.dart';
import 'package:family_stories/features/family/presentation/invite_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../helpers/pump_app.dart';

class _FakeActions implements InviteActions {
  final whatsapp = <String>[];
  final shared = <String>[];
  final copied = <String>[];
  @override
  Future<bool> openWhatsApp(String text) async {
    whatsapp.add(text);
    return true;
  }

  @override
  Future<void> share(String text) async => shared.add(text);
  @override
  Future<void> copy(String text) async => copied.add(text);
}

Widget _page(
  _FakeActions fake, {
  bool owner = false,
  Future<ShortInviteCode?> Function()? rotate,
}) => ProviderScope(
  overrides: [inviteActionsProvider.overrideWithValue(fake)],
  child: InvitePage(
    familyName: 'Ashmawy',
    shortCode: const ShortInviteCode('7K4QM9X'),
    isOwner: owner,
    onRotate: rotate ?? () async => null,
  ),
);

void main() {
  testWidgets('shows QR, code, and sends the same link everywhere', (t) async {
    final fake = _FakeActions();
    await t.pumpApp(_page(fake));
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('7K4-QM9X'), findsOneWidget);

    await t.tap(find.text(l10nEn.inviteSendWhatsApp));
    await t.tap(find.text(l10nEn.inviteShareOther));
    await t.tap(find.text(l10nEn.inviteCopy));
    await t.pump();
    expect(fake.whatsapp.single, contains('familystories://join/7K4QM9X'));
    expect(fake.shared.single, contains('7K4-QM9X'));
    expect(fake.copied.single, '7K4QM9X');
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('non-owner has no change-code menu', (t) async {
    await t.pumpApp(_page(_FakeActions()));
    expect(find.byTooltip(l10nEn.inviteMore), findsNothing);
    await t.expectAccessible();
  });

  testWidgets('owner changes the code only after confirming', (t) async {
    var rotated = 0;
    await t.pumpApp(
      _page(
        _FakeActions(),
        owner: true,
        rotate: () async {
          rotated++;
          return const ShortInviteCode('AAAAAAA');
        },
      ),
    );
    await t.tap(find.byTooltip(l10nEn.inviteMore));
    await t.pumpAndSettle();
    await t.tap(find.text(l10nEn.inviteChangeCode));
    await t.pumpAndSettle();
    await t.tap(find.text(l10nEn.cancel));
    await t.pumpAndSettle();
    expect(rotated, 0);

    await t.tap(find.byTooltip(l10nEn.inviteMore));
    await t.pumpAndSettle();
    await t.tap(find.text(l10nEn.inviteChangeCode));
    await t.pumpAndSettle();
    await t.tap(find.text(l10nEn.inviteChangeConfirm));
    await t.pumpAndSettle(const Duration(seconds: 5));
    expect(rotated, 1);
    expect(find.text('AAA-AAAA'), findsOneWidget);
  });
}
