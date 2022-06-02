// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:collection';

import 'package:flutter/services.dart';
import 'package:flutter_larix/src/defs/permissions.dart';
import 'package:flutter_larix/src/defs/stream_changed.dart';
import 'package:flutter_larix/src/flutter_larix_controller_options.dart';

enum STREAM_STATUS { ON, OFF }

class FlutterLarixController {
  late MethodChannel _channel;

  STREAM_STATUS _streamStatus = STREAM_STATUS.OFF;
  bool _muteStatus = false;
  String _connectionState = "";
  bool _torchIsOn = false;

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

  Future<String> initCamera() async {
    return await _channel.invokeMethod('initCamera');
  }

  Future<void> disposeCamera() async {
    await _channel.invokeMethod('disposeCamera');
  }

  Future<Map<String, String>> requestPermissions() async {
    return await _channel.invokeMethod('requestPermissions');
  }

  Future<Permissions> getPermissions() async {
    return Permissions.fromJson(
      HashMap.from(
        await _channel.invokeMethod('getPermissions'),
      ),
    );
  }

  Future<void> startStream() async {
    await _channel.invokeMethod('startStream', options.toJson());
  }

  Future<void> stopStream() async {
    await _channel.invokeMethod('stopStream');
  }

  Future<bool> startAudioCapture() async {
    var mute = await _channel.invokeMethod('startAudioCapture');
    updateAudioStatusCapture(mute);
    return _muteStatus;
  }

  Future<bool> stopAudioCapture() async {
    var mute = await _channel.invokeMethod('stopAudioCapture');
    updateAudioStatusCapture(mute);
    return _muteStatus;
  }

  updateAudioStatusCapture(audio) {
    _muteStatus = audio['mute'] == true;
  }

  bool getMicrophoneStatus() {
    return _muteStatus;
  }

  Future<void> startVideoCapture() async {
    await _channel.invokeMethod('startVideoCapture');
  }

  Future<void> stopVideoCapture() async {
    await _channel.invokeMethod('stopVideoCapture');
  }

  Future<void> setDisplayRotation() async {
    await _channel.invokeMethod('setDisplayRotation');
  }

  Future<void> setFlip() async {
    await _channel.invokeMethod('flip');
  }

  Future<void> toggleTorch() async {
    var result = await _channel.invokeMethod('toggleTorch');
    _torchIsOn = result == "true";
  }

  STREAM_STATUS getStreamStatus() {
    return _streamStatus;
  }

  String getConnectionState() {
    return _connectionState;
  }

  bool getTorchIsOn() {
    return _torchIsOn;
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
