import 'dart:convert';

/// The last entitlement decision saved atomically with its verified identity.
/// Legacy purchases remain usable offline until StoreKit supplies evidence.
class PremiumEntitlement {
  const PremiumEntitlement({
    required this.active,
    required this.source,
    this.transactionId,
    this.originalTransactionId,
    this.signedDateMs,
  });

  const PremiumEntitlement.legacy(this.active)
    : source = 'legacy',
      transactionId = null,
      originalTransactionId = null,
      signedDateMs = null;

  final bool active;
  final String source;
  final String? transactionId;
  final String? originalTransactionId;
  final int? signedDateMs;

  String encode() => jsonEncode({
    'version': 1,
    'active': active,
    'source': source,
    'transactionId': transactionId,
    'originalTransactionId': originalTransactionId,
    'signedDateMs': signedDateMs,
  });

  static PremiumEntitlement? decode(String? value) {
    if (value == null) return null;
    try {
      final data = jsonDecode(value) as Map<String, dynamic>;
      if (data['version'] != 1 || data['active'] is! bool) return null;
      return PremiumEntitlement(
        active: data['active'] as bool,
        source: data['source'] as String,
        transactionId: data['transactionId'] as String?,
        originalTransactionId: data['originalTransactionId'] as String?,
        signedDateMs: data['signedDateMs'] as int?,
      );
    } catch (_) {
      return null;
    }
  }
}

enum PremiumEntitlementStatus { active, revoked, absentAfterSync, unknown }

/// Only native StoreKit verification can produce an authoritative decision.
/// Empty background snapshots and store/network/verification errors are unknown.
class PremiumEntitlementDecision {
  const PremiumEntitlementDecision({
    required this.status,
    this.transactionId,
    this.originalTransactionId,
    this.signedDateMs,
  });

  const PremiumEntitlementDecision.unknown()
    : status = PremiumEntitlementStatus.unknown,
      transactionId = null,
      originalTransactionId = null,
      signedDateMs = null;

  final PremiumEntitlementStatus status;
  final String? transactionId;
  final String? originalTransactionId;
  final int? signedDateMs;

  factory PremiumEntitlementDecision.fromMap(Map<dynamic, dynamic>? data) {
    final status = switch (data?['status']) {
      'active' => PremiumEntitlementStatus.active,
      'revoked' => PremiumEntitlementStatus.revoked,
      'absentAfterSync' => PremiumEntitlementStatus.absentAfterSync,
      _ => PremiumEntitlementStatus.unknown,
    };
    if (status == PremiumEntitlementStatus.unknown) {
      return const PremiumEntitlementDecision.unknown();
    }
    if (status == PremiumEntitlementStatus.absentAfterSync) {
      return PremiumEntitlementDecision(status: status);
    }
    final transactionId = data?['transactionId'];
    final originalId = data?['originalTransactionId'];
    final signedDate = data?['signedDateMs'];
    if (transactionId is! String ||
        transactionId.isEmpty ||
        originalId is! String ||
        originalId.isEmpty ||
        signedDate is! int) {
      return const PremiumEntitlementDecision.unknown();
    }
    return PremiumEntitlementDecision(
      status: status,
      transactionId: transactionId,
      originalTransactionId: originalId,
      signedDateMs: signedDate,
    );
  }

  /// A refund must match the cached purchase, never an unrelated older purchase.
  PremiumEntitlement? applyTo(PremiumEntitlement cached) {
    if (status == PremiumEntitlementStatus.unknown) return null;
    final matches =
        (transactionId != null && transactionId == cached.transactionId) ||
        (originalTransactionId != null &&
            originalTransactionId == cached.originalTransactionId);
    if (matches &&
        cached.signedDateMs != null &&
        (signedDateMs == null || signedDateMs! < cached.signedDateMs!)) {
      return null;
    }
    if (matches &&
        status == PremiumEntitlementStatus.active &&
        cached.source == 'revoked' &&
        cached.signedDateMs != null &&
        signedDateMs! <= cached.signedDateMs!) {
      return null;
    }
    if (status == PremiumEntitlementStatus.revoked) {
      if (!matches) return null;
    }
    return PremiumEntitlement(
      active: status == PremiumEntitlementStatus.active,
      source: status.name,
      transactionId: transactionId,
      originalTransactionId: originalTransactionId,
      signedDateMs: signedDateMs,
    );
  }
}
