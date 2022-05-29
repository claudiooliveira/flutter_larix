import 'package:flutter_larix/flutter_larix.dart';

class FlutterLarixControllerOptions {
  final int id;
  final Function listener;
  final int cameraWidth;
  final int cameraHeight;
  final CAMERA_TYPE cameraType;
  final String url;
  const FlutterLarixControllerOptions({
    required this.id,
    required this.listener,
    required this.cameraWidth,
    required this.cameraHeight,
    required this.url,
    required this.cameraType,
  });

  Map<String, dynamic> toJson() => {
        "cameraId": cameraType == CAMERA_TYPE.FRONT ? 1 : 0,
        "cameraWidth": cameraWidth,
        "cameraHeight": cameraHeight,
        "url": url,
      };
}
