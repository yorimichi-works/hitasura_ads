import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../state/app_controller.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _interests = [
    'ゲーム',
    '漫画',
    'アニメ',
    '映画',
    '音楽',
    '旅行',
    'グルメ',
    'ファッション',
    'IT',
    '車',
    '教育',
    'ビジネス',
    'その他',
  ];
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nickname;
  late final TextEditingController _age;
  late final TextEditingController _region;
  late final TextEditingController _language;
  late String? _ageGroup;
  late String? _gender;
  late Set<String> _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = widget.controller.user!;
    final profile = widget.controller.profile;
    _nickname = TextEditingController(text: user.nickname);
    _age = TextEditingController(text: user.age.toString());
    _region = TextEditingController(text: profile.region ?? '日本');
    _language = TextEditingController(text: profile.language ?? '日本語');
    _ageGroup = profile.ageGroup;
    _gender = profile.gender;
    _selected = {...profile.interests};
  }

  @override
  void dispose() {
    _nickname.dispose();
    _age.dispose();
    _region.dispose();
    _language.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await widget.controller.updateProfile(
      nickname: _nickname.text,
      age: int.parse(_age.text),
      explorationProfile: ExplorationProfile(
        ageGroup: _ageGroup,
        gender: _gender,
        region: _region.text.trim().isEmpty ? null : _region.text.trim(),
        language: _language.text.trim().isEmpty ? null : _language.text.trim(),
        interests: _selected,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('広告探索プロフィールを保存しました')));
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [
          const Text(
            '広告探索',
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
          ),
          const Text('いろいろな架空広告を探すためのプロフィール'),
          const SizedBox(height: 16),
          const _Notice(),
          const SizedBox(height: 16),
          Card(
            child: SwitchListTile(
              key: const Key('sound-effects-toggle'),
              secondary: const Icon(Icons.volume_up_outlined),
              title: const Text('効果音'),
              subtitle: const Text('広告の操作音と新規発見音'),
              value: widget.controller.soundEffectsEnabled,
              onChanged: widget.controller.setSoundEffectsEnabled,
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'ユーザー設定',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _nickname,
                    decoration: const InputDecoration(
                      labelText: 'ニックネーム',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? '入力してください'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _age,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '実年齢',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final age = int.tryParse(value ?? '');
                      return age == null || age < 1 || age > 120
                          ? '1〜120の数字で入力してください'
                          : null;
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '探索条件',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _ageGroup,
                    decoration: const InputDecoration(
                      labelText: '探索用の年齢層',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        [
                              '18歳未満',
                              '18〜24歳',
                              '25〜34歳',
                              '35〜44歳',
                              '45〜54歳',
                              '55〜64歳',
                              '65歳以上',
                            ]
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                    onChanged: (value) => setState(() => _ageGroup = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _gender,
                    decoration: const InputDecoration(
                      labelText: '探索用の性別設定',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: '設定しない', child: Text('設定しない')),
                      DropdownMenuItem(value: '女性', child: Text('女性')),
                      DropdownMenuItem(value: '男性', child: Text('男性')),
                      DropdownMenuItem(value: 'その他', child: Text('その他')),
                    ],
                    onChanged: (value) => setState(() => _gender = value),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _region,
                    decoration: const InputDecoration(
                      labelText: '地域',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _language,
                    decoration: const InputDecoration(
                      labelText: '言語',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '興味・関心',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final interest in _interests)
                        FilterChip(
                          label: Text(interest),
                          selected: _selected.contains(interest),
                          onSelected: (selected) => setState(
                            () => selected
                                ? _selected.add(interest)
                                : _selected.remove(interest),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            child: Text(_saving ? '保存中…' : '保存する'),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFE082),
      border: Border.all(width: 2),
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.privacy_tip_outlined),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'ここで選ぶ条件は架空広告を探すためだけのものです。本人の実属性、広告パーソナライズ同意、トラッキング同意とは完全に分離されます。',
          ),
        ),
      ],
    ),
  );
}
