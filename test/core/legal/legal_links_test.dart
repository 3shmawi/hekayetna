import 'dart:io';

import 'package:family_stories/core/legal/legal_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(LegalLinks, () {
    for (final (name, url) in [
      ('privacy', LegalLinks.privacy),
      ('terms', LegalLinks.terms),
    ]) {
      test('$name is null or an https page that website/ publishes', () {
        if (url == null) return;
        expect(url.scheme, 'https');
        expect(File('website/${url.pathSegments.last}').existsSync(), isTrue);
      });
    }
  });
}
