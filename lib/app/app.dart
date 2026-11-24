import 'package:family_stories/app/app_shell.dart';
import 'package:family_stories/features/settings/presentation/settings_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Root widget: the ProviderScope, then the shell.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => const ProviderScope(child: _AppView());
}

class _AppView extends ConsumerWidget {
  const _AppView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(settings: ref.watch(settingsControllerProvider));
  }
}
