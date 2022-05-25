
import 'dart:async';

import 'package:flutter/services.dart';

class FlutterLarix {
  static const MethodChannel _channel = MethodChannel('flutter_larix');

  static Future<String?> get platformVersion async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
