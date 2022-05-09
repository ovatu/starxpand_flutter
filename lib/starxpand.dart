import 'dart:async';

import 'package:flutter/services.dart';

class Starxpand {
  static const MethodChannel _channel = MethodChannel('starxpand');

  static Future<void> find() async {
    await _channel.invokeMethod('find');
  }
}
