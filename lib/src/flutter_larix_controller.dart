// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:collection';

import 'package:flutter/services.dart';
import 'package:flutter_larix/src/defs/connectionStatistics.dart';
import 'package:flutter_larix/src/defs/connectionStatisticsFormated.dart';
import 'package:flutter_larix/src/defs/connection_status.dart';
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
        MethodChannel('br.com.devmagic.flutter_larix/nativeview_controller');
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'streamChanged':
          _onStreamChanged(call.arguments);
          break;
        case 'connectionStatistics':
          connectionStatistics(call.arguments);
          return;
        case 'connectionStatus':
          _connectionStatus(call.arguments);
          return;
      }
      options.listener.call();
    });
  }

  Future<String> initCamera(int bitRate) async {
    return await _channel.invokeMethod('initCamera', bitRate);
  }

  Future<void> disposeCamera() async {
    await _channel.invokeMethod('disposeCamera');
  }

  Future<Permissions> requestPermissions() async {
    var result = await _channel.invokeMethod('requestPermissions');
    return Permissions.fromJson(HashMap.from(result));
  }

  Future<Permissions> getPermissions() async {
    return Permissions.fromJson(
      HashMap.from(
        await _channel.invokeMethod('getPermissions'),
      ),
    );
  }

  Future<int?> startStream() async {
    int streamId = await _channel.invokeMethod('startStream', options.toJson());
    if (streamId > 0) {
      return streamId;
    } else {
      await Future.delayed(const Duration(milliseconds: 1500), () {});
      return await startStream();
    }
  }

  Future<void> stopRecord() async {
    await _channel.invokeMethod('stopRecord');
  }

  Future<String> startRecord(String fileName) async {
    String filePath = await _channel.invokeMethod('startRecord', fileName);
    return filePath;
  }

  Future<bool> isRecording() async {
    bool isRecording = await _channel.invokeMethod('isRecording');
    return isRecording;
  }

  Future<void> setBitRate(int bitrate) async {
    await _channel.invokeMethod('setBitRate', bitrate);
  }

  Future<int> getBitRate() async {
    return await _channel.invokeMethod('getBitRate');
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

  Future<void> setDisplayRotation(int value) async {
    await _channel.invokeMethod('setDisplayRotation', value);
  }

  Future<void> reconnect() async {
    await _channel.invokeMethod('reconnect');
  }

  Future<bool> getRotatePermission() async {
    bool permission = await _channel.invokeMethod('getRotatePermission');
    return permission;
  }

  Future<void> flipCamera() async {
    await _channel.invokeMethod('flipCamera');
  }

  Future<double> setZoom(double zoom, bool isManual) async {
    double zoomResult =
        await _channel.invokeMethod('setZoom', <String, dynamic>{
      'zoom': zoom,
      'isManual': isManual,
    });
    return zoomResult;
  }

  Future<double> getZoomMax() async {
    double zoomResult = await _channel.invokeMethod('getZoomMax');
    return zoomResult;
  }

  Future<void> setAutoFocus(bool autoFocus) async {
    await _channel.invokeMethod('setAutoFocus', autoFocus);
  }

  Future<void> startAutomaticBitRate(int bitrate) async {
    await _channel.invokeMethod('startAutomaticBitRate', bitrate);
  }

  Future<void> stopAutomaticBitRate() async {
    await _channel.invokeMethod('stopAutomaticBitRate');
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

  StreamController<ConnectionStatisticsFormatedModel>
      connectionStatisticsStream =
      StreamController<ConnectionStatisticsFormatedModel>();

  StreamController<ConnectionStatusModel> connectionStatusStream =
      StreamController<ConnectionStatusModel>();

  void connectionStatistics(arguments) {
    ConnectionStatisticsModel streamChanged =
        ConnectionStatisticsModel.fromJson(
      HashMap.from(arguments),
    );
    connectionStatisticsStream.add(
      ConnectionStatisticsFormatedModel(
        bandwidth: bandwidthToString(streamChanged.bandwidth),
        traffic: trafficToString(streamChanged.traffic),
      ),
    );
  }

  void _connectionStatus(arguments) {
    ConnectionStatusModel streamChanged = ConnectionStatusModel.fromJson(
      HashMap.from(arguments),
    );
    connectionStatusStream.add(streamChanged);
  }

  String bandwidthToString(int bps) {
    if (bps < 1000) {
      // bps
      return "${bps.toStringAsPrecision(2)}bps";
    } else if (bps < 1000 * 1000) {
      // Kbps
      return "${(bps / 1000).toStringAsPrecision(2)}Kbps";
    } else if (bps < 1000 * 1000 * 1000) {
      // Mbps
      return "${(bps / (1000 * 1000)).toStringAsPrecision(2)}Mbps";
    } else {
      // Gbps
      return "${(bps / (1000 * 1000 * 1000)).toStringAsPrecision(2)}Gbps";
    }
  }

  String trafficToString(int bytes) {
    if (bytes < 1024) {
      // B
      return "${bytes}B";
    } else if (bytes < 1024 * 1024) {
      // KB
      return "${(bytes / 1024).toStringAsPrecision(2)}KB";
    } else if (bytes < 1024 * 1024 * 1024) {
      // MB
      return "${(bytes / (1024 * 1024)).toStringAsPrecision(2)}MB";
    } else {
      // GB
      return "${(bytes / (1024 * 1024 * 1024)).toStringAsPrecision(2)}GB";
    }
  }
}
