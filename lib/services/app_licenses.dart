import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool _registered = false;

/// Adds the bundled font's full license alongside Flutter/package licenses.
/// Registration is idempotent for rebuilt app roots and Settings routes.
void registerAppLicenses() {
  if (_registered) return;
  _registered = true;
  LicenseRegistry.addLicense(() async* {
    final attribution = await rootBundle.loadString(
      'assets/fonts/KosugiMaru-ATTRIBUTION.txt',
    );
    final license = await rootBundle.loadString(
      'assets/fonts/KosugiMaru-LICENSE.txt',
    );
    yield LicenseEntryWithLineBreaks(['Kosugi Maru'], '$attribution\n$license');
  });
}
