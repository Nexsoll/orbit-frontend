// Provides fallback localizations for Zulu (zu) using English
// so Cupertino/Material widgets work even if Flutter does not ship zu.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class ZuCupertinoFallbackDelegate extends LocalizationsDelegate<CupertinoLocalizations> {
  const ZuCupertinoFallbackDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'zu';

  @override
  Future<CupertinoLocalizations> load(Locale locale) {
    // Load English Cupertino strings as a fallback
    return GlobalCupertinoLocalizations.delegate.load(const Locale('en'));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<CupertinoLocalizations> old) => false;
}

class ZuMaterialFallbackDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const ZuMaterialFallbackDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'zu';

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    // Load English Material strings as a fallback
    return GlobalMaterialLocalizations.delegate.load(const Locale('en'));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<MaterialLocalizations> old) => false;
}

class ZuWidgetsFallbackDelegate extends LocalizationsDelegate<WidgetsLocalizations> {
  const ZuWidgetsFallbackDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'zu';

  @override
  Future<WidgetsLocalizations> load(Locale locale) {
    // Load English Widgets strings as a fallback
    return GlobalWidgetsLocalizations.delegate.load(const Locale('en'));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<WidgetsLocalizations> old) => false;
}

class ExtraCupertinoFallbackDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const ExtraCupertinoFallbackDelegate();

  static const _supported = {
    'am',
    'ff',
    'ha',
    'ig',
  };

  @override
  bool isSupported(Locale locale) => _supported.contains(locale.languageCode);

  @override
  Future<CupertinoLocalizations> load(Locale locale) {
    return GlobalCupertinoLocalizations.delegate.load(const Locale('en'));
  }

  @override
  bool shouldReload(
    covariant LocalizationsDelegate<CupertinoLocalizations> old,
  ) =>
      false;
}

class ExtraMaterialFallbackDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const ExtraMaterialFallbackDelegate();

  @override
  bool isSupported(Locale locale) =>
      ExtraCupertinoFallbackDelegate._supported.contains(locale.languageCode);

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    return GlobalMaterialLocalizations.delegate.load(const Locale('en'));
  }

  @override
  bool shouldReload(
    covariant LocalizationsDelegate<MaterialLocalizations> old,
  ) =>
      false;
}

class ExtraWidgetsFallbackDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const ExtraWidgetsFallbackDelegate();

  @override
  bool isSupported(Locale locale) =>
      ExtraCupertinoFallbackDelegate._supported.contains(locale.languageCode);

  @override
  Future<WidgetsLocalizations> load(Locale locale) {
    return GlobalWidgetsLocalizations.delegate.load(const Locale('en'));
  }

  @override
  bool shouldReload(
    covariant LocalizationsDelegate<WidgetsLocalizations> old,
  ) =>
      false;
}
