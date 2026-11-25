import 'dart:async';

import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/analytics/analytics.dart';
import 'package:family_stories/core/network/result.dart';
import 'package:family_stories/core/router/app_routes.dart';
import 'package:family_stories/features/family/data/models.dart';
import 'package:family_stories/features/family/domain/invite_code.dart';
import 'package:family_stories/features/stories/presentation/story_providers.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/join/:code`: shows who you would join and asks before joining. The
/// code comes from a URL anyone can craft, so it is parsed first and junk
/// never reaches the backend.
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({required this.rawCode, super.key});

  final String rawCode;

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  late final InviteCode? _code = InviteCode.parse(widget.rawCode);
  Future<FamilyPreview>? _preview;
  bool _busy = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (_code != null) {
      unawaited(Analytics.capture('invite_opened', {'from': 'link'}));
      _preview = ref
          .read(familyRepositoryProvider)
          .previewFamily(_code.value)
          .unwrap();
      unawaited(
        _preview!.then<void>(
          (_) {},
          onError: (Object _) {
            if (mounted) setState(() => _failed = true);
          },
        ),
      );
      unawaited(Analytics.capture('join_previewed'));
    } else {
      unawaited(Analytics.capture('join_failed', {'reason': 'invalid'}));
    }
  }

  Future<void> _join() async {
    setState(() => _busy = true);
    final r = await ref
        .read(currentSpaceProvider.notifier)
        .joinSpace(_code!.value);
    if (!mounted) return;
    switch (r) {
      case Success():
        unawaited(Analytics.capture('join_completed'));
        context.go(AppRoutes.family);
      case Failed():
        unawaited(Analytics.capture('join_failed', {'reason': 'rejected'}));
        setState(() {
          _busy = false;
          _failed = true;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _code == null || _failed
              ? l10n.joinInvalidTitle
              : l10n.joinConfirmTitle,
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _code == null || _failed
              ? _Message(
                  text: l10n.joinInvalid,
                  action: l10n.cancel,
                  onTap: () => context.go(AppRoutes.home),
                )
              : FutureBuilder<FamilyPreview>(
                  future: _preview,
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return _Message(
                        text: l10n.joinInvalid,
                        action: l10n.cancel,
                        onTap: () => context.go(AppRoutes.home),
                      );
                    }
                    final p = snap.data;
                    if (p == null) return const CircularProgressIndicator();
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          p.name,
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.joinMemberCount(p.memberCount),
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _busy ? null : _join,
                          child: Text(l10n.joinConfirmButton),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => context.go(AppRoutes.home),
                          child: Text(l10n.cancel),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.text,
    required this.action,
    required this.onTap,
  });

  final String text;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(text, textAlign: TextAlign.center),
      const SizedBox(height: 16),
      TextButton(onPressed: onTap, child: Text(action)),
    ],
  );
}
