import 'dart:convert';
import 'package:chopper/chopper.dart';

class CreateMemoryDto {
  final String storyId;
  final List<String>? tags;
  final bool? isReminderEnabled;

  const CreateMemoryDto({
    required this.storyId,
    this.tags,
    this.isReminderEnabled,
  });

  List<PartValue> toListOfPartValue() {
    final List<PartValue> parts = [];
    
    parts.add(PartValue('storyId', storyId));
    
    if (tags != null && tags!.isNotEmpty) {
      parts.add(PartValue('tags', jsonEncode(tags)));
    }
    
    if (isReminderEnabled != null) {
      parts.add(PartValue('isReminderEnabled', isReminderEnabled.toString()));
    }
    
    return parts;
  }

  Map<String, dynamic> toMap() {
    return {
      'storyId': storyId,
      if (tags != null) 'tags': tags,
      if (isReminderEnabled != null) 'isReminderEnabled': isReminderEnabled,
    };
  }
}
