import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:starxpand/models/starxpand_document_display.dart';
import 'package:starxpand/starxpand.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<StarXpandPrinter>? printers;

  @override
  void initState() {
    super.initState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> _find() async {
    var ps = await StarXpand.findPrinters(
        callback: (payload) => print('printer: $payload'));
    setState(() {
      printers = ps;
    });
  }

  _openDrawer(StarXpandPrinter printer) {
    StarXpand.openDrawer(printer);
  }

  _startInputListener(StarXpandPrinter printer) {
    StarXpand.startInputListener(
        printer, (p) => print('_startInputListener: ${p.inputString}'));
  }

  _print(StarXpandPrinter printer) async {
    var doc = StarXpandDocument();
    var printDoc = StarXpandDocumentPrint();

    http.Response response = await http.get(
      Uri.parse('https://ovatu.com/marketing/images/ovatu/logo-large-navy.png'),
    );

    printDoc.actionPrintImage(response.bodyBytes, 350);

    printDoc.style(
        internationalCharacter: StarXpandStyleInternationalCharacter.usa,
        characterSpace: 0.0,
        alignment: StarXpandStyleAlignment.center);
    printDoc.actionPrintText("Star Clothing Boutique\n"
        "123 Star Road\n"
        "City, State 12345\n");

    printDoc.style(alignment: StarXpandStyleAlignment.left);
    printDoc.actionPrintText("Date:MM/DD/YYYY    Time:HH:MM PM\n"
        "--------------------------------\n");

    printDoc.add(StarXpandDocumentPrint()
      ..style(bold: true)
      ..actionPrintText("SALE\n"));

    printDoc.actionPrintText("SKU         Description    Total\n"
        "--------------------------------\n"
        "300678566   PLAIN T-SHIRT  10.99\n"
        "300692003   BLACK DENIM    29.99\n"
        "300651148   BLUE DENIM     29.99\n"
        "300642980   STRIPED DRESS  49.99\n"
        "300638471   BLACK BOOTS    35.99\n"
        "Subtotal                  156.95\n"
        "Tax                         0.00\n"
        "--------------------------------\n");

    printDoc.actionPrintText("Total     ");

    printDoc.add(StarXpandDocumentPrint()
      ..style(magnification: StarXpandStyleMagnification(2, 2))
      ..actionPrintText("   \$156.95\n"));

    printDoc.actionPrintText("--------------------------------\n"
        "Charge\n"
        "156.95\n"
        "Visa XXXX-XXXX-XXXX-0123\n");

    printDoc.add(StarXpandDocumentPrint()
      ..style(invert: true)
      ..actionPrintText("Refunds and Exchanges\n"));

    printDoc.actionPrintText("Within ");

    printDoc.add(StarXpandDocumentPrint()
      ..style(underLine: true)
      ..actionPrintText("30 days"));

    printDoc.actionPrintText(" with receipt\n");
    printDoc.actionPrintText("And tags attached\n\n");

    printDoc.style(alignment: StarXpandStyleAlignment.center);

    printDoc.actionPrintBarcode("0123456",
        symbology: StarXpandBarcodeSymbology.jan8,
        barDots: 3,
        height: 5,
        printHri: true);

    printDoc.actionFeedLine(1);

    printDoc.actionPrintQRCode("Hello, World\n",
        level: StarXpandQRCodeLevel.l, cellSize: 8);

    printDoc.actionCut(StarXpandCutType.partial);

    doc.addPrint(printDoc);
    StarXpand.printDocument(printer, doc);
  }

  int displayCounterText = 0;

  /**
   * Can also be added to a normal printDocument via
   * doc.addDisplay(StarXpandDocumentDisplay display)
   */
  void _updateDisplayText(StarXpandPrinter printer) {
    var displayDoc = StarXpandDocumentDisplay()
      ..actionClearAll()
      ..actionClearLine()
      ..actionShowText("StarXpand\n")
      ..actionClearLine()
      ..actionShowText("Updated ${++displayCounterText} times");

    StarXpand.updateDisplay(printer, displayDoc);
  }

  void _getStatus(StarXpandPrinter printer) async {
    try {
      var status = await StarXpand.getStatus(printer);
      print("Got status ${status.toString()}");
    } catch (e) {
      print(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('StarXpand SDK - Example app'),
        ),
        body: Column(children: [
          TextButton(
              child: Text('Search for devices'), onPressed: () => _find()),
          if (printers != null)
            for (var p in printers!)
              ListTile(
                  onTap: () => _print(p),
                  title: Text(p.model.label + "(${p.interface.name})"),
                  subtitle: Text(p.identifier),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                          onPressed: () => _print(p), child: Text("Print")),
                      Container(width: 4),
                      OutlinedButton(
                          onPressed: () => _openDrawer(p),
                          child: Text("Open drawer")),
                      Container(width: 4),
                      OutlinedButton(
                          onPressed: () => _updateDisplayText(p),
                          child: Text("Update display")),
                      Container(width: 4),
                      OutlinedButton(
                          onPressed: () => _getStatus(p),
                          child: Text("Get Status")),
                    ],
                  ))
        ]),
      ),
    );
  }
}
