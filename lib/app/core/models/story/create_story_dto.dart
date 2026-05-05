import 'dart:convert';

import 'package:chopper/chopper.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';

import '../../utils/enums.dart';

class CreateStoryDto {
  final VPlatformFile? image;
  final VPlatformFile? secondImage; // optional thumbnail for videos
  final StoryType storyType;
  final StoryFontType storyFontType;
  final String content;
  final String? backgroundColor;
  final String? caption;
  final Map<String, dynamic>? attachment;
  final StoryPrivacy? storyPrivacy;
  final List<String>? somePeople;
  final List<String>? exceptPeople;
  final String storySource;

  const CreateStoryDto({
    this.image,
    this.secondImage,
    required this.storyType,
    required this.content,
    this.backgroundColor,
    this.storyFontType = StoryFontType.normal,
    this.caption,
    this.attachment,
    this.storyPrivacy,
    this.somePeople,
    this.exceptPeople,
    this.storySource = 'main',
  });

  List<PartValue> toListOfPartValue() {
    return [
      PartValue('storyType', storyType.name),
      PartValue('content', content),
      PartValue('fontType', storyFontType.name),
      PartValue('backgroundColor', backgroundColor),
      PartValue('caption', caption),
      PartValue('storySource', storySource),
      if (attachment != null) PartValue('attachment', jsonEncode(attachment)),
      if (storyPrivacy != null) PartValue('storyPrivacy', storyPrivacy!.name),
      if (somePeople != null) PartValue('somePeople', jsonEncode(somePeople)),
      if (exceptPeople != null)
        PartValue('exceptPeople', jsonEncode(exceptPeople)),
    ];
  }
}
