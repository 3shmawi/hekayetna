import 'package:family_stories/core/analytics/analytics.dart';
import 'package:family_stories/features/prompts/data/saved_prompts_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Override in tests with a store over mock preferences.
final savedPromptsStoreProvider = FutureProvider<SavedPromptsStore>(
  (ref) async => SavedPromptsStore(await SharedPreferences.getInstance()),
);

/// The prompt ids bookmarked with "Save for later" (device only).
final savedPromptsProvider =
    AsyncNotifierProvider<SavedPromptsNotifier, Set<String>>(
      SavedPromptsNotifier.new,
    );

class SavedPromptsNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async =>
      (await ref.watch(savedPromptsStoreProvider.future)).saved();

  Future<void> toggle(String id) async {
    final store = await ref.read(savedPromptsStoreProvider.future);
    final next = {...state.value ?? const <String>{}};
    final nowSaved = next.add(id);
    if (!nowSaved) next.remove(id);
    state = AsyncData(next);
    await store.setSaved(id, saved: nowSaved);
  }
}

/// Answered questions for the person being asked: prompt id to the title of
/// the story that answers it. Empty until the `stories.prompt_id` column
/// exists (spec 07 part B, held with the migration gate), so no card shows
/// as answered yet. Tests override it.
// ignore: specify_nonobvious_property_types
final answeredPromptsProvider = Provider.family<Map<String, String>, String?>(
  (ref, personId) => const {},
);

/// Today, injectable so a test can fix the ISO week.
final promptsClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Where question events go. Analytics by default (a no-op until the user
/// allows usage data); tests override it to read the events. Never carries
/// question text.
final promptEventsProvider =
    Provider<Future<void> Function(String event, [Map<String, Object>? props])>(
      (ref) => Analytics.capture,
    );
