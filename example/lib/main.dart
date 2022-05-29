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
  bool microfone = true;
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
          //constraints: const BoxConstraints(maxHeight: 100),
          color: Colors.blueAccent,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return FlutterLarix(
                cameraWidth: constraints.maxWidth.toInt(),
                cameraHeight: constraints.maxHeight.toInt(),
                cameraType: CAMERA_TYPE.BACK,
                rtmpUrl:
                    "rtmp://origin-v2.vewbie.com:1935/origin/2b866520-11c5-4818-9d2a-6cfdebbb8c8a",
                onCameraViewCreated: onCameraViewCreated,
                listener: _flutterLarixListener,
              );
            },
          ),
        ),
        if (controller != null)
          Align(
              alignment: Alignment.bottomCenter,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    child: this.microfone
                        ? Icon(Icons.mic_rounded)
                        : Icon(Icons.mic_off_sharp),
                    onTap: () async {
                      if (!this.microfone) {
                        await controller!.startAudioCapture();
                        this.microfone = true;
                      } else {
                        await controller!.stopAudioCapture();
                        this.microfone = false;
                      }
                      setState(() {});
                    },
                  ),
                  LarixRecordButton(
                    controller: controller!,
                  ),
                  GestureDetector(
                    child: Icon(Icons.flip_camera_ios_rounded),
                    onTap: () async {
                      await controller!.setDisplayRotation();
                      // print("camera");
                      // bool microfone = true;
                      // bool camera = true;
                      // int cameraSelected = 0;
                      // await controller!.startVideoCapture();
                      //
                      // await controller!.stopVideoCapture();
                      setState(() {});
                    },
                  ),
                  GestureDetector(
                    child: this.flash
                        ? Icon(Icons.flash_off)
                        : Icon(Icons.flash_on),
                    onTap: () async {
                      // if (this.flash) {
                      //   await controller!.startAudioCapture();
                      //   this.flash = true;
                      // } else {
                      // await controller!.stopAudioCapture();
                      // this.flash = false;
                      // }
                      // setState(() {
                      //
                      // });
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
