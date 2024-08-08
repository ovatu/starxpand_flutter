enum StarXpandInterface {
  unknown,
  usb,
  bluetooth,
  bluetoothLE,
  lan;

  static StarXpandInterface fromName(String name) =>
      StarXpandInterface.values.where((e) => e.name == name).first;
}

enum StarXpandPrinterPaper {
  mm58('58mm', 385), // 385
  mm76('76mm', 530), // 530
  mm80('80mm', 567), // 567
  mm112('112mm', 1093);

  final String label;
  final int width;

  const StarXpandPrinterPaper(this.label, this.width);
}

enum StarXpandPrinterModel {
  tsp650II('TSP 650 II', [StarXpandPrinterPaper.mm80]),
  tsp700II('TSP 600 II', [StarXpandPrinterPaper.mm80]),
  tsp800II('TSP 800 II', [StarXpandPrinterPaper.mm80]),
  tsp100IIUPlus('TSP 100 II U+', [StarXpandPrinterPaper.mm80]),
  tsp100IIIW('TSP 100 III W', [StarXpandPrinterPaper.mm80]),
  tsp100IIILAN('TSP 100 III LAN', [StarXpandPrinterPaper.mm80]),
  tsp100IIIBI('TSP 100 III BI', [StarXpandPrinterPaper.mm80]),
  tsp100IIIU('TSP 100 III U', [StarXpandPrinterPaper.mm80]),
  tsp100IV('TSP 800II', [StarXpandPrinterPaper.mm80]),
  mPOP('mPOP', [StarXpandPrinterPaper.mm58]),
  mCPrint2('mC-Print2', [StarXpandPrinterPaper.mm58]),
  mCPrint3('mC-Print3', [StarXpandPrinterPaper.mm80]),
  smS210i('SM-S210i', [StarXpandPrinterPaper.mm58]),
  smS230i('SM-S230i', [StarXpandPrinterPaper.mm58]),
  smT300('SM-T300', [StarXpandPrinterPaper.mm80]),
  smT300i('SM-T300i', [StarXpandPrinterPaper.mm80]),
  smT400i('SM-T400i', [StarXpandPrinterPaper.mm112]),
  smL200('SM-L200', [StarXpandPrinterPaper.mm58]),
  smL300('SM-L300', [StarXpandPrinterPaper.mm58]),
  sp700('SP-700', [StarXpandPrinterPaper.mm76]),
  unknown('Unknown', []);

  final String label;
  final List<StarXpandPrinterPaper> paper;

  const StarXpandPrinterModel(this.label, this.paper);

  static StarXpandPrinterModel fromName(String name) {
    try {
      return StarXpandPrinterModel.values
          .where((e) => e.name.toLowerCase() == name.toLowerCase())
          .first;
    } catch (e) {
      return StarXpandPrinterModel.unknown;
    }
  }
}

class StarXpandPrinter {
  /// Build response using map recieved from native platform
  StarXpandPrinter.fromMap(Map<String, dynamic> response)
      : model = StarXpandPrinterModel.fromName(response['model']),
        identifier = response['identifier'],
        interface = StarXpandInterface.fromName(response['interface']);

  // Name of the called method
  StarXpandPrinterModel model;
  String identifier;
  StarXpandInterface interface;

  /// Render a string repesentation of the response
  @override
  String toString() {
    return 'model: $model, identifier: $identifier, interface: $interface';
  }

  Map<String, dynamic> toMap() {
    return {
      'model': model.name,
      'identifier': identifier,
      'interface': interface.name,
    };
  }
}
