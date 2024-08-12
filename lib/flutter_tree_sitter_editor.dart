import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tree_sitter/flutter_tree_sitter.dart' hide Stack;

class CodeEditor extends StatefulWidget {
  final String? initialCode;
  final ValueChanged<String>? onChanged;
  final Pointer<TSLanguage> language;
  final String highlightQuery;
  final Map<String, TextStyle> theme;
  final TextStyle? textStyle;

  const CodeEditor({
    super.key,
    required this.language,
    this.initialCode,
    this.onChanged,
    this.theme = const {},
    this.highlightQuery = '',
    this.textStyle,
  });

  @override
  State<CodeEditor> createState() => _CodeEditorState();
}

class _CodeEditorState extends State<CodeEditor> {
  var treeString = '';
  final text = TextEditingController();
  final parser = TreeSitterParser();
  late Highlighter highlighter;
  var tokens = <HighlightSpan>[];
  TreeSitterTree? tree;

  @override
  void initState() {
    super.initState();
    parser.setLanguage(widget.language);
    text.text = widget.initialCode ?? '';
    highlighter = Highlighter(
      widget.language,
      highlightQuery: widget.highlightQuery,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      update();
    });
  }

  @override
  void dispose() {
    tree?.delete();
    parser.delete();
    highlighter.delete();
    super.dispose();
  }

  void update() {
    tree?.delete();
    tree = parser.parseString(text.text);
    setState(() {
      tokens = highlighter.render(
        text.text,
        highlighter.highlight(tree!.rootNode),
      );
    });
    getErrors(tree!.rootNode);
  }

  void getErrors(TSNode rootNode) {
    final codeBytes = utf8.encode(text.text);
    final query = TreeSitterQuery(widget.language, '(ERROR) @error');
    for (final capture in query.captures(rootNode)) {
      final start = capture.node.startPoint;
      final position = '${start.row + 1}:${start.column + 1}';
      final errorTokens = utf8.decode(codeBytes.sublist(
        capture.node.startByte,
        capture.node.endByte,
      ));
      if (treeSitter.ts_node_is_missing(capture.node)) {
        print('$position missing $errorTokens');
      } else {
        print('$position unexpected $errorTokens');
      }
    }
    query.delete();
  }

  @override
  Widget build(BuildContext context) {
    final lines = text.text.split('\n');
    var textStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 12,
      color: widget.theme['root']?.color ??
          Theme.of(context).textTheme.bodyMedium?.color,
      height: 1.5,
      letterSpacing: 0,
    );
    textStyle = textStyle.merge(widget.textStyle);

    return Container(
      color: widget.theme['root']?.backgroundColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < lines.length; i += 1)
                  Text('${i + 1}', style: textStyle),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Stack(children: [
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: RichText(
                    text: TextSpan(style: textStyle, children: [
                      for (final token in tokens)
                        TextSpan(
                          text: token.text,
                          style: textStyle.merge(widget.theme[token.type]),
                        ),
                    ]),
                  ),
                ),
                Positioned.fill(
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      textSelectionTheme: TextSelectionThemeData(
                        selectionColor:
                            widget.theme['comment']?.color?.withOpacity(0.5),
                      ),
                    ),
                    child: TextField(
                      controller: text,
                      onChanged: (_) => update(),
                      maxLines: null,
                      cursorColor: widget.theme['root']?.color,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.only(top: 4),
                        border: InputBorder.none,
                      ),
                      style: textStyle.copyWith(color: Colors.transparent),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
