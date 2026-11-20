import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:dsh_app/l10n/l10n.dart';

void main() {
  group('Thai locale support', () {
    test('Locale("th") is in supportedLocales', () {
      expect(AppLocale.supported, contains(const Locale('th')));
    });

    test('L10n.delegate supports Thai locale', () {
      final delegate = L10n.delegate;
      expect(delegate.isSupported(const Locale('th')), isTrue);
    });

    test('lookupL10n(Locale("th")) returns Thai strings for core keys', () {
      final th = lookupL10n(const Locale('th'));

      // Test at least 5 keys that should have Thai translations
      expect(th.localeTitle, equals('ภาษา'));
      expect(th.localeSystem, equals('ระบบ'));
      expect(th.localeTh, equals('ไทย'));
      expect(th.localeEn, equals('อังกฤษ'));
      expect(th.localeZh, equals('จีน'));
    });

    test('lookupL10n(Locale("th")) returns Thai strings for settings keys', () {
      final th = lookupL10n(const Locale('th'));

      // Test settings-related keys that exist in ARB
      expect(th.tavernSettings, contains('การตั้งค่า'));
      expect(th.phoneRestrictedAdvanced, equals('Advanced settings'));
    });

    test('System locale resolution still works (ตามระบบ)', () {
      // When chosen is null, system locales should be used
      // Thai system locale should resolve to Thai
      final systemWithThai = [Locale('th'), Locale('en'), Locale('zh', 'CN')];
      expect(AppLocale.resolve(null, systemWithThai), equals(AppLocale.th));

      // Chinese system locale should resolve to Chinese
      final systemWithZh = [Locale('zh', 'CN'), Locale('en')];
      expect(AppLocale.resolve(null, systemWithZh), equals(AppLocale.zhCN));

      // English system locale should resolve to English
      final systemWithEn = [Locale('en'), Locale('th')];
      expect(AppLocale.resolve(null, systemWithEn), equals(AppLocale.en));

      // Empty system should default to Chinese (zhCN)
      expect(AppLocale.resolve(null, []), equals(AppLocale.zhCN));
      expect(AppLocale.resolve(null, null), equals(AppLocale.zhCN));
    });

    test('Explicit locale choice overrides system', () {
      // Explicit Thai choice should return Thai regardless of system
      expect(AppLocale.resolve(AppLocale.th, [Locale('en')]), equals(AppLocale.th));
      expect(AppLocale.resolve(AppLocale.en, [Locale('th')]), equals(AppLocale.en));
      expect(AppLocale.resolve(AppLocale.zhCN, [Locale('th')]), equals(AppLocale.zhCN));

      // System choice (null) should follow system
      expect(AppLocale.resolve(null, [Locale('th')]), equals(AppLocale.th));
    });

    test('AppLocale.use() switches to Thai correctly', () {
      final original = AppLocale.current;
      AppLocale.use(AppLocale.th);
      expect(AppLocale.current, equals(AppLocale.th));
      expect(AppLocale.l10n, equals(lookupL10n(AppLocale.th)));
      // Restore
      AppLocale.use(original);
    });
  });
}
