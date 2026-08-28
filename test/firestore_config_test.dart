import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('firebase.json references repository Firestore configuration', () {
    final config = jsonDecode(
      File('firebase.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final firestore = config['firestore'] as Map<String, dynamic>;

    expect(firestore['rules'], 'firestore.rules');
    expect(firestore['indexes'], 'firestore.indexes.json');
    expect(File(firestore['rules'] as String).existsSync(), isTrue);
    expect(File(firestore['indexes'] as String).existsSync(), isTrue);
  });

  test('Firestore users rules require authenticated document ownership', () {
    final rules = File('firestore.rules').readAsStringSync();

    expect(rules, contains('request.auth.uid == userId'));
    expect(rules, contains('request.resource.data.uid == userId'));
    expect(
      rules,
      contains('request.resource.data.email == request.auth.token.email'),
    );
    expect(
      rules,
      contains('request.resource.data.createdAt == resource.data.createdAt'),
    );
    expect(rules, isNot(contains('allow read, write: if true')));
  });
}
