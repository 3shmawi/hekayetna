@Tags(['golden'])
library;

import 'dart:async';
import 'dart:io';

import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/network/result.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_theme.dart';
import 'package:family_stories/core/ui/app_ui.dart' hide StoryVisibility;
import 'package:family_stories/features/auth/presentation/sign_in_view.dart';
import 'package:family_stories/features/family/data/demo_family_repository.dart';
import 'package:family_stories/features/family/data/models.dart';
import 'package:family_stories/features/family/domain/family_graph.dart';
import 'package:family_stories/features/family/domain/invite_code.dart';
import 'package:family_stories/features/family/presentation/display_name_dialog.dart';
import 'package:family_stories/features/family/presentation/family_screens.dart';
import 'package:family_stories/features/family/presentation/family_tree_page.dart';
import 'package:family_stories/features/family/presentation/family_tree_providers.dart';
import 'package:family_stories/features/family/presentation/invite_page.dart';
import 'package:family_stories/features/family/presentation/join_screen.dart';
import 'package:family_stories/features/family/presentation/person_sheet.dart';
import 'package:family_stories/features/onboarding/presentation/onboarding_page.dart';
import 'package:family_stories/features/recording/data/memory_draft_store.dart';
import 'package:family_stories/features/recording/data/recorder_service.dart';
import 'package:family_stories/features/recording/presentation/continue_recording_view.dart';
import 'package:family_stories/features/recording/presentation/record_page.dart';
import 'package:family_stories/features/recording/presentation/record_view.dart';
import 'package:family_stories/features/settings/data/settings_repository.dart';
import 'package:family_stories/features/settings/presentation/settings_controller.dart';
import 'package:family_stories/features/stories/data/models.dart';
import 'package:family_stories/features/stories/presentation/story_feed_page.dart';
import 'package:family_stories/features/stories/presentation/story_providers.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/family/domain/family_fixtures.dart';

/// Visual-evidence screenshots with the app's REAL fonts (Inter + Cairo),
/// unlike the layout goldens which use Flutter's box test font. These
/// prove typography, Arabic shaping and RTL on the 375x812 design frame.
/// They are not compared in CI: they are regenerated on demand and
/// inspected by a human/agent. Output: test/screenshot/shots/*.png.
final Map<String, Widget Function()> scenes = {
  'stories_feed': () => const _DemoScope(child: StoryFeedPage()),
  'sign_in': () => SignInView(
    onSubmit: (_, _, _) {},
    onForgotPassword: (_) {},
    onSendLink: (_) {},
  ),
  'family': () => const _DemoScope(child: FamilyHomeScreen()),
  'invite_page': () => _DemoScope(
    child: InvitePage(
      familyName: 'Ashmawy family',
      shortCode: const ShortInviteCode('7K4QM9X'),
      isOwner: true,
      onRotate: () async => null,
    ),
  ),
  'join_screen': () => const _DemoScope(child: JoinScreen(rawCode: '7K4QM9X')),
  'join_invalid': () =>
      const _DemoScope(child: JoinScreen(rawCode: '../../etc/passwd')),
  'join_arname_plural': () => ProviderScope(
    overrides: [
      familyRepositoryProvider.overrideWithValue(
        _PreviewRepo('عيلة أشماوي', 12),
      ),
    ],
    child: const _DemoScope(child: JoinScreen(rawCode: '7K4QM9X')),
  ),
  'join_mixed_name': () => ProviderScope(
    overrides: [
      familyRepositoryProvider.overrideWithValue(
        _PreviewRepo('عيلة Ashmawy', 2),
      ),
    ],
    child: const _DemoScope(child: JoinScreen(rawCode: '7K4QM9X')),
  ),
  'name_prompt': () => const _DemoScope(child: _NamePromptHost()),
  'record': () => const _DemoScope(child: RecordPage()),
  'record_recording': () => _recordView(RecordButtonState.recording),
  'record_paused': () => _recordView(RecordButtonState.paused),
  'record_resume': () => ContinueRecordingView(
    items: const [
      ResumeItem(
        id: 'a',
        title: 'Ramadan in the old house',
        narratorName: 'Sitto Fatma',
        stoppedAtLabel: 'yesterday at 8:40 pm',
        segmentMs: [240000, 225000],
      ),
    ],
    playingId: null,
    onPlayToggle: (_) {},
    onContinue: (_) {},
    onSave: (_) {},
    onDelete: (_) {},
    onClose: () {},
  ),
  'onboarding': () => const OnboardingPage(),
  'tree_page': () => ProviderScope(
    overrides: [
      familyGraphProvider.overrideWith((ref, _) async => _treeGraph()),
      familyTreeGraphEnabledProvider.overrideWith((ref) async => true),
    ],
    child: Scaffold(
      body: SafeArea(
        child: FamilyTreePage(
          spaceId: 's',
          spaceName: 'Ashmawy family',
          onOpenPerson: (_) {},
        ),
      ),
    ),
  ),
  'person_sheet': () => ProviderScope(
    overrides: [storyFeedProvider.overrideWith2(_TreeFeed.new)],
    child: Scaffold(
      body: SingleChildScrollView(
        child: PersonSheet(graph: _treeGraph(), personId: 'sitto'),
      ),
    ),
  ),
};

FamilyGraph _treeGraph() {
  final fam = bigFamily();
  return FamilyGraph.build(
    persons: fam.persons,
    relationships: fam.rels,
    meId: 'me',
    storiesByNarrator: {
      'sitto': [600, 300, 120],
      'mama': [60],
    },
  );
}

