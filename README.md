# flutter_larix

In this Flutter package you can broadcast using RTMP, SRT, RTSP, RIST protocols based on [Larix Broadcaster SDK](https://softvelum.com/larix/), package includes platform implementation code for Android and/or iOS.

## Getting Started

**First steps to start the package**

Add package import in your pubspec.yaml

```
dependencies:
  flutter_larix:
   git:
      url: https://github.com/claudiooliveira/flutter_larix.git
      ref:  main
```

Adding Larix SDK import inside android/app in build.gradle

```
dependencies {
    implementation files('libs/libstream-release.aar')
    implementation files('libs/libudpsender-release.aar')
}
```

Add in your AndroidManifest.xml

```
    <uses-feature android:name="android.hardware.camera.any" />
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.READ_PHONE_STATE" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
```

In your widget you need to make a call to FlutterLarix passing in the property the method that will start along with the widget

```
FlutterLarix(
    cameraResolution: CAMERA_RESOLUTION.HD,
    cameraType: CAMERA_TYPE.BACK, // camera default
    url: "rtmp://teste.com:1935/origin/AAAAA-bbb-cccc-dddd-111111111111", // 
    onCameraViewCreated: onCameraViewCreated,
    listener: _flutterLarixListener,
),
```

Getting FlutterLarixController instance and requesting camera permission and starting

```
 void onCameraViewCreated(FlutterLarixController controller) async {
    setState(() {
      this.controller = controller;
      initialCamera();
    });
  }
  ```
```
  initialCamera() async {
    var requestPermissions = await controller!.getPermissions();
    if (requestPermissions.hasAudioPermission && requestPermissions.hasCameraPermission) {
      var cameraStatus = await controller!.initCamera();
      print("response ${cameraStatus}");
    } else {
      var permissionsResult = await controller!.requestPermissions();
      if (permissionsResult.hasCameraPermission) {
        var cameraStatus = await controller!.initCamera();
        print("response ${cameraStatus}");
      }
    }
  }
  ```
  ```
  void _flutterLarixListener() {
    if (mounted) {
      setState(() {});
    }
  }
  ```
  
**If you have any questions, you can refer to the [example](https://github.com/claudiooliveira/flutter_larix/tree/test/example/lib).**
