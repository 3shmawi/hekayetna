import 'package:family_stories/core/auth/auth.dart';
import 'package:family_stories/core/auth/backend_auth.dart';
import 'package:family_stories/core/review/review_prompt.dart';
import 'package:family_stories/features/onboarding/data/onboarding.dart';
import 'package:family_stories/features/recording/data/draft_store.dart';
import 'package:family_stories/features/recording/data/file_draft_store.dart';
import 'package:family_stories/features/settings/data/settings_repository.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Composition root: long-lived objects created once at start-up.
/// Add new repositories / services here.
abstract final class Dependencies {
  static late final SettingsRepository settingsRepository;

  /// Private on-device store for unpublished recording drafts.
  static late final DraftStore draftStore;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    settingsRepository = SettingsRepository(prefs);
    await ReviewPrompt.recordLaunch(prefs);
    Onboarding.load(prefs);
    final docs = await getApplicationDocumentsDirectory();
    draftStore = FileDraftStore(directoryPath: '${docs.path}/drafts');
    await Auth.start(BackendAuthService());
  }
}
