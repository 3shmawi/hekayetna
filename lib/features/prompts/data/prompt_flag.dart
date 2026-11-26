import 'package:family_stories/core/feature_flags/feature_flags.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether any question entry point shows. Off in every flavor until the
/// owner turns `interview_prompts` on in PostHog (spec 07, AC-7).
final interviewPromptsEnabledProvider = FutureProvider<bool>(
  (ref) => FeatureFlags.isEnabled(Flags.interviewPrompts),
);