Story _treeStory(String id, String who, String? topic, String title) => Story(
  id: id,
  spaceId: 's',
  title: title,
  visibility: StoryVisibility.family,
  audioPath: 'p/$id.wav',
  durationSeconds: 300,
  createdBy: 'u',
  createdAt: DateTime(2026),
  narratorIds: [who],
  topic: topic,
);

class _TreeFeed extends StoryFeedNotifier {
  _TreeFeed(super.filter);
  @override
  Future<List<Story>> build() async => [
    _treeStory('a', 'sitto', 'childhood_first_home', 'The house by the canal'),
    _treeStory('b', 'sitto', 'how_parents_met', 'How I met your grandfather'),
    _treeStory('c', 'sitto', 'funny_memories', 'The goat at the wedding'),
    _treeStory('d', 'sitto', 'funny_memories', 'The lost shoe'),
  ];
}

Widget _recordView(RecordButtonState state) => Builder(
  builder: (context) => RecordView(
    buttonState: state,
    elapsed: const Duration(minutes: 2, seconds: 14),
    levels: [for (var i = 0; i < 20; i++) (i % 7) / 7],
    narratorName: 'Sitto Amina',
    draftSaved: true,
    canFinish: true,
    topicLabel: 'Childhood & first home',
    promptText: context.l10n.recordPrompt1,
    onDifferentQuestion: () {},
    onClose: () {},
    onToggle: () {},
    onPickNarrator: () {},
    onPickTopic: () {},
    onDone: () {},
  ),
);

Future<void> loadRealFonts() async {
  final fonts = {
    'Inter': [400, 500, 600, 700],
    'Cairo': [400, 500, 600, 700],
  };
  for (final entry in fonts.entries) {
    final loader = FontLoader(entry.key);
    for (final weight in entry.value) {
      final file = File('assets/fonts/${entry.key}/${entry.key}-$weight.ttf');
      final bytes = await file.readAsBytes();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }
  // Icon glyphs too: without the Material Icons font, icons render as boxes
  // and the shots say nothing about them.
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      File(
        // `flutter test` sets FLUTTER_ROOT to the SDK it runs from.
        '${Platform.environment['FLUTTER_ROOT']}'
        '/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ).readAsBytes().then((b) => ByteData.view(b.buffer)),
    );
  await icons.load();
}

late SharedPreferences _prefs;

class _PreviewRepo extends DemoFamilyRepository {
  _PreviewRepo(this.name, this.count);
  final String name;
  final int count;
  @override
  Future<Result<FamilyPreview>> previewFamily(String inviteCode) async =>
      Success(FamilyPreview(name: name, memberCount: count));
}

/// Opens the display-name dialog over an empty screen on first frame.
class _NamePromptHost extends ConsumerStatefulWidget {
  const _NamePromptHost();
  @override
  ConsumerState<_NamePromptHost> createState() => _NamePromptHostState();
}

class _NamePromptHostState extends ConsumerState<_NamePromptHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(showDisplayNameDialog(context, ref, current: ''));
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}

class _DemoScope extends StatelessWidget {
  const _DemoScope({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      draftStoreProvider.overrideWithValue(MemoryDraftStore()),
      recorderServiceProvider.overrideWithValue(_FakeRecorderService()),
      settingsRepositoryProvider.overrideWithValue(SettingsRepository(_prefs)),
    ],
    child: child,
  );
}

/// Idle recorder without the platform plugin (tests have no mic channel).
class _FakeRecorderService implements RecorderService {
  final _controller = StreamController<RecorderState>.broadcast();

  @override
  RecorderState get state => const RecorderState(status: RecorderStatus.idle);

  @override
  Stream<RecorderState> watch() => _controller.stream;

  @override
  Stream<double> get levels => const Stream.empty();

  @override
  List<int>? get waveform => null;

  @override
  Future<bool> ensurePermission() async => false;

  @override
  Future<void> start({
    required String draftId,
    String? narratorPersonId,
    String? topic,
    String? promptId,
  }) async {}

  @override
  Future<void> continueDraft(String draftId) async {}

  @override
  Future<void> pause({PauseReason reason = PauseReason.user}) async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> discard() async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
    await loadRealFonts();
  });

  for (final MapEntry(key: name, value: build) in scenes.entries) {
    for (final locale in const ['en', 'ar']) {
      for (final dark in const [false, true]) {
        if (dark &&
            !(name.startsWith('record') ||
                name.startsWith('tree') ||
                name.startsWith('invite') ||
                name.startsWith('join') ||
                name.startsWith('person'))) {
          continue;
        }
        final tag = dark ? '${locale}_dark' : locale;
        testWidgets('$name · $tag', (tester) async {
          tester.view
            ..physicalSize = const Size(375, 812) * 2
            ..devicePixelRatio = 2;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            ScreenUtilInit(
              designSize: AppDimens.designSize,
              builder: (context, _) => MaterialApp(
                debugShowCheckedModeBanner: false,
                locale: Locale(locale),
                theme: dark ? AppTheme.dark : AppTheme.light,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: build(),
              ),
            ),
          );
          if (name == 'record_recording') {
            // The halo breathes forever; it never settles.
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 800));
          } else {
            await tester.pumpAndSettle();
          }
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('shots/${name}_$tag.png'),
          );
        });
      }
    }
  }
}
