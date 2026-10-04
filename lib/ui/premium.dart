import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/premium_purchase_service.dart';
import '../services/store_price_diagnostic.dart';
import '../state/app_controller.dart';
import 'kit.dart';
import 'store_price_diagnostic.dart';

/// The home entry and Settings share the same purchase and restore controls.
class PremiumScreen extends StatelessWidget {
  const PremiumScreen({
    super.key,
    required this.controller,
    this.purchaseService,
  });
  final AppController controller;
  final PremiumPurchaseService? purchaseService;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: NightBackground(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
              children: [
                Row(
                  children: [
                    BackButton(color: K.paper),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        L10n.ui('premium_home_entry'),
                        style: K.t(22, color: K.yellow),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Sticker(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.block_rounded, color: K.ink, size: 36),
                      const SizedBox(height: 12),
                      Text(
                        L10n.ui('premium_title'),
                        style: K.t(24, color: K.ink),
                      ),
                      const SizedBox(height: 16),
                      PremiumPurchasePanel(
                        controller: controller,
                        purchaseService: purchaseService,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class PremiumPurchasePanel extends StatefulWidget {
  const PremiumPurchasePanel({
    super.key,
    required this.controller,
    this.purchaseService,
  });

  final AppController controller;
  // Allows deterministic widget tests without opening a real store sheet.
  final PremiumPurchaseService? purchaseService;

  @override
  State<PremiumPurchasePanel> createState() => _PremiumPurchasePanelState();
}

class _PremiumPurchasePanelState extends State<PremiumPurchasePanel> {
  bool _refreshStarted = false;

  PremiumPurchaseService get purchases =>
      widget.purchaseService ?? widget.controller.purchases;

  @override
  void initState() {
    super.initState();
    // Refresh immediately before showing prices, outside the build phase.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(purchases.refreshCatalogue());
      setState(() => _refreshStarted = true);
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([widget.controller, purchases]),
    builder: (context, _) {
      final owned = widget.controller.premiumNoAds;
      final loading = !_refreshStarted || purchases.catalogueLoading;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(L10n.ui('premium_desc'), style: K.t(16, color: K.ink)),
          const SizedBox(height: 10),
          Text(L10n.ui('premium_games_stay'), style: K.t(14, color: K.ink)),
          const SizedBox(height: 20),
          if (owned)
            Semantics(
              liveRegion: true,
              child: Text(
                L10n.ui('premium_active'),
                style: K.t(18, color: K.ink),
              ),
            )
          else ...[
            if (loading)
              Semantics(
                liveRegion: true,
                child: Text(
                  L10n.ui('premium_loading'),
                  style: K.t(14, color: K.ink),
                ),
              ),
            ElevatedButton(
              key: const ValueKey('premium-buy'),
              style: ElevatedButton.styleFrom(
                backgroundColor: K.yellow,
                foregroundColor: K.ink,
                disabledBackgroundColor: K.ink.withValues(alpha: .08),
                disabledForegroundColor: K.ink.withValues(alpha: .55),
                minimumSize: const Size.fromHeight(52),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontFamily: K.font,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              onPressed: !loading && purchases.canBuy ? purchases.buy : null,
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text(L10n.ui('premium_buy')),
                  if (!loading && purchases.product != null)
                    // Isolate store-formatted prices from surrounding RTL copy.
                    // Currency symbols must stay beside the original amount.
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(purchases.product!.price),
                    ),
                ],
              ),
            ),
            if (!loading && purchases.product == null) ...[
              Text(
                L10n.ui('premium_unavailable'),
                style: K.t(14, color: K.ink),
              ),
              TextButton(
                onPressed: purchases.busy ? null : purchases.refreshCatalogue,
                style: TextButton.styleFrom(foregroundColor: K.ink),
                child: Text(L10n.ui('premium_retry')),
              ),
            ],
          ],
          TextButton(
            key: const ValueKey('premium-restore'),
            onPressed: purchases.canRestore ? purchases.restore : null,
            style: TextButton.styleFrom(
              foregroundColor: K.ink,
              disabledForegroundColor: K.ink.withValues(alpha: .55),
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(
              L10n.ui('restore_purchases'),
              textAlign: TextAlign.center,
            ),
          ),
          if (purchases.error != null)
            Semantics(
              liveRegion: true,
              child: Text(
                L10n.ui('premium_error'),
                style: K.t(14, color: K.red),
              ),
            ),
          if (priceDiagnosticsEnabled)
            StorePriceDiagnosticPanel(
              displayedProduct: () => purchases.product,
            ),
        ],
      );
    },
  );
}
