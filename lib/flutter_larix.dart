// ignore_for_file: constant_identifier_names
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_larix/src/flutter_larix_controller.dart';
import 'package:flutter_larix/src/flutter_larix_controller_options.dart';

export 'package:flutter_larix/src/flutter_larix_controller.dart';
export 'package:flutter_larix/src/widgets/larix_record_button.dart';

typedef FlutterLarixCameraViewCreatedCallback = void Function(
    FlutterLarixController);

enum CAMERA_TYPE { FRONT, BACK }

// ignore: must_be_immutable
class FlutterLarix extends StatefulWidget {
  int cameraWidth = 0;
  int cameraHeight = 0;
  CAMERA_TYPE cameraType;
  String rtmpUrl = "";
  final FlutterLarixCameraViewCreatedCallback onCameraViewCreated;
  final Function listener;
  FlutterLarix({
    Key? key,
    required this.cameraWidth,
    required this.cameraHeight,
    required this.rtmpUrl,
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
      "width": widget.cameraWidth,
      "height": widget.cameraHeight,
      "type": widget.cameraType.name,
      "url": widget.rtmpUrl,
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
        cameraWidth: widget.cameraWidth,
        cameraHeight: widget.cameraHeight,
        cameraType: widget.cameraType,
        url: widget.rtmpUrl,
      ),
    );
    widget.onCameraViewCreated(_controller!);
  }
}
