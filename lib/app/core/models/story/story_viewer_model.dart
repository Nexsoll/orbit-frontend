// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:super_up_core/super_up_core.dart';

class StoryViewerModel {
  final String viewerId;
  final DateTime viewedAt;
  final SBaseUser viewerInfo;

  const StoryViewerModel({
    required this.viewerId,
    required this.viewedAt,
    required this.viewerInfo,
  });

  factory StoryViewerModel.fromMap(Map<String, dynamic> map) {
    final viewerInfo = map['viewerInfo'] as Map<String, dynamic>;
    return StoryViewerModel(
      viewerId: viewerInfo['_id'] as String,
      viewedAt: DateTime.parse(map['viewedAt'] as String),
      viewerInfo: SBaseUser.fromMap(viewerInfo),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'viewerId': viewerId,
      'viewedAt': viewedAt.toIso8601String(),
      'viewerInfo': viewerInfo.toMap(),
    };
  }

  @override
  String toString() {
    return 'StoryViewerModel{viewerId: $viewerId, viewedAt: $viewedAt, viewerInfo: $viewerInfo}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryViewerModel &&
          runtimeType == other.runtimeType &&
          viewerId == other.viewerId &&
          viewedAt == other.viewedAt &&
          viewerInfo == other.viewerInfo;

  @override
  int get hashCode =>
      viewerId.hashCode ^ viewedAt.hashCode ^ viewerInfo.hashCode;
}

class StoryViewersResponse {
  final List<StoryViewerModel> viewers;

  const StoryViewersResponse({
    required this.viewers,
  });

  factory StoryViewersResponse.fromMap(Map<String, dynamic> map) {
    // The backend returns an array with one object containing views array
    final dynamic responseData = map['data'];

    if (responseData is List) {
      if (responseData.isEmpty) {
        return const StoryViewersResponse(viewers: []);
      }

      final Map<String, dynamic> storyData =
          responseData.first as Map<String, dynamic>;
      final List<dynamic> viewsData =
          storyData['views'] as List<dynamic>? ?? [];

      return StoryViewersResponse(
        viewers: viewsData
            .map((viewData) =>
                StoryViewerModel.fromMap(viewData as Map<String, dynamic>))
            .toList(),
      );
    } else {
      // Handle case where data might be directly the views array
      final List<dynamic> viewsData = responseData as List<dynamic>? ?? [];
      return StoryViewersResponse(
        viewers: viewsData
            .map((viewData) =>
                StoryViewerModel.fromMap(viewData as Map<String, dynamic>))
            .toList(),
      );
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'viewers': viewers.map((viewer) => viewer.toMap()).toList(),
    };
  }

  @override
  String toString() {
    return 'StoryViewersResponse{viewers: $viewers}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryViewersResponse &&
          runtimeType == other.runtimeType &&
          viewers == other.viewers;

  @override
  int get hashCode => viewers.hashCode;
}
