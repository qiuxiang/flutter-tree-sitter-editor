import 'dart:ffi';

import 'package:flutter_tree_sitter/flutter_tree_sitter.dart';
import 'package:flutter_tree_sitter_editor/src/text_document.dart';

typedef Position = (int, int);
typedef Range = (Position, Position);

enum DiagnosticSeverity { error, warning }

class Diagnostic {
  final DiagnosticSeverity severity;
  final Range range;
  final String message;

  const Diagnostic({
    required this.severity,
    required this.range,
    required this.message,
  });

  @override
  String toString() =>
      'Diagnostic(severity: $severity, range: $range, message: $message)';
}

abstract class AbstractAnalyzer {
  Future<List<Diagnostic>> analyze(TextDocument document);
}

class TreeSitterAnalyzer implements AbstractAnalyzer {
  final Pointer<TSLanguage> language;

  const TreeSitterAnalyzer(this.language);

  @override
  Future<List<Diagnostic>> analyze(TextDocument document) async {
    final diagnostics = <Diagnostic>[];
    final query = TreeSitterQuery(language, '(ERROR) @error');
    for (final capture in query.captures(document.node)) {
      final start = capture.node.startPoint;
      final end = capture.node.endPoint;
      final errorTokens = document.getNodeText(capture.node);
      final message = treeSitter.ts_node_is_missing(capture.node)
          ? 'missing $errorTokens'
          : errorTokens;
      diagnostics.add(Diagnostic(
        severity: DiagnosticSeverity.error,
        range: ((start.row, start.column), (end.row, end.column)),
        message: message,
      ));
    }
    query.delete();
    return diagnostics;
  }
}
