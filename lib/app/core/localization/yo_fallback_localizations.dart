// Provides fallback localizations for Yoruba (yo) using English
// so Cupertino/Material widgets work even if Flutter does not ship yo.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class YoCupertinoFallbackDelegate extends LocalizationsDelegate<CupertinoLocalizations> {
  const YoCupertinoFallbackDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'yo';

  @override
  Future<CupertinoLocalizations> load(Locale locale) {
    // Load English Cupertino strings as a fallback
    return GlobalCupertinoLocalizations.delegate.load(const Locale('en'));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<CupertinoLocalizations> old) => false;
}

class YoMaterialFallbackDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const YoMaterialFallbackDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'yo';

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    // Load English Material strings as a fallback
    return GlobalMaterialLocalizations.delegate.load(const Locale('en'));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<MaterialLocalizations> old) => false;
}

class YoWidgetsFallbackDelegate extends LocalizationsDelegate<WidgetsLocalizations> {
  const YoWidgetsFallbackDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'yo';

  @override
  Future<WidgetsLocalizations> load(Locale locale) {
    // Load English Widgets strings as a fallback
    return GlobalWidgetsLocalizations.delegate.load(const Locale('en'));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<WidgetsLocalizations> old) => false;
}
