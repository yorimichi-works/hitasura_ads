import 'package:flutter_test/flutter_test.dart';
import 'package:hitasura_ads/services/release_links.dart';

void main() {
  test('release links accept only explicit HTTPS URLs without credentials', () {
    expect(
      ReleaseLinks.parse('https://www.example.org/privacy')?.host,
      'www.example.org',
    );
    for (final value in [
      '',
      '/privacy',
      'http://www.example.org',
      'https://',
      'javascript:alert(1)',
      'https://user:pass@example.org',
    ]) {
      expect(ReleaseLinks.parse(value), isNull);
    }
  });
}
