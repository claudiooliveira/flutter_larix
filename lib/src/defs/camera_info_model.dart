class CameraInfoModel {
  double minimumFocusDistance;
  bool isTorchSupported;
  double maxZoom;
  bool isZoomSupported;
  int maxExposure;
  int minExposure;
  int lensFacing;
  String cameraId;

  CameraInfoModel({
    required this.minimumFocusDistance,
    required this.isTorchSupported,
    required this.maxZoom,
    required this.isZoomSupported,
    required this.maxExposure,
    required this.minExposure,
    required this.lensFacing,
    required this.cameraId,
  });

  factory CameraInfoModel.fromHashMap(value) => CameraInfoModel(
        minimumFocusDistance: value["minimumFocusDistance"],
        isTorchSupported: value["isTorchSupported"],
        maxZoom: value["maxZoom"],
        isZoomSupported: value["isZoomSupported"],
        maxExposure: value["maxExposure"],
        minExposure: value["minExposure"],
        lensFacing: value["lensFacing"],
        cameraId: value["cameraId"],
      );
}
