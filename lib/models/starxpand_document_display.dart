import 'dart:typed_data';

import 'package:starxpand/models/starxpand_document.dart';
import 'package:starxpand/starxpand.dart';

enum Contrast {
  minus3,
  minus2,
  minus1,
  Default,
  plus1,
  plus2,
  plus3,
}

class StarXpandDocumentDisplay extends StarXpandDocumentContent {
  final List<Map> _actions = [];

  StarXpandDocumentDisplay();

  @override
  String get type => 'display';

  actionShowText(String data) {
    _actions.add({'action': 'showText', 'data': data});
  }

  actionClearAll() {
    _actions.add({'action': 'clearAll'});
  }

  actionClearLine() {
    _actions.add({'action': 'clearLine'});
  }

  actionShowImage(Uint8List image) {
    _actions.add({'action': 'showImage', 'image': image });
  }

  actionSetContrast(Contrast contrast) {
    _actions.add({
      'action': 'setContrast',
      'content': contrast.name,
    });
  }

  @override
  Map getData() {
    return {"actions": _actions};
  }
}
