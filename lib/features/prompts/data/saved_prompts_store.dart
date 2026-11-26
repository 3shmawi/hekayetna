import 'package:shared_preferences/shared_preferences.dart';

/// Prompt ids the user bookmarked ("Save for later") and the week whose
/// question card they dismissed. Local to the device, never synced.
class SavedPromptsStore {
  SavedPromptsStore(this._prefs);

  final SharedPreferences _prefs;

  static const savedKey = 'prompts.saved_ids';
  static const dismissedKey = 'prompts.weekly_dismissed';

  Set<String> saved() => (_prefs.getStringList(savedKey) ?? const []).toSet();

  Future<void> setSaved(String id, {required bool saved}) async {
    final ids = this.saved();
    if (saved) {
      ids.add(id);
    } else {
      ids.remove(id);
    }
    await _prefs.setStringList(savedKey, ids.toList()..sort());
  }

  /// The ISO week key (see `weekKey`) whose card was dismissed, if any.
  String? dismissedWeek() => _prefs.getString(dismissedKey);

  Future<void> dismissWeek(String weekKey) =>
      _prefs.setString(dismissedKey, weekKey);

  bool isWeekDismissed(String weekKey) => dismissedWeek() == weekKey;
}
