import 'package:chopper/chopper.dart';

class StatusAiCaptionDto {
  final String storyType;
  final String? text;
  final String? existingCaption;
  final String? mimeType;

  StatusAiCaptionDto({
    required this.storyType,
    this.text,
    this.existingCaption,
    this.mimeType,
  });

  Map<String, dynamic> toMap() {
    return {
      'storyType': storyType,
      if (text != null) 'text': text,
      if (existingCaption != null) 'existingCaption': existingCaption,
      if (mimeType != null) 'mimeType': mimeType,
    };
  }
}

class StatusAiAnalyzeDto {
  final String storyType;
  final String? text;
  final String? caption;
  final String? mimeType;

  StatusAiAnalyzeDto({
    required this.storyType,
    this.text,
    this.caption,
    this.mimeType,
  });

  Map<String, dynamic> toMap() {
    return {
      'storyType': storyType,
      if (text != null) 'text': text,
      if (caption != null) 'caption': caption,
      if (mimeType != null) 'mimeType': mimeType,
    };
  }
}

class StatusAiSuggestionsDto {
  final String storyType;
  final String? text;
  final String? caption;
  final String? mimeType;

  StatusAiSuggestionsDto({
    required this.storyType,
    this.text,
    this.caption,
    this.mimeType,
  });

  Map<String, dynamic> toMap() {
    return {
      'storyType': storyType,
      if (text != null) 'text': text,
      if (caption != null) 'caption': caption,
      if (mimeType != null) 'mimeType': mimeType,
    };
  }

  List<PartValue> toListOfPartValue() {
    return [
      PartValue('storyType', storyType),
      if (text != null) PartValue('text', text),
      if (caption != null) PartValue('caption', caption),
      if (mimeType != null) PartValue('mimeType', mimeType),
    ];
  }
}

class StatusAiCaptionResult {
  final String caption;
  final List<String> alternatives;

  StatusAiCaptionResult({
    required this.caption,
    required this.alternatives,
  });

  factory StatusAiCaptionResult.fromMap(Map<String, dynamic> map) {
    return StatusAiCaptionResult(
      caption: map['caption'] ?? '',
      alternatives: List<String>.from(map['alternatives'] ?? []),
    );
  }
}

class StatusAiSuggestionResult {
  final List<String> captions;
  final List<String> hashtags;
  final List<String> emojis;
  final List<String> filters;

  StatusAiSuggestionResult({
    required this.captions,
    required this.hashtags,
    required this.emojis,
    required this.filters,
  });

  factory StatusAiSuggestionResult.fromMap(Map<String, dynamic> map) {
    return StatusAiSuggestionResult(
      captions: List<String>.from(map['captions'] ?? []),
      hashtags: List<String>.from(map['hashtags'] ?? []),
      emojis: List<String>.from(map['emojis'] ?? []),
      filters: List<String>.from(map['filters'] ?? []),
    );
  }
}

class StatusAiModerationDecision {
  final bool allowed;
  final List<String> reasons;
  final Map<String, dynamic>? categories;

  StatusAiModerationDecision({
    required this.allowed,
    required this.reasons,
    this.categories,
  });

  factory StatusAiModerationDecision.fromMap(Map<String, dynamic> map) {
    return StatusAiModerationDecision(
      allowed: map['allowed'] ?? true,
      reasons: List<String>.from(map['reasons'] ?? []),
      categories: map['categories'] as Map<String, dynamic>?,
    );
  }
}

class StatusAiAnalysisResult {
  final StatusAiModerationDecision moderation;
  final List<String> labels;
  final String? language;

  StatusAiAnalysisResult({
    required this.moderation,
    required this.labels,
    this.language,
  });

  factory StatusAiAnalysisResult.fromMap(Map<String, dynamic> map) {
    return StatusAiAnalysisResult(
      moderation: StatusAiModerationDecision.fromMap(map['moderation'] ?? {}),
      labels: List<String>.from(map['labels'] ?? []),
      language: map['language'],
    );
  }
}
