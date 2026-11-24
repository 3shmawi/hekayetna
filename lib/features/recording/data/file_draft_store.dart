import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:family_stories/features/recording/data/draft_store.dart';
import 'package:family_stories/features/stories/data/models.dart';

/// JSON index in the app documents directory. Audio files live beside it;
/// the index is what makes an interrupted session recoverable: on launch the
/// app lists drafts and offers to continue. Device/OS limits (force-stop
/// mid-write, storage reclamation) are documented in docs/architecture.md and
/// verified on real devices before being claimed.
class FileDraftStore implements DraftStore {
  FileDraftStore({required this.directoryPath});

  final String directoryPath;

  File get _indexFile => File('$directoryPath/drafts.json');

  @override
  Future<List<StoryDraft>> list() async {
    try {
      final file = _indexFile;
      if (!file.existsSync()) return [];
      final raw = jsonDecode(await file.readAsString()) as List;
      final drafts = [
        for (final j in raw)
          StoryDraft.fromJson(Map<String, dynamic>.from(j as Map)),
      ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return drafts;
    } on FormatException {
      return []; // corrupt index: behave as empty, never crash recording
    }
  }

  @override
  Future<StoryDraft?> get(String id) async {
    final all = await list();
    for (final d in all) {
      if (d.id == id) return d;
    }
    return null;
  }

  @override
  Future<void> save(StoryDraft draft) async {
    final all = await list();
    all
      ..removeWhere((d) => d.id == draft.id)
      ..add(draft);
    await _write(all);
  }

  @override
  Future<void> delete(String id) async {
    final all = await list();
    final draft = all.where((d) => d.id == id).firstOrNull;
    all.removeWhere((d) => d.id == id);
    await _write(all);
    if (draft != null) {
      final f = File(draft.filePath);
      if (f.existsSync()) unawaited(f.delete());
    }
  }

  Future<void> _write(List<StoryDraft> drafts) async {
    final file = _indexFile;
    await file.create(recursive: true);
    // Write-then-rename so a crash mid-write never leaves a torn index.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode([for (final d in drafts) d.toJson()]));
    await tmp.rename(file.path);
  }
}
