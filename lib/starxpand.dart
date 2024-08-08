import 'dart:async';

import 'package:flutter/services.dart';
import 'package:starxpand/models/starxpand_callbacks.dart';
import 'package:starxpand/models/starxpand_document.dart';
import 'package:starxpand/models/starxpand_document_display.dart';
import 'package:starxpand/models/starxpand_document_drawer.dart';
import 'package:starxpand/models/starxpand_printer.dart';
import 'package:starxpand/models/starxpand_status.dart';
import 'package:uuid/uuid.dart';

export 'package:starxpand/models/starxpand_callbacks.dart';
export 'package:starxpand/models/starxpand_document.dart';
export 'package:starxpand/models/starxpand_document_drawer.dart';
export 'package:starxpand/models/starxpand_document_print.dart';
export 'package:starxpand/models/starxpand_printer.dart';

class StarXpand {
  static final MethodChannel _channel = const MethodChannel('starxpand')
    ..setMethodCallHandler((call) => _handler(call));

  static final Map<String, StarXpandCallbackHandler> _callbackHandlers = {};

  static _handler(MethodCall call) {
    switch (call.method) {
      case "callback":
        _callback(Map<String, dynamic>.from(call.arguments));
    }
  }

  static _callback(Map<String, dynamic> args) {
    var guid = args["guid"];
    var type = args["type"];
    var handler = _callbackHandlers[guid];

    if (handler != null) {
      var data = args["data"];

      handler.call(type, Map<String, dynamic>.from(data));
    }
  }

  static String _addCallbackHandler(StarXpandCallbackHandler handler) {
    var uuid = const Uuid().v4();
    _callbackHandlers[uuid] = handler;
    return uuid;
  }

  static _removeCallbackHandler(String guid) {
    _callbackHandlers.remove(guid);
  }

  static Future<List<StarXpandPrinter>> findPrinters(
      {List<StarXpandInterface> interfaces = const [
        StarXpandInterface.usb,
        StarXpandInterface.bluetooth,
        StarXpandInterface.bluetoothLE,
        StarXpandInterface.lan
      ],
        int timeout = 3000,
        StarXpandCallback<StarXpandPrinterPayload>? callback}) async {
    var guid = _addCallbackHandler(
        StarXpandCallbackHandler<StarXpandPrinterPayload>(
                (payload) => callback?.call(payload),
                (type, data) =>
                StarXpandPrinterPayload(
                    type, Map<String, dynamic>.from(data))));

    Map<String, dynamic> result =
    Map<String, dynamic>.from(await _channel.invokeMethod('findPrinters', {
      "callback": guid,
      "timeout": timeout,
      "interfaces": interfaces.map((e) => e.name).toList()
    }) as Map);

    _removeCallbackHandler(guid);

    List printers = result["printers"];
    return printers
        .map((e) => StarXpandPrinter.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<bool> openDrawer(StarXpandPrinter printer) =>
      printDocument(
          printer, StarXpandDocument()
        ..addDrawer(StarXpandDocumentDrawer()));

  static Future<String> monitor(StarXpandPrinter printer,
      StarXpandCallback<StarXpandPrinterStatusPayload> callback) async {
    var guid = _addCallbackHandler(
        StarXpandCallbackHandler<StarXpandPrinterStatusPayload>(
                (payload) => callback.call(payload),
                (type, data) =>
                StarXpandPrinterStatusPayload(
                    type, Map<String, dynamic>.from(data))));

    await _channel.invokeMethod('monitor', {
      "printer": printer.toMap(),
      "callback": guid
    });

    return guid;
  }

  static Future<bool> openPrinterConnection(StarXpandPrinter printer) async {
    return await _channel
        .invokeMethod('openConnection', {"printer": printer.toMap()});
  }

  static Future<bool> closePrinterConnection(StarXpandPrinter printer) async {
    return await _channel.invokeMethod('closeConnection', {"printer": printer.toMap()});
  }

  static Future<bool> printRawBytes(StarXpandPrinter printer, Uint8List bytes) async {
    return await _channel.invokeMethod('printRawBytes', {
      'printer': printer.toMap(),
      'bytes': bytes
    });
  }
  
  static Future<bool> printDocument(StarXpandPrinter printer,
      StarXpandDocument document) async {
    return await _channel.invokeMethod('printDocument',
        {"printer": printer.toMap(), "document": document.toMap()});
  }

  static Future<bool> updateDisplay(StarXpandPrinter printer,
      StarXpandDocumentDisplay display) =>
      printDocument(printer, StarXpandDocument()
        ..addDisplay(display));

  static Future<StarXpandStatus> getStatus(StarXpandPrinter printer) async {
    var result = Map<String, dynamic>.from(
        await _channel.invokeMethod('getStatus', {"printer": printer.toMap()}));
    return StarXpandStatus.fromMap(result.cast<String, dynamic>());
  }

  static Future<String> startInputListener(StarXpandPrinter printer,
      StarXpandCallback<StarXpandInputPayload> callback) async {
    var guid = _addCallbackHandler(
        StarXpandCallbackHandler<StarXpandInputPayload>(
                (payload) => callback.call(payload),
                (type, data) =>
                StarXpandInputPayload(type, Map<String, dynamic>.from(data))));

    await _channel.invokeMethod(
        'startInputListener', {"callback": guid, "printer": printer.toMap()});

    return guid;
  }

  static Future stopInputListener(StarXpandPrinter printer, String guid) async {
    await _channel.invokeMethod(
        'stopInputListener', {"callback": guid, "printer": printer.toMap()});

    _removeCallbackHandler(guid);
  }
}
