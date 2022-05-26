import 'dart:async';

import 'package:flutter/services.dart';

class FlutterLarixController {
  late MethodChannel _channel;
  final StreamController<String> _streamController = StreamController<String>();
  Stream<String> get larixCameraStream => _streamController.stream;
  FlutterLarixController(int id) {
    print("BORA PORRA");
    _channel = MethodChannel('br.com.devmagic.flutter_larix/nativeview_$id');
    _channel.setMethodCallHandler((call) async {
      print("AE LEK DEU BOM ${call.method}");
      switch (call.method) {
        case 'onDetected':
          break;
      }
    });
  }

  void dispose() {
    stopCamera();
    _streamController.close();
  }

  Future<void> stopCamera() async {
    await _channel.invokeMethod('stopCamera');
  }

  Future<void> init() async {
    await _channel.invokeMethod('init');
  }

  Future<void> flipCamera() async {
    await _channel.invokeMethod('flip_camera');
  }
}
