import 'package:flutter_test/flutter_test.dart';
import 'package:hitasura_ads/l10n/l10n.dart';
import 'package:hitasura_ads/l10n/tables.dart';

void main() {
  test('all twenty UI locales contain purchase, privacy, notification and license copy', () {
    const keys = [
      'ad_privacy_failed',
      'ad_privacy_options',
      'licenses',
      'link_unavailable',
      'notifications',
      'notifications_desc',
      'premium_active',
      'premium_home_entry',
      'premium_games_stay',
      'premium_loading',
      'premium_retry',
      'premium_error',

      'premium_buy',
      'premium_desc',
      'premium_title',
      'premium_unavailable',
      'privacy_and_support',
      'privacy_policy',
      'restore_purchases',
      'return_reminder_body',
      'return_reminder_title',
      'stamina_full_body',
      'stamina_full_title',
      'support',
      'unlimited',
      'unlock_any',
    ];
    expect(languages, hasLength(20));
    for (final language in languages) {
      final table = uiTables[language.code]!;
      for (final key in keys) {
        expect(
          table[key],
          isNotNull,
          reason: '${language.code}: $key must not fall back',
        );
        expect(table[key]!.trim(), isNotEmpty);
      }
      expect(table['premium_desc'], isNot(contains('300')));
      expect(table['premium_desc'], isNot(contains('200')));
    }
  });
}
