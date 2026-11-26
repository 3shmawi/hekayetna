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
