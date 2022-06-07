import 'package:flutter_larix/flutter_larix.dart';

class FlutterLarixControllerOptions {
  final int id;
  final Function listener;
  final CAMERA_TYPE cameraType;
  final CAMERA_RESOLUTION cameraResolution;
  final String url;
  const FlutterLarixControllerOptions({
    required this.id,
    required this.listener,
    required this.cameraResolution,
    required this.url,
    required this.cameraType,
  });

  Map<String, dynamic> toJson() => {
        "cameraId": cameraType == CAMERA_TYPE.FRONT ? 1 : 0,
        "cameraResolution": cameraResolution.name,
        "url": url,
      };
}
