// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

enum FilterType {
  none,
  beauty,
  vintage,
  blackWhite,
  sepia,
  cool,
  warm,
  bright,
  contrast,
  saturated,
  blur,
  sharpen,
}

enum FaceFilterType {
  none,
  dogEars,
  catEars,
  bunnyEars,
  crown,
  glasses,
  mustache,
  heart,
  flower,
}

class StreamFilterModel {
  final FilterType filterType;
  final FaceFilterType faceFilterType;
  final double intensity;
  final bool isEnabled;

  const StreamFilterModel({
    this.filterType = FilterType.none,
    this.faceFilterType = FaceFilterType.none,
    this.intensity = 1.0,
    this.isEnabled = false,
  });

  StreamFilterModel copyWith({
    FilterType? filterType,
    FaceFilterType? faceFilterType,
    double? intensity,
    bool? isEnabled,
  }) {
    return StreamFilterModel(
      filterType: filterType ?? this.filterType,
      faceFilterType: faceFilterType ?? this.faceFilterType,
      intensity: intensity ?? this.intensity,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'filterType': filterType.name,
      'faceFilterType': faceFilterType.name,
      'intensity': intensity,
      'isEnabled': isEnabled,
    };
  }

  factory StreamFilterModel.fromMap(Map<String, dynamic> map) {
    return StreamFilterModel(
      filterType: FilterType.values.firstWhere(
        (e) => e.name == map['filterType'],
        orElse: () => FilterType.none,
      ),
      faceFilterType: FaceFilterType.values.firstWhere(
        (e) => e.name == map['faceFilterType'],
        orElse: () => FaceFilterType.none,
      ),
      intensity: map['intensity']?.toDouble() ?? 1.0,
      isEnabled: map['isEnabled'] ?? false,
    );
  }
}

extension FilterTypeExtension on FilterType {
  String get displayName {
    switch (this) {
      case FilterType.none:
        return 'None';
      case FilterType.beauty:
        return 'Beauty';
      case FilterType.vintage:
        return 'Vintage';
      case FilterType.blackWhite:
        return 'B&W';
      case FilterType.sepia:
        return 'Sepia';
      case FilterType.cool:
        return 'Cool';
      case FilterType.warm:
        return 'Warm';
      case FilterType.bright:
        return 'Bright';
      case FilterType.contrast:
        return 'Contrast';
      case FilterType.saturated:
        return 'Saturated';
      case FilterType.blur:
        return 'Blur';
      case FilterType.sharpen:
        return 'Sharpen';
    }
  }

  String get icon {
    switch (this) {
      case FilterType.none:
        return '🚫';
      case FilterType.beauty:
        return '✨';
      case FilterType.vintage:
        return '📷';
      case FilterType.blackWhite:
        return '⚫';
      case FilterType.sepia:
        return '🟤';
      case FilterType.cool:
        return '🧊';
      case FilterType.warm:
        return '🔥';
      case FilterType.bright:
        return '☀️';
      case FilterType.contrast:
        return '🌓';
      case FilterType.saturated:
        return '🌈';
      case FilterType.blur:
        return '🌫️';
      case FilterType.sharpen:
        return '🔍';
    }
  }
}

extension FaceFilterTypeExtension on FaceFilterType {
  String get displayName {
    switch (this) {
      case FaceFilterType.none:
        return 'None';
      case FaceFilterType.dogEars:
        return 'Dog Ears';
      case FaceFilterType.catEars:
        return 'Cat Ears';
      case FaceFilterType.bunnyEars:
        return 'Bunny Ears';
      case FaceFilterType.crown:
        return 'Crown';
      case FaceFilterType.glasses:
        return 'Glasses';
      case FaceFilterType.mustache:
        return 'Mustache';
      case FaceFilterType.heart:
        return 'Heart';
      case FaceFilterType.flower:
        return 'Flower';
    }
  }

  String get icon {
    switch (this) {
      case FaceFilterType.none:
        return '🚫';
      case FaceFilterType.dogEars:
        return '🐶';
      case FaceFilterType.catEars:
        return '🐱';
      case FaceFilterType.bunnyEars:
        return '🐰';
      case FaceFilterType.crown:
        return '👑';
      case FaceFilterType.glasses:
        return '🤓';
      case FaceFilterType.mustache:
        return '🥸';
      case FaceFilterType.heart:
        return '💖';
      case FaceFilterType.flower:
        return '🌸';
    }
  }
}
