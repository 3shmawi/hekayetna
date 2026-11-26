/// An invite code the app may send to the backend: either a 7-character
/// short code or an old UUID code. Anything else (hostile or junk input)
/// is rejected here, before any network call.
sealed class InviteCode {
  const InviteCode();

  /// Parses what a person typed, scanned or opened. Returns null for
  /// anything that is not a valid code.
  static InviteCode? parse(String? raw) {
    if (raw == null || raw.length > 64) return null;
    final trimmed = raw.trim();
    if (_uuid.hasMatch(trimmed)) return UuidInviteCode(trimmed.toLowerCase());
    final cleaned = trimmed.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    if (cleaned.length == 7 && _short.hasMatch(cleaned)) {
      return ShortInviteCode(cleaned);
    }
    return null;
  }

  static final _uuid = RegExp(
    '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// The backend alphabet: no 0, O, 1, I or L.
  static final _short = RegExp(r'^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{7}$');

  /// What the backend and the links carry (no dash).
  String get value;
}

final class ShortInviteCode extends InviteCode {
  const ShortInviteCode(this.value);

  @override
  final String value;

  /// For people: `7K4-QM9`.
  String get display => '${value.substring(0, 3)}-${value.substring(3)}';
}

final class UuidInviteCode extends InviteCode {
  const UuidInviteCode(this.value);

  @override
  final String value;
}

/// The links a short code travels in. The https host comes from config
/// (null until the domain is verified), never hard-coded.
abstract final class InviteLinks {
  static const scheme = 'familystories';

  static String deepLink(ShortInviteCode code) =>
      '$scheme://join/${code.value}';

  static String? webLink(ShortInviteCode code, {required String? host}) =>
      host == null || host.isEmpty ? null : 'https://$host/join/${code.value}';
}
