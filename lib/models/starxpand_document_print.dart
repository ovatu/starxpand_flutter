import 'dart:ffi';
import 'dart:typed_data';
import 'dart:ui';

import 'package:starxpand/models/starxpand_document.dart';

enum StarXpandCutType { full, partial, fullDirect, partialDirect }
enum StarXpandBarcodeSymbology {
  upcE,
  upcA,
  jan8,
  ean8,
  jan13,
  ean13,
  code39,
  itf,
  code128,
  code93,
  nw7
}
enum StarXpandBarcodeBarRatioLevel { levelPlus1, level0, levelMinus1 }

enum StarXpandPdf417Level {
  ecc0,
  ecc1,
  ecc2,
  ecc3,
  ecc4,
  ecc5,
  ecc6,
  ecc7,
  ecc8
}

enum StarXpandQRCodeModel { model1, model2 }
enum StarXpandQRCodeLevel { l, m, q, h }

enum StarXpandStyleAlignment { left, center, right }
enum StarXpandStyleFontType { a, b }
enum StarXpandStyleInternationalCharacter {
  usa,
  france,
  germany,
  uk,
  denmark,
  sweden,
  italy,
  spain,
  japan,
  norway,
  denmark2,
  spain2,
  latinAmerica,
  korea,
  ireland,
  slovenia,
  croatia,
  china,
  vietnam,
  arabic,
  legal
}
enum StarXpandStyleCharacterEncodingType {
  japanese,
  simplifiedChinese,
  traditionalChinese,
  korean,
  codePage
}
enum StarXpandStyleCjkCharacterType {
  japanese,
  simplifiedChinese,
  traditionalChinese,
  korean
}

class StarXpandStyleMagnification {
  final int width;
  final int height;

  StarXpandStyleMagnification(this.width, this.height);

  Map toMap() => {'width': width, 'height': height};
}

class StarXpandDocumentPrint extends StarXpandDocumentContent {
  final List<Map> _actions = [];

  @override
  String get type => 'print';

  style({
    StarXpandStyleAlignment? alignment,
    StarXpandStyleFontType? fontType,
    bool? bold,
    bool? invert,
    bool? underLine,
    StarXpandStyleMagnification? magnification,
    double? characterSpace,
    double? lineSpace,
    double? horizontalPositionTo,
    double? horizontalPositionBy,
    List<int>? horizontalTabPosition,
    StarXpandStyleInternationalCharacter? internationalCharacter,
    StarXpandStyleCharacterEncodingType? secondPriorityCharacterEncoding,
    List<StarXpandStyleCjkCharacterType>? cjkCharacterPriority,
  }) {
    _actions.add({
      'action': 'style',
      'alignment': alignment?.name,
      'fontType': fontType?.name,
      'bold': bold,
      'invert': invert,
      'underLine': underLine,
      'magnification': magnification?.toMap(),
      'characterSpace': characterSpace,
      'lineSpace': lineSpace,
      'horizontalPositionTo': horizontalPositionTo,
      'horizontalPositionBy': horizontalPositionBy,
      'horizontalTabPosition': horizontalTabPosition,
      'internationalCharacter': internationalCharacter?.name,
      'secondPriorityCharacterEncoding': secondPriorityCharacterEncoding?.name,
      'cjkCharacterPriority': cjkCharacterPriority?.map((e) => e.name).toList()
    });
  }

  add(StarXpandDocumentPrint print) {
    _actions.add({'action': 'add', 'data': print.getData()});
  }

  actionCut(StarXpandCutType type) {
    _actions.add({'action': 'cut', 'type': type.name});
  }

  actionFeed(double height) {
    _actions.add({'action': 'feed', 'height': height});
  }

  actionFeedLine(int lines) {
    _actions.add({'action': 'feedLine', 'lines': lines});
  }

  actionPrintText(String text) {
    _actions.add({'action': 'printText', 'text': text});
  }

  actionPrintLogo(String keyCode) {
    _actions.add({'action': 'printLogo', 'keyCode': keyCode});
  }

  actionPrintBarcode(String content,
      {StarXpandBarcodeSymbology? symbology,
      bool? printHri,
      int? barDots,
      StarXpandBarcodeBarRatioLevel? barRatioLevel,
      double? height}) {
    _actions.add({
      'action': 'printBarcode',
      'content': content,
      'symbology': symbology?.name,
      'printHri': printHri,
      'barDots': barDots,
      'barRatioLevel': barRatioLevel?.name,
      'height': height
    });
  }

  actionPrintPdf417(String content,
      {int? column,
      int? line,
      int? module,
      int? aspect,
      StarXpandPdf417Level? level}) {
    _actions.add({
      'action': 'printPdf417',
      'content': content,
      'line': line,
      'module': module,
      'aspect': aspect,
      'level': level?.name
    });
  }

  actionPrintQRCode(String content,
      {StarXpandQRCodeModel? model,
      StarXpandQRCodeLevel? level,
      int? cellSize}) {
    _actions.add({
      'action': 'printQRCode',
      'content': content,
      'model': model?.name,
      'level': level?.name,
      'cellSize': cellSize
    });
  }

  actionPrintImage(Uint8List image, int width) {
    _actions.add({'action': 'printImage', 'image': image, 'width': width});
  }

  @override
  Map getData() {
    return {"actions": _actions};
  }
}
