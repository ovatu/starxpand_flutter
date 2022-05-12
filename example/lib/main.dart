import 'package:flutter/material.dart';
import 'dart:async';

import 'package:http/http.dart' as http;

import 'package:flutter/services.dart';
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
        callback: (payload) => print('lib main: $payload'));
    setState(() {
      printers = ps;
    });
    print(ps);
  }

  _openDrawer(StarXpandPrinter printer) {
    StarXpand.openDrawer(printer);
  }

  _startInputListener(StarXpandPrinter printer) {
    StarXpand.startInputListener(
        printer, (p) => print('_startInputListener: ${p.input}'));
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
    printDoc.actionPrintText("""Star Clothing Boutique
123 Star Road
City, State 12345

""");
    printDoc.style(alignment: StarXpandStyleAlignment.left);
    printDoc.actionPrintText("""Date:MM/DD/YYYY    Time:HH:MM PM
--------------------------------
""");

    printDoc.add(StarXpandDocumentPrint()
      ..style(bold: true)
      ..actionPrintText("SALE\n"));

    printDoc.actionPrintText("""SKU         Description    Total
--------------------------------
300678566   PLAIN T-SHIRT  10.99
300692003   BLACK DENIM    29.99
300651148   BLUE DENIM     29.99
300642980   STRIPED DRESS  49.99
300638471   BLACK BOOTS    35.99

Subtotal                  156.95
Tax                         0.00
--------------------------------

""");

    printDoc.actionPrintText("Total     ");

    printDoc.add(StarXpandDocumentPrint()
      ..style(magnification: StarXpandStyleMagnification(2, 2))
      ..actionPrintText("   \$156.95\n"));

    printDoc.actionPrintText("""--------------------------------

Charge
156.95
Visa XXXX-XXXX-XXXX-0123

""");

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
    doc.addDrawer(StarXpandDocumentDrawer());

    StarXpand.printDocument(printer, doc);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Column(children: [
          TextButton(child: Text('FInd'), onPressed: () => _find()),
          if (printers != null)
            for (var p in printers!)
              ListTile(
                  onTap: () => _print(p),
                  title: Text(p.model),
                  subtitle: Text(p.identifier),
                  trailing: Text(p.interface.name))
        ]),
      ),
    );
  }
}
