import 'package:flutter/material.dart';

import 'package:flutter_larix/flutter_larix.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Column(
          children: const [
            Expanded(
              child: TesteAndroid(),
            ),
          ],
        ),
      ),
    );
  }
}

class TesteAndroid extends StatefulWidget {
  const TesteAndroid({Key? key}) : super(key: key);

  @override
  State<TesteAndroid> createState() => _TesteAndroidState();
}

class _TesteAndroidState extends State<TesteAndroid> {
  FlutterLarixController? controller;
  bool isMute = false;
  bool camera = true;
  bool flash = false;
  int cameraSelected = 0;

  bool get isStreaming => controller?.getStreamStatus() == STREAM_STATUS.ON;

  void _flutterLarixListener() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 600),
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
        if (controller != null)
          Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      child: this.isMute
                          ? Icon(Icons.mic_off_sharp)
                          : Icon(Icons.mic_rounded),
                      onTap: () async {
                        if (isMute) {
                          this.isMute = await controller!.startAudioCapture();
                        } else if (!this.isMute) {
                          this.isMute = await controller!.stopAudioCapture();
                        }
                        setState(() {});
                      },
                    ),
                    LarixRecordButton(
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
              ))
      ],
    );
  }

  void onCameraViewCreated(FlutterLarixController controller) async {
    setState(() {
      this.controller = controller;
    });
  }
}
