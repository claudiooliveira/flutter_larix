import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_larix/flutter_larix.dart';
import 'package:flutter_larix/src/flutter_larix_controller.dart';
import 'package:flutter_larix/src/flutter_larix_controller_options.dart';
import 'package:flutter_larix_example/pages/stream.dart';

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  FlutterLarixController controller = FlutterLarixController(
      options: FlutterLarixControllerOptions(
    id: 1,
    listener: () {},
    cameraType: CAMERA_TYPE.BACK,
    cameraResolution: CAMERA_RESOLUTION.HD,
    url: "",
  ));
  final Map<String, dynamic> creationParams = <String, dynamic>{};
  @override
  initState() {
    super.initState();
    (() async {
      print("teste versao do bangue ${await controller.initCamera()}");
    })();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Flutter Larix Example ${Platform.isAndroid}"),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            // Center(
            //   child: TextButton(
            //     style: ButtonStyle(
            //       backgroundColor: MaterialStateProperty.all<Color>(
            //           Color.fromARGB(255, 169, 228, 174)),
            //     ),
            //     onPressed: () {
            //       Navigator.push(
            //           context, MaterialPageRoute(builder: (context) => Stream()));
            //     },
            //     child: Text("fazer stream"),
            //   ),
            // ),
            Container(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: UiKitView(
                viewType: 'np-ablo-spanhou',
                layoutDirection: TextDirection.ltr,
                creationParams: creationParams,
                creationParamsCodec: const StandardMessageCodec(),
              ),
            )
          ],
        ),
      ),
    );
  }
}
