import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_larix/flutter_larix.dart';
import 'package:flutter_larix_example/buttons.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    // String platformVersion;
    // // Platform messages may fail, so we use a try/catch PlatformException.
    // // We also handle the message potentially returning null.
    // try {
    //   platformVersion =
    //       await FlutterLarix.platformVersion ?? 'Unknown platform version';
    // } on PlatformException {
    //   platformVersion = 'Failed to get platform version.';
    // }

    // // If the widget was removed from the tree while the asynchronous platform
    // // message was in flight, we want to discard the reply rather than calling
    // // setState to update our non-existent appearance.
    // if (!mounted) return;

    // setState(() {
    //   _platformVersion = platformVersion;
    // });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        backgroundColor: Colors.amber,
        body: Column(
          children: [
            Text('Running on: $_platformVersion\n'),
            const Expanded(
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
    print("MUDOU CARAI");
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
          child: FlutterLarix(
            cameraWidth: 1280,
            cameraHeight: 720,
            cameraType: CAMERA_TYPE.BACK,
            rtmpUrl:
                "rtmp://origin-v2.vewbie.com:1935/origin/2b866520-11c5-4818-9d2a-6cfdebbb8c8a",
            onCameraViewCreated: onCameraViewCreated,
            listener: _flutterLarixListener,
          ),
        ),
        Align(
            alignment: Alignment.bottomCenter,
            child: Row(
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
                GestureDetector(
                  child: isStreaming
                      ? const Icon(Icons.no_photography)
                      : const Icon(Icons.photo_camera),
                  onTap: () async {
                    if (!isStreaming) {
                      await controller!.startStream();
                    } else {
                      await controller!.stopStream();
                    }
                  },
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
                  child:
                      this.flash ? Icon(Icons.flash_off) : Icon(Icons.flash_on),
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

    // await controller.init();
    // controller.scannedDataStream.listen((results) {
    //   setState(() {
    //     _barcodeResults = getBarcodeResults(results);
    //   });
    // });
  }
}
