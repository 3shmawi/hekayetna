import 'package:family_stories/core/network/app_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Maps Supabase errors to an [AppFailure]; `null` for anything else.
AppFailure? backendFailure(Object error) => switch (error) {
  AuthWeakPasswordException() => AuthFailure(
    AuthFailureReason.weakPassword,
    error,
  ),
  AuthException(code: 'invalid_credentials') => AuthFailure(
    AuthFailureReason.invalidCredentials,
    error,
  ),
  AuthException(code: 'user_already_exists' || 'email_exists') => AuthFailure(
    AuthFailureReason.emailInUse,
    error,
  ),
  AuthException(code: 'email_not_confirmed') => AuthFailure(
    AuthFailureReason.emailNotConfirmed,
    error,
  ),
  AuthException(code: 'email_address_invalid' || 'validation_failed') =>
    AuthFailure(AuthFailureReason.invalidEmail, error),
  AuthException(code: 'reauthentication_needed' || 'same_password') =>
    AuthFailure(AuthFailureReason.recentLoginRequired, error),
  FunctionException(status: 401 || 403) => UnauthorizedFailure(error),
  FunctionException() => ServerFailure(error),
  AuthException() => UnauthorizedFailure(error),
  PostgrestException(:final message) when _familyReason(message) != null =>
    FamilyFailure(_familyReason(message)!, error),
  PostgrestException(code: 'PGRST116') => NotFoundFailure(error),
  PostgrestException(code: '42501') => UnauthorizedFailure(error),
  PostgrestException(:final String code) when code.startsWith('22') =>
    ValidationFailure(error),
  PostgrestException() => ServerFailure(error),
  _ => null,
};

FamilyFailureReason? _familyReason(String message) => switch (message) {
  'invalid_invite_code' => FamilyFailureReason.invalidInviteCode,
  'member_removed' => FamilyFailureReason.memberRemoved,
  'not_owner' => FamilyFailureReason.notOwner,
  'cannot_remove_self' => FamilyFailureReason.cannotRemoveSelf,
  'membership_not_found' => FamilyFailureReason.membershipNotFound,
  _ => null,
};
