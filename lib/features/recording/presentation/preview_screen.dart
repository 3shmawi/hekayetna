import 'dart:async';
import 'dart:io';

import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/theme/app_colors.dart';
import 'package:family_stories/features/recording/data/segment_joiner.dart';
import 'package:family_stories/features/stories/data/models.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

/// Listen-before-saving step. The take only becomes a story after the person
/// hears it and chooses to continue; re-recording is one tap.
class RecordingPreviewScreen extends ConsumerStatefulWidget {
  const RecordingPreviewScreen({required this.draftId, super.key});
  final String draftId;

  @override
  ConsumerState<RecordingPreviewScreen> createState() =>
      _RecordingPreviewScreenState();
}

class _RecordingPreviewScreenState
    extends ConsumerState<RecordingPreviewScreen> {
  final _player = AudioPlayer();
  StoryDraft? _draft;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final drafts = await ref.read(draftStoreProvider).list();
      final draft = drafts.where((d) => d.id == widget.draftId).firstOrNull;
      // Local drafts are device files; a URL path is a bundled fixture used by
      // the review/screenshot entrypoints, never a real take.
      final isFixture = draft != null && draft.filePath.startsWith('http');
      if (draft == null || (!isFixture && !File(draft.filePath).existsSync())) {
        setState(() => _loadError = 'missing');
        return;
      }
      if (isFixture) {
        await _player.setUrl(draft.filePath);
      } else {
        // A take is several segments: play them as one joined file.
        final multi =
            draft.segments.length > 1 || draft.filePath.endsWith('.wav');
        final path = multi
            ? await SegmentJoiner.join(
                draft.segments,
                '${File(draft.filePath).parent.path}/preview.wav',
              )
            : draft.filePath;
        await _player.setFilePath(path);
      }
      setState(() => _draft = draft);
    } on Exception catch (_) {
      setState(() => _loadError = 'missing');
    }
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final draft = _draft;
    return Scaffold(
      appBar: AppBar(title: Text(s.previewTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _loadError != null
            ? Center(child: Text(s.errorUnknown))
            : draft == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  Text(
                    _fmt(Duration(seconds: draft.durationSeconds)),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 24),
                  StreamBuilder<PlayerState>(
                    stream: _player.playerStateStream,
                    builder: (context, snap) {
                      final playing = snap.data?.playing ?? false;
                      return Center(
                        child: Material(
                          color: AppColors.terracotta,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () async {
                              if (playing) {
                                await _player.pause();
                              } else {
                                final dur = _player.duration;
                                if (dur != null && _player.position >= dur) {
                                  await _player.seek(Duration.zero);
                                }
                                await _player.play();
                              }
                            },
                            child: SizedBox(
                              width: 96,
                              height: 96,
                              child: Icon(
                                playing ? Icons.pause : Icons.play_arrow,
                                size: 56,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () async {
                      await _player.stop();
                      if (context.mounted) {
                        context.pushReplacement(
                          '/record/new-story/${draft.id}',
                        );
                      }
                    },
                    child: Text(s.continueLabel),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await _player.stop();
                      await ref.read(draftStoreProvider).delete(draft.id);
                      if (context.mounted) context.pushReplacement('/record');
                    },
                    icon: const Icon(Icons.mic),
                    label: Text(s.reRecord),
                  ),
                ],
              ),
      ),
    );
  }

  String _fmt(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}
