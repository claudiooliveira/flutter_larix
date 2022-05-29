// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:collection';

import 'package:flutter/services.dart';
import 'package:flutter_larix/src/defs/stream_changed.dart';
import 'package:flutter_larix/src/flutter_larix_controller_options.dart';

enum STREAM_STATUS { ON, OFF }

class FlutterLarixController {
  late MethodChannel _channel;

  STREAM_STATUS _streamStatus = STREAM_STATUS.OFF;
  String _connectionState = "";

  FlutterLarixControllerOptions options;

  FlutterLarixController({
    required this.options,
  }) {
    _channel =
        MethodChannel('br.com.devmagic.flutter_larix/nativeview_${options.id}');
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'streamChanged':
          _onStreamChanged(call.arguments);
          break;
      }
      options.listener.call();
    });
  }

  void dispose() {
    stopStream();
  }

  Future<void> startStream() async {
    await _channel.invokeMethod('startStream', options.toJson());
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

  String getConnectionState() {
    return _connectionState;
  }

  void _onStreamChanged(dynamic arguments) {
    var streamChanged = StreamChanged.fromJson(HashMap.from(arguments));
    _connectionState = streamChanged.connectionState;
    if (_connectionState == "DISCONNECTED") {
      _streamStatus = STREAM_STATUS.OFF;
    } else {
      _streamStatus = STREAM_STATUS.ON;
    }
  }
}
