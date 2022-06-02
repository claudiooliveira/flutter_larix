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
    var per = await controller!.getPermissions();
    if (per.hasAudioPermission && per.hasCameraPermission) {
      var teste = await controller!.initCamera();
      print("teste oq veio na camera ${teste}");
    } else {
      print("vai perguntar algo ? ");
      var teste = await controller!.requestPermissions();
      print("oque ele respondeu das permissões ${teste}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Teste flutter larix"),
      ),
      body: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: Container(
              width: double.infinity,
              // constraints: const BoxConstraints(maxHeight: 300),
              color: Colors.blueAccent,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return FlutterLarix(
                    cameraWidth: constraints.maxWidth.toInt(),
                    cameraHeight: constraints.maxHeight.toInt(),
                    cameraType: CAMERA_TYPE.BACK,
                    rtmpUrl:
                        "rtmp://origin-v2.vewbie.com:1935/origin/9143dd3b-6f9a-4696-97cb-43c4f78fa43f",
                    onCameraViewCreated: onCameraViewCreated,
                    listener: _flutterLarixListener,
                  );
                },
              ),
            ),
          ),
          Align(
            alignment: Alignment.topRight,
            child: GestureDetector(
              child: Icon(Icons.back_hand_rounded, color: Colors.red[50]),
              onTap: () {
                controller!.requestPermissions();
                // Navigator.pop(context);
              },
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
                                    await controller!.setFlip();
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
                ))
        ],
      ),
    );
  }
}
