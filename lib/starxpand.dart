import 'dart:async';

import 'package:flutter/services.dart';
import 'package:starxpand/models/starxpand_document.dart';
import 'package:starxpand/models/starxpand_printer.dart';

export 'package:starxpand/models/starxpand_printer.dart';
export 'package:starxpand/models/starxpand_document.dart';
export 'package:starxpand/models/starxpand_document_print.dart';
export 'package:starxpand/models/starxpand_document_drawer.dart';

class StarXpand {
  static const MethodChannel _channel = MethodChannel('starxpand');

  static Future<List<StarXpandPrinter>> find() async {
    Map<String, dynamic> result =
        Map<String, dynamic>.from(await _channel.invokeMethod('find') as Map);
    List printers = result["printers"];
    return printers
        .map((e) => StarXpandPrinter.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<bool> openDrawer(StarXpandPrinter printer) async {
    return await _channel
        .invokeMethod('openDrawer', {"printer": printer.toMap()});
  }

  static Future<bool> print(
      StarXpandPrinter printer, StarXpandDocument document) async {
    return await _channel.invokeMethod(
        'print', {"printer": printer.toMap(), "document": document.toMap()});
  }

  static startInputListener(StarXpandPrinter printer) {
    return _channel
        .invokeMethod('startInputListener', {"printer": printer.toMap()});
  }
}
