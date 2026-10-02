import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../tool/ump_qa/ump_qa_gateway.dart';

class _Information extends Fake implements ConsentInformation {
  ConsentRequestParameters? parameters;
  bool fail = false;

  @override
  void requestConsentInfoUpdate(
    ConsentRequestParameters params,
    OnConsentInfoUpdateSuccessListener successListener,
    OnConsentInfoUpdateFailureListener failureListener,
  ) {
    parameters = params;
    if (fail) {
      failureListener(FormError(errorCode: 1, message: 'Test request failed'));
    } else {
      successListener();
    }
  }
}

void main() {
  test('QA requires all four independent runtime conditions', () {
    for (var flags = 0; flags < 16; flags++) {
      void check() => requireUmpQaEnvironment(
        debug: flags & 1 != 0,
        ios: flags & 2 != 0,
        explicitlyEnabled: flags & 4 != 0,
        nativeSimulator: flags & 8 != 0,
      );
      if (flags == 15) {
        expect(check, returnsNormally);
      } else {
        expect(check, throwsStateError);
      }
    }
  });

  test(
    'QA sets only EEA debug geography, without age or cross-app flags',
    () async {
      final information = _Information();
      await EeaQaConsentGateway(information: information).update();
      final params = information.parameters!;
      expect(
        params.consentDebugSettings?.debugGeography,
        DebugGeography.debugGeographyEea,
      );
      expect(params.consentDebugSettings?.testIdentifiers, isNull);
      expect(params.tagForUnderAgeOfConsent, isNull);
      expect(params.consentSyncId, isNull);
    },
  );

  test(
    'actual gateway failure is propagated, never converted to consent',
    () async {
      final information = _Information()..fail = true;
      await expectLater(
        EeaQaConsentGateway(information: information).update(),
        throwsA(isA<FormError>()),
      );
    },
  );
}
