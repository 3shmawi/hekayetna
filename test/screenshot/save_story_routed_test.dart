@Tags(['golden'])
library;

import 'dart:io';

import 'package:family_stories/app/app_providers.dart';
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

import '../helpers/pump_app.dart';

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

  late File takeFile;

  setUp(() async {
    await loadAppFonts();
    final dir = Directory.systemTemp.createTempSync('savepage_');
    addTearDown(() => dir.deleteSync(recursive: true));
    takeFile = File('${dir.path}/take.wav')..writeAsBytesSync([1, 2, 3, 4]);
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
      () => stories.audioSize(any()),
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
    Size size = const Size(375, 812),
    double textScale = 1,
    bool dark = false,
    double keyboard = 0,
  }) async {
    tester.view
      ..physicalSize = size
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
              joinTake: (_) async => takeFile.path,
            ),
          ),
        ],
        child: ScreenUtilInit(
          designSize: AppDimens.designSize,
          builder: (context, _) => MaterialApp.router(
            locale: locale,
            theme: dark ? AppTheme.dark : AppTheme.light,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
                viewInsets: EdgeInsets.only(bottom: keyboard),
              ),
              child: child!,
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> shot(WidgetTester tester, String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('evidence/save_story_$name.png'),
  );

  for (final locale in const ['en', 'ar']) {
    for (final dark in const [false, true]) {
      final t = dark ? 'dark' : 'light';
      testWidgets('frame $locale $t', (tester) async {
        SharedPreferences.setMockInitialValues({'settings.locale': locale});
        prefs = await SharedPreferences.getInstance();
        await pump(tester, locale: Locale(locale), dark: dark);
        await shot(tester, 'frame_${locale}_$t');
      });
    }
  }

  testWidgets('small 160% en light', (tester) async {
    await pump(tester, size: const Size(320, 640), textScale: 1.6);
    await shot(tester, 'small_en_light');
  });

  testWidgets('keyboard on the title, en light', (tester) async {
    await pump(tester, keyboard: 280);
    await tester.showKeyboard(find.byType(TextField).first);
    await tester.enterText(
      find.byType(TextField).first,
      'Grandpa and the boat',
    );
    await tester.pumpAndSettle();
    await shot(tester, 'keyboard_en_light');
  });

  testWidgets('empty title error, ar dark', (tester) async {
    SharedPreferences.setMockInitialValues({'settings.locale': 'ar'});
    prefs = await SharedPreferences.getInstance();
    await pump(tester, locale: const Locale('ar'), dark: true);
    await tester.tap(find.byType(AppButton).last);
    await tester.pumpAndSettle();
    await shot(tester, 'error_ar_dark');
  });
}
