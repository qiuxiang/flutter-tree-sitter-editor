import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_tree_sitter/flutter_tree_sitter.dart';

class TextDocument {
  final TSNode node;
  final Uint8List bytes;

  const TextDocument(this.node, this.bytes);

  String getNodeText(TSNode node) {
    return utf8.decode(bytes.sublist(node.startByte, node.endByte));
  }
}
