import 'package:family_stories/features/family/domain/invite_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parse', () {
    test('accepts a short code in any case, with spaces or a dash', () {
      for (final raw in ['7K4QM9X', '7k4qm9x', '7K4-QM9X', ' 7k4 qm9x ']) {
        final c = InviteCode.parse(raw);
        expect(c, isA<ShortInviteCode>(), reason: raw);
        expect(c!.value, '7K4QM9X');
      }
      expect(
        (InviteCode.parse('7K4QM9X')! as ShortInviteCode).display,
        '7K4-QM9X',
      );
    });

    test('accepts an old UUID code', () {
      final c = InviteCode.parse('3F2504E0-4F89-41D3-9A0C-0305E82C3301');
      expect(c, isA<UuidInviteCode>());
      expect(c!.value, '3f2504e0-4f89-41d3-9a0c-0305e82c3301');
    });

    test('rejects hostile and junk input without throwing', () {
      final hostile = <String?>[
        null,
        '',
        '   ',
        '../../etc/passwd',
        'x' * 10000,
        '7K4QM9\u0000X',
        '7K4QM9%00',
        '🙂🙂🙂🙂🙂🙂🙂',
        'javascript:alert(1)',
        'ABC-DEF; drop table',
        '0O1ILAA', // characters outside the alphabet
        '7K4QM9', // too short
        '7K4QM9XY', // too long
        '3F2504E0-4F89-41D3-9A0C-0305E82C330', // short UUID
      ];
      for (final raw in hostile) {
        expect(InviteCode.parse(raw), isNull, reason: '$raw');
      }
    });
  });

  group('links', () {
    const code = ShortInviteCode('7K4QM9X');
    test('deep link carries the code without a dash', () {
      expect(InviteLinks.deepLink(code), 'familystories://join/7K4QM9X');
    });
    test('web link needs a configured host', () {
      expect(InviteLinks.webLink(code, host: null), isNull);
      expect(InviteLinks.webLink(code, host: ''), isNull);
      expect(
        InviteLinks.webLink(code, host: 'hekayetna.app'),
        'https://hekayetna.app/join/7K4QM9X',
      );
    });
  });
}
