import 'dart:convert';

import 'package:family_stories/features/prompts/domain/interview_prompt.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const kPromptLibraryAsset = 'assets/prompts/prompts.json';

/// Loaded once and cached for the life of the app.
final promptLibraryProvider = FutureProvider<PromptLibrary>((ref) async {
  final raw = await rootBundle.loadString(kPromptLibraryAsset);
  return PromptLibrary.fromJson(jsonDecode(raw) as Map<String, dynamic>);
});
