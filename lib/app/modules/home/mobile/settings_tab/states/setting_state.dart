// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

class SettingState {
  final bool isDarkMode;
  final String language;
  final bool inAppAlerts;
  final bool appLockEnabled;
  final bool twoFactorEnabled;

  SettingState({
    required this.isDarkMode,
    required this.language,
    required this.inAppAlerts,
    required this.appLockEnabled,
    required this.twoFactorEnabled,
  });

  @override
  String toString() {
    return 'SettingState{isDarkMode: $isDarkMode, language: $language, inAppAlerts: $inAppAlerts, appLockEnabled: $appLockEnabled, twoFactorEnabled: $twoFactorEnabled}';
  }

  SettingState copyWith({
    bool? isDarkMode,
    bool? inAppAlerts,
    bool? appLockEnabled,
    bool? twoFactorEnabled,
    String? language,
  }) {
    return SettingState(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      inAppAlerts: inAppAlerts ?? this.inAppAlerts,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      language: language ?? this.language,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingState &&
          runtimeType == other.runtimeType &&
          isDarkMode == other.isDarkMode &&
          language == other.language &&
          inAppAlerts == other.inAppAlerts &&
          appLockEnabled == other.appLockEnabled &&
          twoFactorEnabled == other.twoFactorEnabled;

  @override
  int get hashCode =>
      isDarkMode.hashCode ^ language.hashCode ^ inAppAlerts.hashCode ^ appLockEnabled.hashCode ^ twoFactorEnabled.hashCode;
}
