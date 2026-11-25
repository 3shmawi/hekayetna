import 'dart:convert';
import 'dart:io';

import 'package:family_stories/features/recording/data/draft_store.dart';
import 'package:family_stories/features/stories/data/models.dart';

/// JSON index in the app documents directory. Segment files live in a
/// per-draft directory beside it; the index is what makes an interrupted
/// session recoverable: on launch the
/// app lists drafts and offers to continue. Device/OS limits (force-stop
/// mid-write, storage reclamation) are documented in docs/architecture.md and
/// verified on real devices before being claimed.
class FileDraftStore implements DraftStore {
  FileDraftStore({required this.directoryPath});

  final String directoryPath;

  /// Extension of every segment file. record 7.2.0 has no ADTS encoder, so
  /// the spec's fallback applies: WAV (PCM 16-bit, 44.1 kHz mono) segments
  /// on both platforms. Revisit if a future record version adds ADTS.
  static const segmentExtension = '.wav';

  Directory _draftDir(String draftId) => Directory('$directoryPath/$draftId');

  /// Last segment index issued per draft this session. Combined with the
  /// on-disk scan so reservations stay unique even before the recorder has
  /// created the file; after a restart the disk scan takes over.
  final _reservedSegments = <String, int>{};

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
  Future<String> newSegmentPath(String draftId) async {
    final dir = _draftDir(draftId);
    await dir.create(recursive: true);
    var maxIndex = _reservedSegments[draftId] ?? 0;
    await for (final entity in dir.list()) {
      final match = RegExp(
        r'^seg-(\d+)-',
      ).firstMatch(entity.uri.pathSegments.last);
      if (match != null) {
        final index = int.parse(match.group(1)!);
        if (index > maxIndex) maxIndex = index;
      }
    }
    final next = maxIndex + 1;
    _reservedSegments[draftId] = next;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return '${dir.path}/seg-${next.toString().padLeft(3, '0')}-$stamp$segmentExtension';
  }

  @override
  Future<void> delete(String id) async {
    final all = await list();
    final draft = all.where((d) => d.id == id).firstOrNull;
    all.removeWhere((d) => d.id == id);
    await _write(all);
    if (draft != null) {
      for (final segment in draft.segments) {
        final f = File(segment.path);
        if (f.existsSync()) await f.delete();
      }
      final dir = _draftDir(id);
      if (dir.existsSync()) await dir.delete(recursive: true);
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
