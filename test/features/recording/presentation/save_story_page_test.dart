import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/network/app_failure.dart';
import 'package:family_stories/core/network/connectivity_provider.dart';
import 'package:family_stories/core/network/result.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_theme.dart';
import 'package:family_stories/core/ui/app_ui.dart' hide StoryVisibility;
import 'package:family_stories/features/family/data/family_repository.dart';
import 'package:family_stories/features/family/data/models.dart';
import 'package:family_stories/features/photos/data/models.dart';
import 'package:family_stories/features/photos/data/photo_repository.dart';
import 'package:family_stories/features/recording/data/memory_draft_store.dart';
import 'package:family_stories/features/recording/data/recorder_service.dart';
import 'package:family_stories/features/recording/presentation/save_story_page.dart';
import 'package:family_stories/features/settings/data/settings_repository.dart';
import 'package:family_stories/features/settings/presentation/settings_controller.dart';
import 'package:family_stories/features/stories/data/models.dart';
import 'package:family_stories/features/stories/data/story_repository.dart';
import 'package:family_stories/features/stories/data/story_saver.dart';
import 'package:family_stories/features/stories/presentation/story_providers.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Stories extends Mock implements StoryRepository {}

class _Family extends Mock implements FamilyRepository {}

class _Photos extends Mock implements PhotoRepository {}

class _Recorder extends Mock implements RecorderService {}

class _FakeStory extends Fake implements Story {}

const _space = FamilySpace(id: 'sp1', name: 'Family', inviteCode: 'X');

