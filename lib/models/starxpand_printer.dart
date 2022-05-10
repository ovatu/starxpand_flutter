enum StarXpandInterface { unknown, usb, bluetooth, bluetoothLE, lan }

extension StarXpandInterfaceIO on StarXpandInterface {
  static StarXpandInterface fromString(String value) {
    switch (value) {
      case "usb":
        return StarXpandInterface.usb;
      case "bluetooth":
        return StarXpandInterface.bluetooth;
      case "bluetoothLE":
        return StarXpandInterface.bluetoothLE;
      case "lan":
        return StarXpandInterface.lan;
    }

    return StarXpandInterface.unknown;
  }

  String get value {
    switch (this) {
      case StarXpandInterface.unknown:
        return "unknown";
      case StarXpandInterface.usb:
        return "usb";
      case StarXpandInterface.bluetooth:
        return "bluetooth";
      case StarXpandInterface.bluetoothLE:
        return "bluetoothLE";
      case StarXpandInterface.lan:
        return "lan";
    }
  }
}

class StarXpandPrinter {
  /// Build response using map recieved from native platform
  StarXpandPrinter.fromMap(Map<dynamic, dynamic> response)
      : model = response['model'],
        identifier = response['identifier'],
        interface = StarXpandInterfaceIO.fromString(response['interface']);

  // Name of the called method
  String model;
  String identifier;
  StarXpandInterface interface;

  /// Render a string repesentation of the response
  @override
  String toString() {
    return 'model: $model, identifier: $identifier, interface: $interface';
  }

  Map toMap() {
    return {
      'model': model,
      'identifier': identifier,
      'interface': interface.value
    };
  }
}
