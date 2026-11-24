import 'dart:ui';

import 'package:family_stories/core/backend/backend.dart';
import 'package:family_stories/core/di/dependencies.dart';
import 'package:family_stories/features/family/data/demo_family_repository.dart';
import 'package:family_stories/features/family/data/family_repository.dart';
import 'package:family_stories/features/family/data/supabase_family_repository.dart';
import 'package:family_stories/features/photos/data/demo_photo_repository.dart';
import 'package:family_stories/features/photos/data/photo_repository.dart';
import 'package:family_stories/features/photos/data/supabase_photo_repository.dart';
import 'package:family_stories/features/recording/data/draft_store.dart';
import 'package:family_stories/features/recording/data/recorder_service.dart';
import 'package:family_stories/features/recording/data/recording_background.dart';
import 'package:family_stories/features/recording/data/recording_background_binder.dart';
import 'package:family_stories/features/recording/data/segment_recorder.dart';
import 'package:family_stories/features/recording/data/segmented_recorder_service.dart';
import 'package:family_stories/features/recording/data/storage_space.dart';
import 'package:family_stories/features/stories/data/demo_story_repository.dart';
import 'package:family_stories/features/stories/data/story_repository.dart';
import 'package:family_stories/features/stories/data/supabase_story_repository.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Feature providers: every screen reads its data through one of these.
/// With no Supabase project configured ([Backend.isConfigured] false) the
/// app runs on in-memory demo repositories and the UI says so on screen.
final isDemoModeProvider = Provider<bool>((ref) => !Backend.isConfigured);

/// The signed-in user's id; the demo user when no backend is configured.
final currentUserIdProvider = Provider<String?>((ref) {
  if (ref.watch(isDemoModeProvider)) return 'demo-user';
  return Backend.client.auth.currentUser?.id;
});

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Backend.client,
);

final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  if (ref.watch(isDemoModeProvider)) return DemoFamilyRepository();
  return SupabaseFamilyRepository(ref.watch(supabaseClientProvider));
});

final photoRepositoryProvider = Provider<PhotoRepository>((ref) {
  if (ref.watch(isDemoModeProvider)) return DemoPhotoRepository();
  return SupabasePhotoRepository(ref.watch(supabaseClientProvider));
});

final storyRepositoryProvider = Provider<StoryRepository>((ref) {
  if (ref.watch(isDemoModeProvider)) return DemoStoryRepository();
  return SupabaseStoryRepository(ref.watch(supabaseClientProvider));
});

final recorderServiceProvider = Provider<RecorderService>((ref) {
  final service = SegmentedRecorderService(
    draftStore: ref.watch(draftStoreProvider),
    recorder: RecordSegmentRecorder(),
    freeBytes: StorageSpace.freeBytes,
  );
  ref.onDispose(service.dispose);
  final binder = RecordingBackgroundBinder(
    recorder: service,
    background: createRecordingBackground(),
    labels: _recordingLabels,
  );
  ref.onDispose(binder.dispose);
  return service;
});

/// Notification text in the phone's language (the service has no
/// BuildContext).
BackgroundLabels _recordingLabels() {
  final l10n = lookupAppLocalizations(PlatformDispatcher.instance.locale);
  return BackgroundLabels(
    title: l10n.recordNotificationTitle,
    pausedTitle: l10n.recordNotificationPausedTitle,
    pause: l10n.recordNotificationPause,
    resume: l10n.recordNotificationResume,
    stop: l10n.recordNotificationStop,
  );
}

/// Private on-device draft recordings. Created in [Dependencies.init].
final draftStoreProvider = Provider<DraftStore>(
  (ref) => Dependencies.draftStore,
);
