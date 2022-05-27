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
    stopStream();
    _streamController.close();
  }

  Future<void> startStream() async {
    await _channel.invokeMethod('startStream');
  }

  Future<void> stopStream() async {
    await _channel.invokeMethod('stopStream');
  }

  Future<void> startAudioCapture() async {
    await _channel.invokeMethod('startAudioCapture');
  }

  Future<void> stopAudioCapture() async {
    await _channel.invokeMethod('stopAudioCapture');
  }

  Future<void> startVideoCapture() async {
    await _channel.invokeMethod('startVideoCapture');
  }

  Future<void> setDisplayRotation() async {
    await _channel.invokeMethod('setDisplayRotation');
  }

  Future<void> stopVideoCapture() async {
    await _channel.invokeMethod('stopVideoCapture');
  }

  // case "startStream":
  // mStreamerGL.startAudioCapture();
  // mStreamerGL.startVideoCapture();
  // break;
  // case "stopStream":
  // mStreamerGL.stopAudioCapture();
  // mStreamerGL.stopVideoCapture();
  // break;
  // case "flip":
  // mStreamerGL.flip("1", "1");
  // break;
  // case "stopAudioCapture":
  // mStreamerGL.stopAudioCapture();
  // break;
  // case "startAudioCapture":
  // mStreamerGL.startAudioCapture();
  // break;
  // case "changeCameraConfig":
  // mStreamerGL.changeCameraConfig();
  // break;
  // case "setDisplayRotation":
  // mStreamerGL.setDisplayRotation(90);
  // break;
  // case "getActiveCameraId":
  // mStreamerGL.getActiveCameraId();
  // break;
}
