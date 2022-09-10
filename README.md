# StarXpand SDK for Flutter

[![pub package](https://img.shields.io/pub/v/starxpand.svg)](https://pub.dev/packages/starxpand) [![likes](https://badges.bar/starxpand/likes)](https://pub.dev/packages/starxpand/score) [![popularity](https://badges.bar/starxpand/popularity)](https://pub.dev/packages/starxpand/score)  [![pub points](https://badges.bar/starxpand/pub%20points)](https://pub.dev/packages/starxpand/score)

A StarXpand wrapper to use Star Micronics printers.

With this plugin, your app can easily print to Star printers on Android and iOS.

## Prerequisites

1) Deployment Target iOS 12.0 or higher.
2) Android minSdkVersion 21 or higher.

## iOS

Add reader protocol to info.plist (https://github.com/star-micronics/StarXpand-SDK-iOS) if required

```
<key>UISupportedExternalAccessoryProtocols</key>
<array>
    <string>jp.star-m.starpro</string>
</array>
```

Add elements to info.plist (https://github.com/star-micronics/StarXpand-SDK-iOS)

```
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Our app uses bluetooth to find, connect and print to Star printers.</string>

<key>NSBluetoothPeripheralUsageDescription</key>
<string>Our app uses bluetooth to find, connect and print to Star printers.</string>

<key>NSLocalNetworkUsageDescription</key>
<string>Our app uses LAN to find, connect and print to Star printers.</string>
```

## Installing

Add starxpand to your pubspec.yaml:

```yaml
dependencies:
  starxpand:
```

Import starxpand:

```dart
import 'package:starxpand/starxpand.dart';
```

## Getting Started

Find printers:

```dart
var printers = await StarXpand.findPrinters();
setState(() {
    _printers = printers;
});
```

Print:

```dart
var doc = StarXpandDocument();
var printDoc = StarXpandDocumentPrint();

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

doc.addPrint(printDoc);
doc.addDrawer(StarXpandDocumentDrawer());

StarXpand.printDocument(printer, doc);
```

## Available APIs

```dart
StarXpand.findPrinters(interfaces, timeout, callback);

StarXpand.openDrawer(printer);
StarXpand.printDocument(printer, document);
StarXpand.startInputListener(printer);
StarXpand.stopInputListener(printer, guid);
```
