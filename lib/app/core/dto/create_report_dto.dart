// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

class CreateReportDto {
  final String content;
  final String type;
  final String targetId;

//<editor-fold desc="Data Methods">
  const CreateReportDto({
    required this.content,
    required this.type,
    required this.targetId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CreateReportDto &&
          runtimeType == other.runtimeType &&
          content == other.content &&
          type == other.type &&
          targetId == other.targetId);

  @override
  int get hashCode => content.hashCode ^ type.hashCode ^ targetId.hashCode;

  @override
  String toString() {
    return 'CreateReportDto{ content: $content, type: $type, targetId: $targetId,}';
  }

  CreateReportDto copyWith({
    String? content,
    String? type,
    String? targetId,
  }) {
    return CreateReportDto(
      content: content ?? this.content,
      type: type ?? this.type,
      targetId: targetId ?? this.targetId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'content': content,
      'type': type,
      'targetId': targetId,
    };
  }

  factory CreateReportDto.fromMap(Map<String, dynamic> map) {
    return CreateReportDto(
      content: map['content'] as String,
      type: map['type'] as String,
      targetId: map['targetId'] as String,
    );
  }

//</editor-fold>
}
