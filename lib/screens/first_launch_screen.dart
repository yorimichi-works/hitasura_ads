import 'package:flutter/material.dart';

import '../state/app_controller.dart';

class FirstLaunchScreen extends StatefulWidget {
  const FirstLaunchScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<FirstLaunchScreen> createState() => _FirstLaunchScreenState();
}

class _FirstLaunchScreenState extends State<FirstLaunchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nickname = TextEditingController(text: '広告大好き');
  int _age = 29;
  String _gender = '男性';
  bool _saving = false;

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await widget.controller.register(_nickname.text, _age, _gender);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(width: 4),
                  boxShadow: const [
                    BoxShadow(color: Colors.black, offset: Offset(8, 8)),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'PR / AD / Sponsored',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'ひたすら\n広告',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.displayLarge,
                        ),
                        const SizedBox(height: 12),
                        const Text('広告を見る。それだけ。', textAlign: TextAlign.center),
                        const SizedBox(height: 28),
                        TextFormField(
                          controller: _nickname,
                          maxLength: 20,
                          decoration: const InputDecoration(
                            labelText: 'ニックネーム',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'ニックネームを入力してください'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          key: const Key('first-launch-age'),
                          initialValue: _age,
                          decoration: const InputDecoration(
                            labelText: '年齢',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (var age = 1; age <= 100; age++)
                              DropdownMenuItem(
                                value: age,
                                child: Text('$age歳'),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _age = value ?? _age),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '性別',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        SegmentedButton<String>(
                          key: const Key('first-launch-gender'),
                          segments: const [
                            ButtonSegment(
                              value: '男性',
                              label: Text('男'),
                              icon: Icon(Icons.male),
                            ),
                            ButtonSegment(
                              value: '女性',
                              label: Text('女'),
                              icon: Icon(Icons.female),
                            ),
                          ],
                          selected: {_gender},
                          onSelectionChanged: (values) =>
                              setState(() => _gender = values.single),
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _saving ? null : _submit,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(58),
                          ),
                          child: Text(
                            _saving ? '準備中…' : 'はじめる',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'プロフィールによって出現する広告が変わります。',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
