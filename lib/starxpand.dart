import 'dart:async';

import 'package:uuid/uuid.dart';

import 'package:flutter/services.dart';
import 'package:starxpand/models/starxpand_callbacks.dart';
import 'package:starxpand/models/starxpand_document.dart';
import 'package:starxpand/models/starxpand_printer.dart';
import 'package:starxpand/models/starxpand_document_drawer.dart';

export 'package:starxpand/models/starxpand_callbacks.dart';
export 'package:starxpand/models/starxpand_printer.dart';
export 'package:starxpand/models/starxpand_document.dart';
export 'package:starxpand/models/starxpand_document_print.dart';
export 'package:starxpand/models/starxpand_document_drawer.dart';

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

  static String _addCallbackHandler(
    StarXpandCallbackHandler handler, {
    /// override guid
    String? guid,
  }) {
    String uuid;
    if (guid == null) {
      uuid = const Uuid().v4();
    } else {
      uuid = guid;
    }
    _callbackHandlers[uuid] = handler;
    return uuid;
  }

  static _removeCallbackHandler(String guid) {
    _callbackHandlers.removeWhere((key, value) => key.startsWith(guid));
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
            (type, data) => StarXpandPrinterPayload(
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

  static Future<bool> openDrawer(StarXpandPrinter printer) => printDocument(
      printer, StarXpandDocument()..addDrawer(StarXpandDocumentDrawer()));

  static Future<bool> printDocument(
      StarXpandPrinter printer, StarXpandDocument document) async {
    return await _channel.invokeMethod('printDocument',
        {"printer": printer.toMap(), "document": document.toMap()});
  }

  static Future<String> startInputListener(
    StarXpandPrinter printer,
    StarXpandCallback<StarXpandInputPayload> scannerCallback, {
    StarXpandCallback<StarXpandInputErrorPayload>? scannerErrorCallback,
    StarXpandCallback<StarXpandInputConnected>? scannerConnectedCallback,
    StarXpandCallback<StarXpandInputDisconnected>? scannerDisconnectedCallback,
  }) async {
    var guid = _addCallbackHandler(
      StarXpandCallbackHandler<StarXpandInputPayload>(
        (payload) => scannerCallback.call(payload),
        (type, data) => StarXpandInputPayload(
          type,
          Map<String, dynamic>.from(data),
        ),
      ),
    );

    if (scannerErrorCallback != null) {
      var guidScannerError = _addCallbackHandler(
        StarXpandCallbackHandler<StarXpandInputErrorPayload>(
          (payload) => scannerErrorCallback.call(payload),
          (type, data) => StarXpandInputErrorPayload(
            type,
            Map<String, dynamic>.from(data),
          ),
        ),
        guid: guid + "_error",
      );
    }

    if (scannerConnectedCallback != null) {
      var guidConnected = _addCallbackHandler(
        StarXpandCallbackHandler<StarXpandInputConnected>(
          (payload) => null,
          (type, data) => StarXpandInputConnected(),
        ),
        guid: guid + "_connected",
      );
    }

    if (scannerDisconnectedCallback != null) {
      var guidDisconnected = _addCallbackHandler(
        StarXpandCallbackHandler<StarXpandInputDisconnected>(
          (payload) => null,
          (type, data) => StarXpandInputDisconnected(),
        ),
        guid: guid + "_disconnected",
      );
    }

    await _channel.invokeMethod(
      'startInputListener',
      {
        "callback": guid,
        "printer": printer.toMap(),
      },
    );

    return guid;
  }

  static Future stopInputListener(StarXpandPrinter printer, String guid) async {
    await _channel.invokeMethod(
        'stopInputListener', {"callback": guid, "printer": printer.toMap()});

    _removeCallbackHandler(guid);
  }
}
