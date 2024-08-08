import 'dart:typed_data';

import 'starxpand_printer.dart';

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

enum StarXpandPrinterStatusUpdateType {
  connected,
  disconnected,
  error;

  static StarXpandPrinterStatusUpdateType fromName(String name) =>
    StarXpandPrinterStatusUpdateType.values.where((e) => e.name == name).first;
}

class StarXpandPrinterStatusPayload extends StarXpandCallbackPayload {
  late final StarXpandPrinterStatusUpdateType updateType;
  late final String message;

  StarXpandPrinterStatusPayload(String type, Map<String, dynamic> payload)
    : super(type, payload);

  @override
  fromMap(Map<String, dynamic> data) {
    updateType = StarXpandPrinterStatusUpdateType.fromName(data['updateType']);
    message = data['message'];
  }


  @override
  String toString() {
    return "StarXpandStatusPayload: type($updateType) message($message)";
  }
}

class StarXpandInputPayload extends StarXpandCallbackPayload {
  late final String inputString;
  late final Uint8List inputData;

  StarXpandInputPayload(String type, Map<String, dynamic> payload)
      : super(type, payload);

  @override
  fromMap(Map<String, dynamic> data) {
    inputString = data["string"];
    inputData = data["data"];
  }
}
