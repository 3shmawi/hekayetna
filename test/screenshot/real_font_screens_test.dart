@Tags(['golden'])
library;

import 'dart:async';
import 'dart:io';

import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_theme.dart';
import 'package:family_stories/features/auth/presentation/sign_in_view.dart';
import 'package:family_stories/features/family/presentation/family_screens.dart';
import 'package:family_stories/features/onboarding/presentation/onboarding_page.dart';
import 'package:family_stories/features/recording/data/memory_draft_store.dart';
import 'package:family_stories/features/recording/data/recorder_service.dart';
import 'package:family_stories/features/recording/presentation/record_screen.dart';
import 'package:family_stories/features/stories/presentation/story_screens.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

/// Visual-evidence screenshots with the app's REAL fonts (Inter + Cairo),
/// unlike the layout goldens which use Flutter's box test font. These
/// prove typography, Arabic shaping and RTL on the 375x812 design frame.
/// They are not compared in CI: they are regenerated on demand and
/// inspected by a human/agent. Output: test/screenshot/shots/*.png.
final Map<String, Widget Function()> scenes = {
  'stories_feed': () => const _DemoScope(child: StoryFeedScreen()),
  'sign_in': () => SignInView(
    onSubmit: (_, _, _) {},
    onForgotPassword: (_) {},
    onSendLink: (_) {},
  ),
  'family': () => const _DemoScope(child: FamilyHomeScreen()),
  'record': () => const _DemoScope(child: RecordScreen()),
  'onboarding': () => const OnboardingPage(),
};

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

class _DemoScope extends StatelessWidget {
  const _DemoScope({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      draftStoreProvider.overrideWithValue(MemoryDraftStore()),
      recorderServiceProvider.overrideWithValue(_FakeRecorderService()),
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
  Future<bool> ensurePermission() async => false;

  @override
  Future<void> start({
    required String draftId,
    String? narratorPersonId,
    String? topic,
    String? promptId,
  }) async {}

  @override
  Future<void> pause() async {}

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
  setUp(loadRealFonts);

  for (final MapEntry(key: name, value: build) in scenes.entries) {
    for (final locale in const ['en', 'ar']) {
      testWidgets('$name · $locale', (tester) async {
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
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: build(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('shots/${name}_$locale.png'),
        );
      });
    }
  }
}
