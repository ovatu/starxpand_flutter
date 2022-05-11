import 'package:starxpand/models/starxpand_document.dart';
import 'package:starxpand/starxpand.dart';

enum StarXpandDocumentDrawerChannel { no1, no2 }

class StarXpandDocumentDrawer extends StarXpandDocumentContent {
  final StarXpandDocumentDrawerChannel channel;

  StarXpandDocumentDrawer({this.channel = StarXpandDocumentDrawerChannel.no1});

  @override
  String get type => 'drawer';

  @override
  Map getData() {
    return {"channel": channel.name};
  }
}
