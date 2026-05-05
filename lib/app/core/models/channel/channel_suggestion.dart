// Copyright 2025, Orbit Chat
// ChannelSuggestion model used in Story screen suggestions

import 'package:super_up_core/super_up_core.dart';

class ChannelSuggestion {
  final String roomId;
  final String title;
  final String image;
  final int followers;
  bool isJoined;

  String get thumbImageS3 {
    // Check if image already contains a full URL
    if (image.startsWith('http')) {
      return image; // Already a full URL
    }
    // Construct full URL: baseMediaUrl + image
    return SConstants.baseMediaUrl + image;
  }

  ChannelSuggestion({
    required this.roomId,
    required this.title,
    required this.image,
    required this.followers,
    required this.isJoined,
  });

  factory ChannelSuggestion.fromMap(Map<String, dynamic> map) {
    return ChannelSuggestion(
      roomId: map['roomId']?.toString() ?? map['_id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      image: map['image']?.toString() ?? '',
      followers: (map['followers'] is int)
          ? map['followers'] as int
          : int.tryParse(map['followers']?.toString() ?? '0') ?? 0,
      isJoined: map['isJoined'] == true,
    );
  }
}
