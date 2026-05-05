import 'dart:convert';

class SocialLoginDto {
  final String accessToken;
  final String deviceId;
  final Map<String, dynamic> deviceInfo;
  final String language;
  final String platform;
  final String? pushKey;

  SocialLoginDto({
    required this.accessToken,
    required this.deviceId,
    required this.deviceInfo,
    required this.language,
    required this.platform,
    this.pushKey,
  });

  Map<String, dynamic> toMap() {
    return {
      'accessToken': accessToken,
      'deviceId': deviceId,
      // Backend expects string then decodes with jsonDecoder
      'deviceInfo': jsonEncode(deviceInfo),
      'language': language,
      'platform': platform,
      'pushKey': pushKey,
    };
  }
}
