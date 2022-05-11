import 'package:starxpand/starxpand.dart';

class StarXpandDocument {
  final List<StarXpandDocumentContent> _contents = [];

  addPrint(StarXpandDocumentPrint print) => _contents.add(print);
  addDrawer(StarXpandDocumentDrawer drawer) => _contents.add(drawer);

  Map toMap() {
    return {"contents": _contents.map((e) => e.toMap()).toList()};
  }
}

abstract class StarXpandDocumentContent {
  String get type;

  Map? getData();

  Map toMap() {
    return {"type": type, "data": getData()};
  }
}
