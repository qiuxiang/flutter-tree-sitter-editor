import 'dart:async';
import 'dart:convert';
import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:flutter_tree_sitter/flutter_tree_sitter.dart' hide Stack;
import 'package:flutter_tree_sitter_editor/src/analyzer.dart';
import 'package:flutter_tree_sitter_editor/src/text_document.dart';
import 'package:provider/provider.dart';

class CodeEditor extends StatefulWidget {
  final String? initialCode;
  final ValueChanged<String>? onChanged;
  final Pointer<TSLanguage>? language;
  final String? highlightQuery;
  final Map<String, TextStyle>? theme;
  final TextStyle? textStyle;
  final AbstractAnalyzer? analyzer;
  final TextEditingController? controller;

  const CodeEditor({
    super.key,
    this.language,
    this.controller,
    this.initialCode,
    this.onChanged,
    this.theme,
    this.highlightQuery,
    this.textStyle,
    this.analyzer,
  });

  @override
  State<CodeEditor> createState() => _CodeEditorState();
}

class _CodeEditorState extends State<CodeEditor> {
  late TextEditingController code;
  TreeSitterParser? parser;
  Highlighter? highlighter;
  final tokens = StreamController<List<HighlightSpan>>();
  final lines = StreamController<int>();
  TreeSitterTree? tree;
  late TextDocument document;
  final diagnosticsMap = StreamController<Map<int, List<Diagnostic>>>();
  var textFieldWidth = 0.0;
  final textPainter = TextPainter(textDirection: TextDirection.ltr);
  late TextStyle textStyle;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      code = TextEditingController();
    } else {
      code = widget.controller!;
    }
    if (widget.initialCode != null) {
      code.text = widget.initialCode!;
    }
    if (widget.language != null) {
      parser = TreeSitterParser();
      parser!.setLanguage(widget.language!);
      if (widget.highlightQuery != null) {
        highlighter = Highlighter(
          widget.language!,
          highlightQuery: widget.highlightQuery!,
        );
      }
    }
    updateTextStyle();
    updateTextLayout();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      update();
    });
    code.addListener(() {
      update();
    });
  }

  @override
  void dispose() {
    tree?.delete();
    parser?.delete();
    highlighter?.delete();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CodeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.textStyle != widget.textStyle) {
      updateTextStyle();
    }
  }

  void update() {
    lines.add(code.text.split('\n').length);
    tree?.delete();
    tree = parser?.parseString(code.text);
    if (tree != null) {
      document = TextDocument(tree!.rootNode, utf8.encode(code.text));
      widget.analyzer?.analyze(document).then((diagnostics) {
        final diagnosticsMap = <int, List<Diagnostic>>{};
        for (final diagnostic in diagnostics) {
          final range = diagnostic.range;
          final line = range.$1.$1;
          if (diagnosticsMap.containsKey(line)) {
            diagnosticsMap[line]!.add(diagnostic);
          } else {
            diagnosticsMap[line] = [diagnostic];
          }
        }
        this.diagnosticsMap.add(diagnosticsMap);
      });
    }
    if (highlighter == null) {
      tokens.add([HighlightSpan('', code.text)]);
    } else {
      tokens.add(highlighter!.render(
        document.bytes,
        highlighter!.highlight(tree!.rootNode),
      ));
    }
  }

  void updateTextLayout() {
    setState(() {
      textPainter.text = TextSpan(
        text: code.text,
        style: textStyle,
      );
      textPainter.layout();
    });
  }

  void updateTextStyle() {
    textStyle = TextStyle(
      fontFamily: 'monospace',
      fontFamilyFallback: const <String>[
        'menlo',
        'cascadia code',
        'microsoft yahei'
      ],
      fontSize: 12,
      color: widget.theme?['root']?.color ??
          Theme.of(context).textTheme.bodyMedium?.color,
      height: 1.5,
      letterSpacing: 0,
    );
    textStyle = textStyle.merge(widget.textStyle);
  }

  @override
  Widget build(BuildContext context) {
    final structStyle =
        StrutStyle.fromTextStyle(textStyle, forceStrutHeight: true);
    return MultiProvider(
      providers: [
        StreamProvider.value(value: lines.stream, initialData: 0),
        StreamProvider.value(
          value: diagnosticsMap.stream,
          initialData: const <int, List<Diagnostic>>{},
        ),
      ],
      child: Container(
        color: widget.theme?['root']?.backgroundColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
              child: SignColumn(textStyle: textStyle),
            ),
            Expanded(
              child: LayoutBuilder(builder: (context, box) {
                final child = Stack(children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: StreamBuilder(
                      stream: tokens.stream,
                      builder: (context, snapshot) {
                        final tokens = snapshot.data ?? [];
                        return RichText(
                          strutStyle: structStyle,
                          text: TextSpan(style: textStyle, children: [
                            for (final token in tokens)
                              TextSpan(
                                text: token.text,
                                style:
                                    textStyle.merge(widget.theme?[token.type]),
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
                          selectionColor: widget.theme?['comment']?.color
                              ?.withValues(alpha: 0.5),
                        ),
                      ),
                      child: TextField(
                        controller: code,
                        onChanged: (value) {
                          widget.onChanged?.call(value);
                        },
                        maxLines: null,
                        cursorColor: widget.theme?['root']?.color,
                        keyboardType: TextInputType.multiline,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.all(0),
                        ),
                        style: textStyle.copyWith(color: Colors.transparent),
                        strutStyle: structStyle,
                      ),
                    ),
                  ),
                ]);
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: (textPainter.width + 4) > box.maxWidth
                        ? null
                        : box.maxWidth,
                    child: child,
                  ),
                );
              }),
            ),
          ]),
        ),
      ),
    );
  }
}

class SignColumn extends StatelessWidget {
  final TextStyle textStyle;
  const SignColumn({super.key, required this.textStyle});

  @override
  Widget build(BuildContext context) {
    final lines = context.watch<int>();
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      for (var i = 0; i < lines; i += 1)
        Builder(
          key: Key('$i'),
          builder: (context) {
            Widget? icon;
            final diagnostics = context.select(
              (Map<int, List<Diagnostic>> map) => map[i],
            );
            if (diagnostics != null) {
              icon = Tooltip(
                message: diagnostics.map((i) => i.message).join('\n'),
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
    ]);
  }
}
