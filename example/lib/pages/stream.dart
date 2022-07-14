import 'package:flutter/material.dart';
import 'package:flutter_larix/flutter_larix.dart';
import 'package:flutter_larix_example/widgets/camera_control_button.dart';
import 'package:flutter_larix_example/widgets/record_button.dart';

class Stream extends StatefulWidget {
  const Stream({Key? key}) : super(key: key);

  @override
  State<Stream> createState() => _StreamState();
}

class _StreamState extends State<Stream> {
  FlutterLarixController? controller;
  String broadcastUrl =
      "rtmp://origin-v2.vewbie.com:1935/origin/9143dd3b-6f9a-4696-97cb-43c4f78fa43f";
  bool get isStreaming => controller?.getStreamStatus() == STREAM_STATUS.ON;

  void _flutterLarixListener() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  initState() {
    super.initState();
  }

  @override
  dispose() {
    controller?.disposeCamera();
    super.dispose();
  }

  void onCameraViewCreated(FlutterLarixController controller) async {
    setState(() {
      this.controller = controller;
      initialCamera();
    });
  }

  initialCamera() async {
    var permissionsCamera = await controller!.getPermissions();
    print(" teste oq veio aqui ${permissionsCamera}");
    if (permissionsCamera.hasAudioPermission &&
        permissionsCamera.hasCameraPermission) {
      await controller!.initCamera();
    } else {
      var requestPermossions = await controller!.requestPermissions();
      if (requestPermossions.hasCameraPermission) {
        await controller!.initCamera();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Flutter Larix Example"),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          print(
              "APP EXAMPLE SITE: ${constraints.maxWidth}x${constraints.maxHeight}");
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth,
              maxHeight: constraints.maxHeight,
            ),
            child: Stack(
              children: [
                Container(
                  color: Colors.black,
                  height: constraints.maxHeight,
                  width: constraints.maxWidth + 100,
                  child: FlutterLarix(
                    cameraResolution: CAMERA_RESOLUTION.FULLHD,
                    cameraType: CAMERA_TYPE.BACK,
                    url: broadcastUrl,
                    onCameraViewCreated: onCameraViewCreated,
                    listener: _flutterLarixListener,
                  ),
                ),
                if (controller != null)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 32),
                      child: LayoutBuilder(builder: (context, constraints) {
                        return SizedBox(
                          height: 80,
                          child: Stack(
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 16),
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(100),
                                  ),
                                ),
                                height: 46,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CameraControlButton(
                                      icon: controller!.getMicrophoneStatus()
                                          ? const Icon(
                                              Icons.mic_off_sharp,
                                              color: Colors.white,
                                            )
                                          : const Icon(
                                              Icons.mic_rounded,
                                              color: Colors.white,
                                            ),
                                      onTap: () async {
                                        if (controller!.getMicrophoneStatus()) {
                                          await controller!.startAudioCapture();
                                        } else {
                                          await controller!.stopAudioCapture();
                                        }
                                        setState(() {});
                                      },
                                    ),
                                    CameraControlButton(
                                      icon: const Icon(
                                        Icons.flip_camera_ios_rounded,
                                        color: Colors.white,
                                      ),
                                      onTap: () async {
                                        await controller!.flipCamera();
                                        setState(() {});
                                      },
                                    ),
                                    const SizedBox(width: 64, height: 64),
                                    CameraControlButton(
                                      icon: controller?.getTorchIsOn() == false
                                          ? const Icon(
                                              Icons.flash_off,
                                              color: Colors.white,
                                            )
                                          : const Icon(
                                              Icons.flash_on,
                                              color: Colors.white,
                                            ),
                                      onTap: () async {
                                        await controller!.toggleTorch();
                                        setState(() {});
                                      },
                                    ),
                                    CameraControlButton(
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                      ),
                                      onTap: () {
                                        Navigator.pop(context);
                                      },
                                    )
                                  ],
                                ),
                              ),
                              Positioned(
                                top: 0,
                                left: 84,
                                child: RecordButton(
                                  controller: controller!,
                                ),
                              )
                            ],
                          ),
                        );
                      }),
                    ),
                  )
              ],
            ),
          );
        },
      ),
    );
  }
}
