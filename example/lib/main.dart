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
        body: Center(
          child: Column(
            children: [
              Text('Running on: $_platformVersion\n'),
              Expanded(
                child: Stack(
                  children: [
                    Expanded(
                      child: TesteAndroid(),
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
                            onPressed: () {},
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TesteAndroid extends StatelessWidget {
  const TesteAndroid({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> creationParams = <String, dynamic>{
      "teste": "MAAAA"
    };
    return Container(
      width: double.infinity,
      //constraints: const BoxConstraints(maxHeight: 100),
      color: Colors.blueAccent,
      child: AndroidView(
        viewType: "NativeView",
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
      ),
    );
  }
}
