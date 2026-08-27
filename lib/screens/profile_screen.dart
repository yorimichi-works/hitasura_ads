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
  late int _age;
  late final TextEditingController _region;
  late final TextEditingController _language;
  late String? _gender;
  late Set<String> _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = widget.controller.user;
    final profile = widget.controller.profile;
    _nickname = TextEditingController(text: user?.nickname ?? '');
    _age = (user?.age ?? 20).clamp(1, 100);
    _region = TextEditingController(text: profile.region ?? '日本');
    _language = TextEditingController(text: profile.language ?? '日本語');
    _gender = profile.gender == '女性' ? '女性' : '男性';
    _selected = {...profile.interests};
  }

  @override
  void dispose() {
    _nickname.dispose();
    _region.dispose();
    _language.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await widget.controller.updateProfile(
      nickname: _nickname.text.trim().isEmpty ? '広告大好き' : _nickname.text,
      age: _age,
      explorationProfile: ExplorationProfile(
        ageGroup: ageGroupFor(_age),
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
                  DropdownButtonFormField<int>(
                    key: const Key('profile-age'),
                    initialValue: _age,
                    decoration: const InputDecoration(
                      labelText: '実年齢',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (var age = 1; age <= 100; age++)
                        DropdownMenuItem(value: age, child: Text('$age歳')),
                    ],
                    onChanged: (value) => setState(() => _age = value ?? _age),
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
                  const Text(
                    '性別',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    key: const Key('profile-gender'),
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
                    selected: {_gender!},
                    onSelectionChanged: (values) =>
                        setState(() => _gender = values.single),
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
