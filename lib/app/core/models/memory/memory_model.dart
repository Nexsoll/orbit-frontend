import 'package:super_up/app/core/models/story/story_model.dart';

class MemoryModel {
  final String id;
  final String userId;
  final String storyId;
  final StoryModel originalStoryData;
  final DateTime savedAt;
  final DateTime? reminderDate;
  final bool isReminderEnabled;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MemoryModel({
    required this.id,
    required this.userId,
    required this.storyId,
    required this.originalStoryData,
    required this.savedAt,
    this.reminderDate,
    required this.isReminderEnabled,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MemoryModel.fromMap(Map<String, dynamic> map) {
    return MemoryModel(
      id: map['_id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      storyId: map['storyId'] as String? ?? '',
      originalStoryData:
          StoryModel.fromMap(map['originalStoryData'] as Map<String, dynamic>),
      savedAt: DateTime.parse(
          map['savedAt'] as String? ?? DateTime.now().toIso8601String()),
      reminderDate: map['reminderDate'] != null
          ? DateTime.parse(map['reminderDate'] as String)
          : null,
      isReminderEnabled: map['isReminderEnabled'] as bool? ?? true,
      tags: List<String>.from(map['tags'] as List? ?? []),
      createdAt: DateTime.parse(
          map['createdAt'] as String? ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          map['updatedAt'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'userId': userId,
      'storyId': storyId,
      'originalStoryData': originalStoryData.toMap(),
      'savedAt': savedAt.toIso8601String(),
      'reminderDate': reminderDate?.toIso8601String(),
      'isReminderEnabled': isReminderEnabled,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  MemoryModel copyWith({
    String? id,
    String? userId,
    String? storyId,
    StoryModel? originalStoryData,
    DateTime? savedAt,
    DateTime? reminderDate,
    bool? isReminderEnabled,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MemoryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      storyId: storyId ?? this.storyId,
      originalStoryData: originalStoryData ?? this.originalStoryData,
      savedAt: savedAt ?? this.savedAt,
      reminderDate: reminderDate ?? this.reminderDate,
      isReminderEnabled: isReminderEnabled ?? this.isReminderEnabled,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'MemoryModel{id: $id, userId: $userId, storyId: $storyId, savedAt: $savedAt, isReminderEnabled: $isReminderEnabled, tags: $tags}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemoryModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
