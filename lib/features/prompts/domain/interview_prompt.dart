/// Who a question suits. `elder` questions are about long lives (marriage,
/// hard times, grandchildren) and are offered first to older relatives.
enum PromptAudience { any, elder }

/// One question in one language, with up to two follow-ups.
class PromptText {
  const PromptText({required this.question, required this.followUps});

  factory PromptText.fromJson(Map<String, dynamic> json) => PromptText(
    question: json['question'] as String,
    followUps: [for (final f in json['followUps'] as List) f as String],
  );

  final String question;
  final List<String> followUps;
}

/// A question from `assets/prompts/prompts.json`. The id is stable: it is
/// what a saved story records and what "answered" is matched on.
class InterviewPrompt {
  const InterviewPrompt({
    required this.id,
    required this.topic,
    required this.audience,
    required this.en,
    required this.ar,
  });

  factory InterviewPrompt.fromJson(Map<String, dynamic> json) =>
      InterviewPrompt(
        id: json['id'] as String,
        topic: json['topic'] as String,
        audience: PromptAudience.values.byName(json['audience'] as String),
        en: PromptText.fromJson(json['en'] as Map<String, dynamic>),
        ar: PromptText.fromJson(json['ar'] as Map<String, dynamic>),
      );

  final String id;
  final String topic;
  final PromptAudience audience;
  final PromptText en;
  final PromptText ar;

  /// The text for a language code; anything but Arabic reads English.
  PromptText text(String languageCode) => languageCode == 'ar' ? ar : en;
}

/// The whole library, in file order.
class PromptLibrary {
  const PromptLibrary({required this.version, required this.prompts});

  factory PromptLibrary.fromJson(Map<String, dynamic> json) => PromptLibrary(
    version: json['version'] as int,
    prompts: [
      for (final p in json['prompts'] as List)
        InterviewPrompt.fromJson(p as Map<String, dynamic>),
    ],
  );

  final int version;
  final List<InterviewPrompt> prompts;

  List<InterviewPrompt> forTopic(String topic) => [
    for (final p in prompts)
      if (p.topic == topic) p,
  ];

  InterviewPrompt? byId(String id) {
    for (final p in prompts) {
      if (p.id == id) return p;
    }
    return null;
  }
}