void main() {
  late _Stories stories;
  late _Family family;
  late _Photos photos;
  late _Recorder recorder;
  late MemoryDraftStore drafts;
  late GoRouter router;
  Story? created;

  setUpAll(() => registerFallbackValue(_FakeStory()));

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    created = null;
    stories = _Stories();
    family = _Family();
    photos = _Photos();
    recorder = _Recorder();
    drafts = MemoryDraftStore();
    await drafts.save(
      StoryDraft(
        id: 'd1',
        filePath: '/tmp/take.wav',
        durationSeconds: 125,
        updatedAt: DateTime(2026),
      ),
    );
    when(
      () => family.getMySpace(),
    ).thenAnswer((_) async => const Success(_space));
    when(() => family.listPersons('sp1')).thenAnswer(
      (_) async => const Success(<Person>[
        Person(id: 'p1', spaceId: 'sp1', fullName: 'Sitto', createdBy: 'u1'),
      ]),
    );
    when(() => family.listMembers('sp1')).thenAnswer(
      (_) async => const Success(<FamilyMember>[
        FamilyMember(
          id: 'm1',
          userId: 'u1',
          displayName: 'Mona',
          role: 'owner',
        ),
        FamilyMember(
          id: 'm2',
          userId: 'u2',
          displayName: 'Omar',
          role: 'member',
        ),
        FamilyMember(
          id: 'm3',
          userId: 'u3',
          displayName: 'Nour',
          role: 'member',
        ),
      ]),
    );
    when(
      () => photos.listPhotos('sp1'),
    ).thenAnswer((_) async => const Success(<Photo>[]));
    when(
      () => stories.getStory(any()),
    ).thenAnswer((_) async => const Success(null));
    when(
      () => stories.uploadAudio(any(), any()),
    ).thenAnswer((i) async => Success(i.positionalArguments[1] as String));
    when(() => stories.createStory(any())).thenAnswer((i) async {
      created = i.positionalArguments[0] as Story;
      return Success(created!);
    });
    when(
      () => stories.deleteAudio(any()),
    ).thenAnswer((_) async => const Success(null));
    when(() => recorder.waveform).thenReturn(List.filled(64, 30));
    when(() => recorder.discard()).thenAnswer((_) async {});
  });

  Future<void> pump(
    WidgetTester tester, {
    bool online = true,
    Locale locale = const Locale('en'),
  }) async {
    tester.view
      ..physicalSize = const Size(375, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    router = GoRouter(
      initialLocation: '/record/new-story/d1',
      routes: [
        GoRoute(
          path: '/record/new-story/:id',
          builder: (_, state) =>
              SaveStoryPage(draftId: state.pathParameters['id']!),
        ),
        GoRoute(path: '/record', builder: (_, _) => const Text('RECORD PAGE')),
        GoRoute(path: '/stories', builder: (_, _) => const Text('FEED PAGE')),
        GoRoute(
          path: '/stories/:id',
          builder: (_, state) => Text('STORY ${state.pathParameters['id']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          draftStoreProvider.overrideWithValue(drafts),
          settingsRepositoryProvider.overrideWithValue(
            SettingsRepository(prefs),
          ),
          familyRepositoryProvider.overrideWithValue(family),
          photoRepositoryProvider.overrideWithValue(photos),
          storyRepositoryProvider.overrideWithValue(stories),
          recorderServiceProvider.overrideWithValue(recorder),
          currentUserIdProvider.overrideWithValue('u1'),
          onlineProvider.overrideWith((ref) => Stream.value(online)),
          storySaverProvider.overrideWithValue(
            StorySaver(
              stories: stories,
              family: family,
              drafts: drafts,
              userId: 'u1',
              joinTake: (_) async => '/tmp/take.wav',
            ),
          ),
        ],
        child: ScreenUtilInit(
          designSize: AppDimens.designSize,
          builder: (context, _) => MaterialApp.router(
            locale: locale,
            theme: AppTheme.light,
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapSave(
    WidgetTester tester, [
    String label = 'Save story',
  ]) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('AC-4: an empty title shows the error and uploads nothing', (
    tester,
  ) async {
    await pump(tester);
    await tapSave(tester);
    expect(find.text('Add a title for the story'), findsOneWidget);
    verifyNever(() => stories.uploadAudio(any(), any()));
  });

  testWidgets('AC-5: the consequence line is exact for each choice', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Only you can hear this'), findsOneWidget);

    await tester.tap(find.text('Selected people'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Omar'));
    await tester.tap(find.text('Nour'));
    await tester.pumpAndSettle();
    expect(find.text('2 people can hear this: Omar, Nour'), findsOneWidget);

    await tester.tap(find.text('The whole family'));
    await tester.pumpAndSettle();
    expect(find.text('Everyone in the family now (3 people)'), findsOneWidget);
  });

  testWidgets('Selected people with nobody cannot be saved', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField).first, 'A title');
    await tester.tap(find.text('Selected people'));
    await tester.pumpAndSettle();
    await tapSave(tester);
    expect(
      find.text('Pick at least one person, or choose Only me'),
      findsOneWidget,
    );
    verifyNever(() => stories.uploadAudio(any(), any()));
  });

  testWidgets('AC-6: save creates the story with the recipients and opens it', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField).first, '  Moving to Shubra ');
    await tester.tap(find.text('Selected people'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Omar'));
    await tester.tap(find.text('Nour'));
    await tester.pumpAndSettle();
    await tapSave(tester);

    expect(created, isNotNull);
    expect(created!.title, 'Moving to Shubra');
    expect(created!.visibility, StoryVisibility.selected);
    expect(created!.recipientUserIds, unorderedEquals(['u2', 'u3']));
    expect(created!.waveform, hasLength(64));
    expect(find.text('STORY ${created!.id}'), findsOneWidget);
    expect(await drafts.get('d1'), isNull);
  });

  testWidgets(
    'AC-6: a failed save keeps the form, the draft and offers Retry',
    (tester) async {
      when(
        () => stories.createStory(any()),
      ).thenAnswer((_) async => const Failed(NetworkFailure()));
      await pump(tester);
      await tester.enterText(find.byType(TextField).first, 'Keep me');
      await tapSave(tester);

      expect(find.text('Retry'), findsOneWidget);
      expect(find.textContaining("The story wasn't saved"), findsOneWidget);
      // names the step that failed: the audio was uploaded, create failed
      expect(find.textContaining('The audio is uploaded'), findsOneWidget);
      expect(find.text('Keep me'), findsOneWidget);
      expect(await drafts.get('d1'), isNotNull);
      expect(find.text('FEED PAGE'), findsNothing);
    },
  );

  testWidgets('AC-7: offline disables Save and says why', (tester) async {
    await pump(tester, online: false);
    expect(
      find.textContaining("You're offline. Your story is safe on this phone"),
      findsOneWidget,
    );
    final save = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Save story'),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('AC-9: Record again asks once, Cancel keeps the take', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Record again'));
    await tester.pumpAndSettle();
    expect(find.text('Record this story again?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await drafts.get('d1'), isNotNull);
    verifyNever(() => recorder.discard());

    await tester.tap(find.text('Record again'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Record again'));
    await tester.pumpAndSettle();
    expect(await drafts.get('d1'), isNull);
    verify(() => recorder.discard()).called(1);
    expect(find.text('RECORD PAGE'), findsOneWidget);
  });

  testWidgets('AC-9: Delete asks once and removes the take', (tester) async {
    await pump(tester);
    await tester.tap(find.widgetWithText(AppButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this recording?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(await drafts.get('d1'), isNull);
    expect(find.text('FEED PAGE'), findsOneWidget);
  });

  testWidgets('a missing draft shows an honest message', (tester) async {
    await drafts.delete('d1');
    await pump(tester);
    expect(
      find.text("This recording can't be found on this phone."),
      findsOneWidget,
    );
  });

  testWidgets('hostile text is saved exactly as typed', (tester) async {
    await pump(tester);
    const hostile =
        "<script>alert(1)</script>'; DROP TABLE stories;-- \u202Eabc";
    await tester.enterText(find.byType(TextField).first, hostile);
    await tapSave(tester);
    expect(created!.title, hostile);
  });

  testWidgets('Arabic: the save screen mirrors and uses Arabic copy', (
    tester,
  ) async {
    await pump(tester, locale: const Locale('ar'));
    expect(find.text('احفظ الحكاية'), findsWidgets);
    expect(find.text('Save story'), findsNothing);
    final context = tester.element(find.text('احفظ الحكاية').first);
    expect(Directionality.of(context), TextDirection.rtl);
  });
}
