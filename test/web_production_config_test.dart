import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Firebase Hosting serves the Flutter build as an SPA', () {
    final config = jsonDecode(
      File('firebase.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final hosting = config['hosting'] as Map<String, dynamic>;
    final rewrites = hosting['rewrites'] as List<dynamic>;

    expect(hosting['public'], 'build/web');
    expect(rewrites, hasLength(1));
    final spaRewrite = rewrites.single as Map<String, dynamic>;
    expect(spaRewrite['source'], '**');
    expect(spaRewrite['destination'], '/index.html');
  });

  test('production web metadata uses the canonical custom domain', () {
    const origin = 'https://hitasura.yorimichi-works.jp';
    final index = File('web/index.html').readAsStringSync();
    final robots = File('web/robots.txt').readAsStringSync();
    final sitemap = File('web/sitemap.xml').readAsStringSync();
    final manifest = jsonDecode(
      File('web/manifest.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    expect(index, contains('<html lang="ja">'));
    expect(index, contains('$origin/'));
    expect(index, contains('property="og:title"'));
    expect(index, contains('name="description"'));
    expect(robots, contains('$origin/sitemap.xml'));
    expect(sitemap, contains('<loc>$origin/</loc>'));
    expect(manifest['name'], 'ひたすら広告');
    expect(manifest['start_url'], '/');
    expect(File('web/favicon.png').lengthSync(), greaterThan(0));
    expect(File('web/og-image.png').lengthSync(), greaterThan(0));
  });

  test('production workflow disables mobile ads on web', () {
    final workflow = File('.github/workflows/deploy-firebase-hosting.yml')
        .readAsStringSync();

    expect(workflow, contains('flutter analyze'));
    expect(workflow, contains('flutter test'));
    expect(workflow, contains('flutter build web --release --base-href /'));
    expect(workflow, contains('--dart-define=ADMOB_MODE=disabled'));
    expect(workflow, contains('channelId: live'));
  });
}
