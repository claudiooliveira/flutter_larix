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
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 32),
            child: SizedBox(
              height: 28,
              child: ElevatedButton(
                child: Text(
                  "Trocar câmera",
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
                onPressed: () {
                  if (controller != null) {
                    controller?.flipCamera();
                  }
                },
              ).activeButton(
                context,
                style: ButtonStyle(
                  elevation: MaterialStateProperty.all<double>(0.0),
                ),
              ),
            ),
          ),
        )
      ],
    );
  }

  void onCameraViewCreated(FlutterLarixController controller) async {
    print("onCameraViewCreated!!!!!!!!");
    setState(() {
      this.controller = controller;
    });

    await controller.init();
    // controller.scannedDataStream.listen((results) {
    //   setState(() {
    //     _barcodeResults = getBarcodeResults(results);
    //   });
    // });
  }
}
