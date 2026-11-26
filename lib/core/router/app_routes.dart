/// Every route path in one place. Each path is also a deep link:
/// `familystories://<path>` and, once the domain is verified,
/// `https://example.com<path>`. Document new paths in
/// docs/deep_links.md.
abstract final class AppRoutes {
  /// The app's default destination: the stories feed.
  static const String home = stories;
  static const stories = '/stories';
  static const record = '/record';
  static const family = '/family';
  static const settings = '/settings';
  static const signIn = '/sign-in';
  static const account = '/account';
  static const newPassword = '/new-password';
  static const welcome = '/welcome';
  static const prompts = '/prompts';

  /// Nested paths (used with `context.push`, never as branch roots).
  static String storyDetail(String id) => '/stories/$id';
  static String recordNewStory(String draftId) => '/record/new-story/$draftId';
  static String personDetail(String id) => '/family/people/$id';

  /// Paths that need a signed-in user; signed-out users are sent to
  /// [signIn] first (core/auth/auth_redirect.dart). In demo mode (no
  /// backend configured) everything is reachable so the app stays
  /// explorable.
  static const Set<String> signedInOnly = {
    stories,
    record,
    family,
    account,
    newPassword,
    prompts,
  };
}
