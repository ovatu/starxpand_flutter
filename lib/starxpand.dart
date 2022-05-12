import 'dart:async';

import 'package:starxpand/models/starxpand_document_drawer.dart';
import 'package:uuid/uuid.dart';

import 'package:flutter/services.dart';
import 'package:starxpand/models/starxpand_document.dart';
import 'package:starxpand/models/starxpand_printer.dart';

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

  static String _addCallbackHandler(StarXpandCallbackHandler handler) {
    var uuid = Uuid().v4();
    _callbackHandlers[uuid] = handler;
    return uuid;
  }

  static _removeCallbackHandler(String guid) {
    _callbackHandlers.remove(guid);
  }

  static Future<List<StarXpandPrinter>> findPrinters(
      {StarXpandCallback<StarXpandPrinterPayload>? callback}) async {
    var guid = _addCallbackHandler(
        StarXpandCallbackHandler<StarXpandPrinterPayload>(
            (payload) => callback?.call(payload),
            (type, data) => StarXpandPrinterPayload(
                type, Map<String, dynamic>.from(data))));

    Map<String, dynamic> result = Map<String, dynamic>.from(
        await _channel.invokeMethod('findPrinters', {"callback": guid}) as Map);

    _removeCallbackHandler(guid);

    List printers = result["printers"];
    return printers
        .map((e) => StarXpandPrinter.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<bool> openDrawer(StarXpandPrinter printer) => printDocument(
      printer, StarXpandDocument().addDrawer(StarXpandDocumentDrawer()));

  static Future<bool> printDocument(
      StarXpandPrinter printer, StarXpandDocument document) async {
    return await _channel.invokeMethod('printDocument',
        {"printer": printer.toMap(), "document": document.toMap()});
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
    await _channel
        .invokeMethod('stopInputListener', {"printer": printer.toMap()});

    _removeCallbackHandler(guid);
  }
}

typedef StarXpandCallback<T extends StarXpandCallbackPayload> = void Function(
    T payload);

class StarXpandCallbackHandler<T extends StarXpandCallbackPayload> {
  final T Function(String type, Map<String, dynamic> data)? payloadBuilder;
  final StarXpandCallback<T> callback;

  StarXpandCallbackHandler(this.callback, this.payloadBuilder);

  @override
  String toString() {
    return "StarXpandCallbackHandler payloadBuilder: $payloadBuilder, callback: $callback";
  }

  call(String type, Map<String, dynamic> data) {
    var payload = payloadBuilder?.call(type, data) ??
        StarXpandCallbackPayload(type, data) as T;
    callback(payload);
  }
}

class StarXpandCallbackPayload {
  late final String type;
  late final Map<String, dynamic> data;

  StarXpandCallbackPayload(this.type, Map<String, dynamic> payload) {
    data = payload;
    fromMap(data);
  }

  fromMap(Map<String, dynamic> data) {}
}

class StarXpandPrinterPayload extends StarXpandCallbackPayload {
  late final StarXpandPrinter printer;

  StarXpandPrinterPayload(String type, Map<String, dynamic> payload)
      : super(type, payload);

  @override
  fromMap(Map<String, dynamic> data) {
    printer = StarXpandPrinter.fromMap(data);
  }

  @override
  String toString() {
    return "StarXpandPrinterPayload: printer: $printer";
  }
}

class StarXpandInputPayload extends StarXpandCallbackPayload {
  late final String input;

  StarXpandInputPayload(String type, Map<String, dynamic> payload)
      : super(type, payload);

  @override
  fromMap(Map<String, dynamic> data) {
    input = data["data"];
  }
}
