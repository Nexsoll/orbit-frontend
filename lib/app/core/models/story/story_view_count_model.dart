// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

class StoryViewCountModel {
  final int viewsCount;

  const StoryViewCountModel({
    required this.viewsCount,
  });

  factory StoryViewCountModel.fromMap(Map<String, dynamic> map) {
    return StoryViewCountModel(
      viewsCount: map['viewsCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'viewsCount': viewsCount,
    };
  }

  @override
  String toString() {
    return 'StoryViewCountModel{viewsCount: $viewsCount}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryViewCountModel &&
          runtimeType == other.runtimeType &&
          viewsCount == other.viewsCount;

  @override
  int get hashCode => viewsCount.hashCode;
}
