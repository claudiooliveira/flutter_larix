// ignore_for_file: constant_identifier_names

import 'dart:async';

import 'package:flutter/services.dart';

enum STREAM_STATUS { ON, OFF }

class FlutterLarixController {
  late MethodChannel _channel;
  final StreamController<String> _streamController = StreamController<String>();
  Stream<String> get larixCameraStream => _streamController.stream;

  STREAM_STATUS _streamStatus = STREAM_STATUS.OFF;

  final Function listener;

  FlutterLarixController(int id, this.listener) {
    print("BORA PORRA");
    _channel = MethodChannel('br.com.devmagic.flutter_larix/nativeview_$id');
    _channel.setMethodCallHandler((call) async {
      print(
          "AE LEK DEU BOM ${call.method} ${call.arguments} ${call.arguments.runtimeType}");

      //var arguments = Map.from(call.arguments);
      //print("arguments ::::: $arguments");
      switch (call.method) {
        case 'streamChanged':
          _streamStatus = STREAM_STATUS.ON;
          var args = (call.arguments as List<dynamic>);
          if (args.isNotEmpty) {
            print("ARGSSS ${args[0]}");
            //if (call.arguments.length) {
            //print("salve >>>>>>> ${Map.from(call.arguments[0])}");
            _streamStatus = STREAM_STATUS.ON;
            //if (streamStatus)
            //}
          }
          break;
      }
      listener.call();
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

  STREAM_STATUS getStreamStatus() {
    return _streamStatus;
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
