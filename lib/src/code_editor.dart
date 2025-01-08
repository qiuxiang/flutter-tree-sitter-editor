import 'dart:async';
import 'dart:convert';
import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:flutter_tree_sitter/flutter_tree_sitter.dart' hide Stack;
import 'package:flutter_tree_sitter_editor/src/analyzer.dart';
import 'package:flutter_tree_sitter_editor/src/text_document.dart';

class CodeEditor extends StatefulWidget {
  final String? initialCode;
  final ValueChanged<String>? onChanged;
  final Pointer<TSLanguage> language;
  final String highlightQuery;
  final Map<String, TextStyle> theme;
  final TextStyle? textStyle;
  final AbstractAnalyzer? analyzer;

  const CodeEditor({
    super.key,
    required this.language,
    this.initialCode,
    this.onChanged,
    this.theme = const {},
    this.highlightQuery = '',
    this.textStyle,
    this.analyzer,
  });

  @override
  State<CodeEditor> createState() => _CodeEditorState();
}

class _CodeEditorState extends State<CodeEditor> {
  final text = TextEditingController();
  final parser = TreeSitterParser();
  late final Highlighter highlighter;
  final tokens = StreamController<List<HighlightSpan>>();
  final lines = StreamController<int>();
  TreeSitterTree? tree;
  late TextDocument document;
  final diagnosticsMap = <int, List<Diagnostic>>{};

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
    lines.add(text.text.split('\n').length);
    tree?.delete();
    tree = parser.parseString(text.text);
    document = TextDocument(tree!.rootNode, utf8.encode(text.text));
    widget.analyzer?.analyze(document).then((diagnostics) {
      if (diagnostics.isNotEmpty) {
        // setState(() {
        diagnosticsMap.clear();
        for (final diagnostic in diagnostics) {
          final range = diagnostic.range;
          final line = range.$1.$1;
          if (diagnosticsMap.containsKey(line)) {
            diagnosticsMap[line]!.add(diagnostic);
          } else {
            diagnosticsMap[line] = [diagnostic];
          }
        }
        // });
      }
    });
    // setState(() {
    tokens.add(highlighter.render(
      document.bytes,
      highlighter.highlight(tree!.rootNode),
    ));
    // });
  }

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
            child: StreamBuilder(
              stream: lines.stream,
              builder: (context, snapshot) {
                final lines = snapshot.data ?? 0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < lines; i += 1)
                      Builder(
                        key: Key('$i'),
                        builder: (context) {
                          Widget? icon;
                          final diagnostics = diagnosticsMap[i];
                          if (diagnostics != null) {
                            icon = Tooltip(
                              message:
                                  diagnostics.map((i) => i.message).join('\n'),
                              child: Icon(
                                Icons.error_rounded,
                                size: textStyle.fontSize! + 2,
                                color: Colors.red,
                              ),
                            );
                          }
                          return Row(children: [
                            Text('${i + 1}', style: textStyle),
                            Container(
                              width: 16,
                              padding: const EdgeInsets.only(left: 4),
                              child: icon,
                            ),
                          ]);
                        },
                      ),
                  ],
                );
              },
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Stack(children: [
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: StreamBuilder(
                    stream: tokens.stream,
                    builder: (context, snapshot) {
                      final tokens = snapshot.data ?? [];
                      return RichText(
                        text: TextSpan(style: textStyle, children: [
                          for (final token in tokens)
                            TextSpan(
                              text: token.text,
                              style: textStyle.merge(widget.theme[token.type]),
                            ),
                        ]),
                      );
                    },
                  ),
                ),
                Positioned.fill(
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      textSelectionTheme: TextSelectionThemeData(
                        selectionColor: widget.theme['comment']?.color
                            ?.withValues(alpha: 0.5),
                      ),
                    ),
                    child: TextField(
                      controller: text,
                      onChanged: (_) => update(),
                      maxLines: null,
                      cursorColor: widget.theme['root']?.color,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
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
