import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:starxpand/models/starxpand_printer.dart';
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
    var ps = await StarXpand.find();
    setState(() {
      printers = ps;
    });
    print(ps);
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
                  onTap: () => StarXpand.openDrawer(p),
                  title: Text(p.model),
                  subtitle: Text(p.identifier),
                  trailing: Text(p.interface.name))
        ]),
      ),
    );
  }
}
