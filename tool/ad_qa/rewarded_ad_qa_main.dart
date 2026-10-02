// Isolated, opt-in Debug simulator entrypoint. Never imported by lib/.
// All ad operations use the real shipping service forced to Google's demo unit.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hitasura_ads/services/ads_privacy_service.dart';
import 'package:hitasura_ads/services/rewarded_ad_service.dart';

import '../ump_qa/ump_qa_gateway.dart';
import 'ad_qa_policy.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('HITASURA_REWARDED_AD_QA');
  const mode = String.fromEnvironment('ADMOB_MODE');
  requireRewardedQaEnvironment(
    debug: kDebugMode,
    ios: Platform.isIOS,
    explicitlyEnabled: enabled,
    nativeSimulator: true,
    adMode: mode,
  );
  final native = await const MethodChannel('hitasura_ads/simulator_capture')
      .invokeMapMethod<String, Object?>('documentsDirectory')
      .timeout(const Duration(seconds: 10));
  requireRewardedQaEnvironment(
    debug: kDebugMode,
    ios: Platform.isIOS,
    explicitlyEnabled: enabled,
    nativeSimulator: native?['isSimulator'] == true,
    adMode: mode,
  );
  final documents = native?['documentsPath'];
  if (documents is! String || !documents.startsWith('/')) {
    throw StateError('Native simulator Documents path unavailable');
  }
  final directory = Directory('$documents/HitasuraRewardedQa')..createSync();
  runApp(MaterialApp(home: RewardedQaScreen(directory: directory)));
}

class RewardedQaScreen extends StatefulWidget {
  const RewardedQaScreen({super.key, required this.directory});
  final Directory directory;

  @override
  State<RewardedQaScreen> createState() => _RewardedQaScreenState();
}

class _RewardedQaScreenState extends State<RewardedQaScreen> {
  GoogleRewardedAdService? _ads;
  late final DebugPrintCallback _originalDebugPrint;
  String _stage = 'ad_qa_ready';
  String _details = 'Google demo rewarded unit only; real SDK callbacks';
  bool _busy = false;
  bool _started = false;
  bool _loaded = false;
  bool _shown = false;
  final Map<String, int> _callbacks = {};

  @override
  void initState() {
    super.initState();
    _originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      _originalDebugPrint(message, wrapWidth: wrapWidth);
      final stage = sdkStageForLog(message);
      if (stage != null) {
        _callbacks[stage] = (_callbacks[stage] ?? 0) + 1;
        _record(stage, {
          'source': 'shipping_service_sdk_log',
          'message': message,
        });
      }
    };
  }

  void _record(String stage, [Map<String, Object?> details = const {}]) {
    final event = <String, Object?>{
      'stage': stage,
      'at': DateTime.now().toUtc().toIso8601String(),
      'target': 'tool/ad_qa/rewarded_ad_qa_main.dart',
      'native_simulator_attested': true,
      'debug_mode': kDebugMode,
      'ad_mode': 'test',
      'expected_demo_unit': iosRewardedDemoUnit,
      'service_uses_test_ads': _ads?.usesTestAds,
      ...details,
    };
    final encoded = jsonEncode(event);
    File('${widget.directory.path}/events.jsonl')
        .writeAsStringSync('$encoded\n', mode: FileMode.append, flush: true);
    final pending = File('${widget.directory.path}/state.json.pending');
    pending.writeAsStringSync(encoded, flush: true);
    pending.renameSync('${widget.directory.path}/state.json');
    stdout.writeln('HITASURA_REWARDED_QA $encoded');
    if (mounted) {
      setState(() {
        _stage = stage;
        _details = const JsonEncoder.withIndent('  ').convert(event);
      });
    }
  }

  Future<void> _load() async {
    if (_busy || _started) return;
    _started = true;
    setState(() => _busy = true);
    try {
      // Only after explicit opt-in and native simulator attestation.
      await ConsentInformation.instance.reset();
      final privacy = AdsPrivacyService(gateway: EeaQaConsentGateway());
      _ads = GoogleRewardedAdService(
        adNetworkMode: AdNetworkMode.test,
        privacyService: privacy,
      );
      if (!_ads!.usesTestAds || !_ads!.isSupported) {
        throw StateError('Google demo-only service configuration rejected');
      }
      _record('ad_qa_consent_and_load_requested', {
        'debug_geography': 'EEA',
        'placement': 'restore_search_energy',
      });
      await _ads!.initialize().timeout(const Duration(seconds: 150));
      if (_ads!.status != RewardedAdStatus.ready ||
          _callbacks['sdk_load_callback'] != 1) {
        throw StateError('Actual rewarded SDK did not load one demo ad');
      }
      _loaded = true;
      _record('ad_qa_loaded', {
        'mobile_ads_sdk_version': await MobileAds.instance
            .getVersionString()
            .timeout(const Duration(seconds: 5)),
        'sdk_can_request_ads': await ConsentInformation.instance
            .canRequestAds(),
        'sdk_consent_status':
            (await ConsentInformation.instance.getConsentStatus()).name,
      });
    } catch (error) {
      _record('ad_qa_error', {'error': '$error'});
      _ads?.dispose();
      _ads = null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _show() async {
    final ads = _ads;
    if (_busy || !_loaded || _shown || ads == null || !ads.usesTestAds) return;
    _shown = true;
    setState(() => _busy = true);
    try {
      _record('ad_qa_show_requested');
      final result = await ads
          .show(placementName: 'restore_search_energy')
          .timeout(const Duration(seconds: 150));
      final actualReward = _callbacks['sdk_reward_callback'] == 1;
      final actualDismiss = _callbacks['sdk_dismiss_callback'] == 1;
      if (result != RewardedAdResult.rewarded ||
          !actualReward ||
          !actualDismiss) {
        throw StateError(
          'Actual rewarded flow incomplete: ${result.name}, reward=$actualReward, dismiss=$actualDismiss',
        );
      }
      _record('ad_qa_complete', {
        'result': result.name,
        'callback_counts': Map<String, int>.from(_callbacks),
        'native_test_mode_indicator': 'requires_xcresult_screenshot_review',
      });
    } catch (error) {
      _record('ad_qa_error', {'error': '$error'});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _ads?.dispose();
    debugPrint = _originalDebugPrint;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Rewarded SDK integration QA')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('GOOGLE DEMO ADS ONLY'),
          const Text(iosRewardedDemoUnit),
          Text(_stage),
          ElevatedButton(
            onPressed: _busy || _started ? null : _load,
            child: const Text('Reset consent and load Google demo'),
          ),
          ElevatedButton(
            onPressed: _busy || !_loaded || _shown ? null : _show,
            child: const Text('Show Google demo rewarded ad'),
          ),
          Text(_details),
        ],
      ),
    ),
  );
}
