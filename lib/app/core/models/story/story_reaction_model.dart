// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

class StoryReactionModel {
  final bool liked;
  final int likesCount;

  const StoryReactionModel({
    required this.liked,
    required this.likesCount,
  });

  factory StoryReactionModel.fromMap(Map<String, dynamic> map) {
    return StoryReactionModel(
      liked: map['liked'] as bool,
      likesCount: map['likesCount'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'liked': liked,
      'likesCount': likesCount,
    };
  }

  @override
  String toString() {
    return 'StoryReactionModel{liked: $liked, likesCount: $likesCount}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryReactionModel &&
          runtimeType == other.runtimeType &&
          liked == other.liked &&
          likesCount == other.likesCount;

  @override
  int get hashCode => liked.hashCode ^ likesCount.hashCode;
}
