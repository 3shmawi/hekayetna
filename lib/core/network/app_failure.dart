import 'dart:async';
import 'dart:io';

import 'package:family_stories/core/backend/backend_errors.dart';
import 'package:flutter/foundation.dart';

/// Every error the UI can show, independent of where it came from
/// (the backend, HTTP, platform). Repositories return these inside a `Result`
/// instead of throwing.
@immutable
sealed class AppFailure implements Exception {
  const AppFailure([this.cause]);

  /// The original error, for logs and monitoring — never shown to users.
  final Object? cause;

  /// Worth retrying automatically (the device or server may recover).
  bool get isRetryable => false;

  /// Maps any thrown error to a failure.
  static AppFailure from(Object error) => switch (error) {
    AppFailure() => error,
    SocketException() || HttpException() => NetworkFailure(error),
    TimeoutException() => TimeoutFailure(error),
    FormatException() => ValidationFailure(error),
    // REST API errors (Dio): core/api/api_errors.dart.
    // Backend errors (Supabase / Firebase): core/backend/backend_errors.dart.
    _ => backendFailure(error) ?? UnknownFailure(error),
  };
}

/// No internet or the host can't be reached.
final class NetworkFailure extends AppFailure {
  const NetworkFailure([super.cause]);

  @override
  bool get isRetryable => true;
}

final class TimeoutFailure extends AppFailure {
  const TimeoutFailure([super.cause]);

  @override
  bool get isRetryable => true;
}

/// Not signed in, session expired, or not allowed (RLS).
final class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure([super.cause]);
}

/// The thing already exists in a different form; nothing was overwritten.
final class ConflictFailure extends AppFailure {
  const ConflictFailure([super.cause]);
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure([super.cause]);
}

/// Invalid input or data in an unexpected shape.
final class ValidationFailure extends AppFailure {
  const ValidationFailure([super.cause]);
}

final class ServerFailure extends AppFailure {
  const ServerFailure([super.cause]);

  @override
  bool get isRetryable => true;
}

/// The phone is almost full, so recording cannot start or continue.
final class StorageFullFailure extends AppFailure {
  const StorageFullFailure([super.cause]);
}

/// Why joining or managing a family space didn't work.
enum FamilyFailureReason {
  invalidInviteCode,
  memberRemoved,
  notOwner,
  cannotRemoveSelf,
  membershipNotFound,
}

/// A family-space rule the backend refused, with a message the user can act on.
final class FamilyFailure extends AppFailure {
  const FamilyFailure(this.reason, [super.cause]);

  final FamilyFailureReason reason;
}

final class UnknownFailure extends AppFailure {
  const UnknownFailure([super.cause]);
}

/// Why a sign-in, sign-up or account change didn't work.
enum AuthFailureReason {
  invalidCredentials,
  emailInUse,
  weakPassword,
  invalidEmail,
  emailNotConfirmed,

  /// Deleting the account (or changing the password) needs a fresh
  /// sign-in first.
  recentLoginRequired,

  /// The user closed the Apple / Google sheet: show nothing.
  cancelled,

  /// The backend isn't set up in this env file yet.
  notConfigured,
}

/// A sign-in or account error the user can act on.
final class AuthFailure extends AppFailure {
  const AuthFailure(this.reason, [super.cause]);

  final AuthFailureReason reason;
}
