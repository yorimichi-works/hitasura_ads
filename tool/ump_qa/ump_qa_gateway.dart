// This file is imported only by the separate simulator QA entrypoint and tests.
import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hitasura_ads/services/ads_privacy_service.dart';

void requireUmpQaEnvironment({
  required bool debug,
  required bool ios,
  required bool explicitlyEnabled,
  required bool nativeSimulator,
}) {
  if (!debug || !ios || !explicitlyEnabled || !nativeSimulator) {
    throw StateError(
      'UMP QA requires an explicitly enabled Debug iOS simulator',
    );
  }
}

/// Uses the shipping gateway for form presentation and privacy options. Only
/// the consent-update parameters differ, using Google's documented test API.
class EeaQaConsentGateway extends UmpAdsConsentGateway {
  EeaQaConsentGateway({ConsentInformation? information})
    : information = information ?? ConsentInformation.instance;

  final ConsentInformation information;

  @override
  Future<void> update() {
    final result = Completer<void>();
    information.requestConsentInfoUpdate(
      ConsentRequestParameters(
        consentDebugSettings: ConsentDebugSettings(
          debugGeography: DebugGeography.debugGeographyEea,
        ),
      ),
      () => result.complete(),
      (error) => result.completeError(error),
    );
    return result.future;
  }
}
