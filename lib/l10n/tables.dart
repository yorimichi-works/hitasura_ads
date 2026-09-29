// Registry of translation tables. Languages without a table fall back to
// English automatically.
import 'games/en.dart';
import 'games/ja.dart';
import 'ui/en.dart';
import 'ui/ja.dart';

const Map<String, Map<String, String>> uiTables = {
  'en': uiEn,
  'ja': uiJa,
};

const Map<String, Map<int, List<String>>> gameTables = {
  'en': gameTextsEn,
  'ja': gameTextsJa,
};

const Map<String, Map<String, String>> wordTables = {};
