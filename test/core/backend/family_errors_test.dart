import 'package:family_stories/core/backend/backend_errors.dart';
import 'package:family_stories/core/network/app_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('family RPC errors map to typed failures', () {
    const cases = {
      'invalid_invite_code': FamilyFailureReason.invalidInviteCode,
      'member_removed': FamilyFailureReason.memberRemoved,
      'not_owner': FamilyFailureReason.notOwner,
      'cannot_remove_self': FamilyFailureReason.cannotRemoveSelf,
      'membership_not_found': FamilyFailureReason.membershipNotFound,
    };
    cases.forEach((message, reason) {
      test(message, () {
        final failure = backendFailure(PostgrestException(message: message));
        expect(failure, isA<FamilyFailure>());
        expect((failure! as FamilyFailure).reason, reason);
      });
    });
  });

  test('an unrelated database error stays a server failure', () {
    final failure = backendFailure(const PostgrestException(message: 'boom'));
    expect(failure, isA<ServerFailure>());
  });
}
