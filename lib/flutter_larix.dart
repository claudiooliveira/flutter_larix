// ignore_for_file: constant_identifier_names
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_larix/src/flutter_larix_controller.dart';
import 'package:flutter_larix/src/flutter_larix_controller_options.dart';

export 'package:flutter_larix/src/flutter_larix_controller.dart';

typedef FlutterLarixCameraViewCreatedCallback = void Function(
    FlutterLarixController);

enum CAMERA_TYPE { FRONT, BACK }

enum CAMERA_RESOLUTION { SD, HD, FULLHD }

// ignore: must_be_immutable
class FlutterLarix extends StatefulWidget {
  CAMERA_RESOLUTION cameraResolution = CAMERA_RESOLUTION.HD;
  CAMERA_TYPE cameraType;
  String url = "";
  final FlutterLarixCameraViewCreatedCallback onCameraViewCreated;
  final Function listener;
  FlutterLarix({
    Key? key,
    required this.cameraResolution,
    required this.url,
    required this.cameraType,
    required this.onCameraViewCreated,
    required this.listener,
  }) : super(key: key);

  @override
  State<FlutterLarix> createState() => _FlutterLarixState();
}

class _FlutterLarixState extends State<FlutterLarix> {
  FlutterLarixController? _controller;

  @override
  Widget build(BuildContext context) {
    const String viewType = 'br.com.devmagic.flutter_larix/nativeview';
    final Map<String, dynamic> creationParams = <String, dynamic>{
      "resolution": widget.cameraResolution.name,
      "type": widget.cameraType.name,
      "url": widget.url,
    };

    return AndroidView(
      viewType: viewType,
      onPlatformViewCreated: _onPlatformViewCreated,
      creationParams: creationParams,
      creationParamsCodec: const StandardMessageCodec(),
    );
  }

  void _onPlatformViewCreated(int id) {
    _controller = FlutterLarixController(
      options: FlutterLarixControllerOptions(
        id: id,
        listener: widget.listener,
        cameraType: widget.cameraType,
        cameraResolution: widget.cameraResolution,
        url: widget.url,
      ),
    );
    widget.onCameraViewCreated(_controller!);
  }
}
