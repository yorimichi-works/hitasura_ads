// Separate, explicitly enabled Debug simulator target. Never imported by lib/.
// Exercises the actual UMP SDK and the shipping consent service, without an
// ad service, an ad request, tracking authorization, or Mobile Ads startup.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hitasura_ads/services/ads_privacy_service.dart';

import 'ump_qa_gateway.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('HITASURA_UMP_QA');
  // Reject release/profile/device before touching any consent state.
  requireUmpQaEnvironment(
    debug: kDebugMode,
    ios: Platform.isIOS,
    explicitlyEnabled: enabled,
    nativeSimulator: true,
  );
  final response = await const MethodChannel('hitasura_ads/simulator_capture')
      .invokeMapMethod<String, Object?>('documentsDirectory');
  requireUmpQaEnvironment(
    debug: kDebugMode,
    ios: Platform.isIOS,
    explicitlyEnabled: enabled,
    nativeSimulator: response?['isSimulator'] == true,
  );
  final documents = response?['documentsPath'];
  if (documents is! String || !documents.startsWith('/')) {
    throw StateError('Native simulator Documents path unavailable');
  }
  final directory = Directory('$documents/HitasuraUmpQa')..createSync();
  runApp(MaterialApp(home: UmpQaScreen(directory: directory)));
}

class UmpQaScreen extends StatefulWidget {
  const UmpQaScreen({super.key, required this.directory});
  final Directory directory;

  @override
  State<UmpQaScreen> createState() => _UmpQaScreenState();
}

class _UmpQaScreenState extends State<UmpQaScreen> {
  AdsPrivacyService? _privacy;
  String _stage = 'qa_ready';
  String _details = 'EEA simulator QA; no ad initialization or requests';
  bool _busy = false;

  void _record(String stage, [Map<String, Object?> details = const {}]) {
    final event = <String, Object?>{
      'stage': stage,
      'at': DateTime.now().toUtc().toIso8601String(),
      'target': 'tool/ump_qa/ump_qa_main.dart',
      'native_simulator_attested': true,
      'debug_mode': kDebugMode,
      'debug_geography': 'EEA',
      'ad_initialization_requested': false,
      'ad_load_requested': false,
      ...details,
    };
    final encoded = jsonEncode(event);
    File('${widget.directory.path}/events.jsonl')
        .writeAsStringSync('$encoded\n', mode: FileMode.append, flush: true);
    final pending = File('${widget.directory.path}/state.json.pending');
    pending.writeAsStringSync(encoded, flush: true);
    pending.renameSync('${widget.directory.path}/state.json');
    stdout.writeln('HITASURA_UMP_QA $encoded');
    if (mounted) {
      setState(() {
        _stage = stage;
        _details = const JsonEncoder.withIndent('  ').convert(event);
      });
    }
  }

  Future<void> _snapshot(String stage) async {
    final information = ConsentInformation.instance;
    _record(stage, {
      'sdk_consent_status': (await information.getConsentStatus()).name,
      'sdk_can_request_ads': await information.canRequestAds(),
      'sdk_privacy_options_status':
          (await information.getPrivacyOptionsRequirementStatus()).name,
      'service_can_request_ads': _privacy?.canRequestAds,
      'service_privacy_options_required': _privacy?.privacyOptionsRequired,
      'service_has_error': _privacy?.hasError,
    });
  }

  Future<void> _start() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      _privacy?.dispose();
      // Test-only reset after both Dart and native simulator guards above.
      await ConsentInformation.instance.reset();
      _privacy = AdsPrivacyService(gateway: EeaQaConsentGateway());
      _record('consent_update_requested');
      if (!await _privacy!.prepare()) {
        throw StateError('Shipping service could not update actual UMP state');
      }
      await _snapshot('consent_update_complete');
      _record('consent_form_requested');
      await _privacy!.ensureConsent();
      if (_privacy!.hasError) {
        throw StateError('Shipping service reported a consent-form error');
      }
      await _snapshot('consent_complete');
    } catch (error) {
      _record('qa_error', {'error': '$error'});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _options() async {
    if (_busy || _privacy?.privacyOptionsRequired != true) return;
    setState(() => _busy = true);
    try {
      _record('privacy_options_requested');
      await _privacy!.showPrivacyOptions();
      if (_privacy!.hasError) {
        throw StateError('Shipping service reported a privacy-options error');
      }
      await _snapshot('privacy_options_complete');
    } catch (error) {
      _record('qa_error', {'error': '$error'});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _privacy?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hitasura UMP integration QA')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(_stage),
          const SizedBox(height: 12),
          Semantics(
            identifier: 'ump_start',
            child: ElevatedButton(
              onPressed: _busy ? null : _start,
              child: const Text('Reset and start EEA consent'),
            ),
          ),
          Semantics(
            identifier: 'ump_options',
            child: ElevatedButton(
              onPressed: !_busy && _privacy?.privacyOptionsRequired == true
                  ? _options
                  : null,
              child: const Text('Open required privacy options'),
            ),
          ),
          const SizedBox(height: 12),
          Text(_details),
        ],
      ),
    ),
  );
}
