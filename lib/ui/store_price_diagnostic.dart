import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../services/store_price_diagnostic.dart';
import 'kit.dart';

class StorePriceDiagnosticPanel extends StatefulWidget {
  const StorePriceDiagnosticPanel({
    super.key,
    required this.displayedProduct,
    this.reader,
  });

  final ProductDetails? Function() displayedProduct;
  final StorePriceDiagnostic? reader;

  @override
  State<StorePriceDiagnosticPanel> createState() =>
      _StorePriceDiagnosticPanelState();
}

class _StorePriceDiagnosticPanelState extends State<StorePriceDiagnosticPanel> {
  late final StorePriceDiagnostic _reader =
      widget.reader ?? StorePriceDiagnostic();
  bool _busy = false;
  String? _report;

  Future<void> _read() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _report = null;
    });
    final report = await _reader.read(
      displayedProduct: widget.displayedProduct(),
    );
    if (!mounted) return;
    setState(() {
      _report = const JsonEncoder.withIndent('  ').convert(report);
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text('価格の取得情報（本人確認用）', style: K.t(14, color: K.ink)),
        Text(
          '画面表示・Flutter再照会・Apple直接照会を比較します。\n'
          '購入せず、結果はこの画面にだけ表示します。\n'
          '同じ操作で照会しますが、完全に同時の値とは限りません。',
          style: K.t(12, color: K.ink),
        ),
        TextButton(
          key: const ValueKey('read-price-diagnostic'),
          onPressed: _busy ? null : _read,
          style: TextButton.styleFrom(
            foregroundColor: K.ink,
            disabledForegroundColor: K.ink.withValues(alpha: .55),
            minimumSize: const Size.fromHeight(48),
            textStyle: K.t(14, color: K.ink),
          ),
          child: Text(_busy ? '確認中…' : 'Appleの価格情報を確認'),
        ),
        if (_report != null)
          SelectableText(
            _report!,
            key: const ValueKey('price-diagnostic-result'),
            style: K.t(12, color: K.ink),
          ),
      ],
    ),
  );
}
