import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/solarized-light.dart';
import 'package:flutter_tree_sitter_editor/flutter_tree_sitter_editor.dart';
import 'package:flutter_tree_sitter_python/flutter_tree_sitter_python.dart';
import 'package:flutter_tree_sitter_python/highlight.dart';

void main() {
  runApp(const App());
}

class ScrollBehavior extends MaterialScrollBehavior {
  const ScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      scrollBehavior: ScrollBehavior(),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final highlightTheme = solarizedLightTheme;
  final analyzer = TreeSitterAnalyzer(treeSitterPython);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(toolbarHeight: 0),
      backgroundColor: highlightTheme['root']?.backgroundColor,
      body: SingleChildScrollView(
        child: CodeEditor(
          initialCode: pythonCode,
          analyzer: analyzer,
          language: treeSitterPython,
          highlightQuery: pythonHighlightQuery,
          theme: toTreeSitterTheme(highlightTheme),
        ),
      ),
    );
  }
}

Map<String, TextStyle> toTreeSitterTheme(Map highlightTheme) {
  return {
    ...highlightTheme,
    'constant': highlightTheme['variable'],
    'function': highlightTheme['title'],
    'function.builtin': highlightTheme['title'],
    'operator': highlightTheme['built_in'],
  };
}

const pythonCode = '''
n = int(input('Type a number, and its factorial will be printed: '))

if n < 0:
    raise ValueError('You must enter a non-negative integer')

factorial = 1
for i in range(2, n + 1):
    factorial *= i

print(factorial)
''';
