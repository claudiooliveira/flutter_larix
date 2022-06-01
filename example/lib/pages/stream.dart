import 'package:flutter/material.dart';
import 'package:flutter_larix/flutter_larix.dart';
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Teste flutter larix"),
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
                Navigator.pop(context);
              },
            ),
          ),
          if (controller != null)
            Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Container(
                    color: Colors.white60,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          child: controller!.getMicrophoneStatus()
                              ? const Icon(Icons.mic_off_sharp)
                              : const Icon(Icons.mic_rounded),
                          onTap: () async {
                            if (controller!.getMicrophoneStatus()) {
                              await controller!.startAudioCapture();
                            } else {
                              await controller!.stopAudioCapture();
                            }
                            setState(() {});
                          },
                        ),
                        RecordButton(
                          controller: controller!,
                        ),
                        GestureDetector(
                          child: const Icon(Icons.flip_camera_ios_rounded),
                          onTap: () async {
                            await controller!.setFlip();
                            setState(() {});
                          },
                        ),
                        GestureDetector(
                          child: controller?.getTorchIsOn() == false
                              ? const Icon(Icons.flash_off)
                              : const Icon(Icons.flash_on),
                          onTap: () async {
                            await controller!.toggleTorch();
                            setState(() {});
                          },
                        ),
                        // GestureDetector(
                        //   child: Icon(Icons.keyboard_arrow_right),
                        //   onTap: () async {
                        //     await controller!.startStream();
                        //     setState(() {});
                        //   },
                        // ),
                        // GestureDetector(
                        //   child: Icon(Icons.close_rounded),
                        //   onTap: () async {
                        //     await controller!.stopStream();
                        //     setState(() {});
                        //   },
                        // )
                      ],
                    ),
                  ),
                ))
        ],
      ),
    );
  }

  void onCameraViewCreated(FlutterLarixController controller) async {
    setState(() {
      this.controller = controller;
    });
  }
}
