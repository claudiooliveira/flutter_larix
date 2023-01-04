import 'package:flutter/material.dart';
import 'package:flutter_larix/flutter_larix.dart';
import 'package:flutter_larix/src/defs/camera_info_model.dart';
import 'package:flutter_larix_example/widgets/camera_control_button.dart';
import 'package:flutter_larix_example/widgets/record_button.dart';

class Stream extends StatefulWidget {
  const Stream({Key? key}) : super(key: key);

  @override
  State<Stream> createState() => _StreamState();
}

class _StreamState extends State<Stream> with SingleTickerProviderStateMixin {
  FlutterLarixController? controller;
  late Animation<double> animation;
  late AnimationController animationController;
  late CameraInfoModel currentCamera;
  late List<CameraInfoModel> cameraInfo;
  bool openDialog = false;
  double _currentSliderValue = 0;
  bool autoFocus = true;
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
    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    animation = Tween<double>(begin: 0, end: 66).animate(animationController)
      ..addListener(() {
        setState(() {
          // The state that has changed here is the animation object’s value.
        });
      });
    openDialog = false;
    _currentSliderValue = 0;
    autoFocus = true;
    animationController.reverse();
  }

  @override
  dispose() {
    controller?.disposeCamera();
    animationController.dispose();
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
    if (permissionsCamera.hasAudioPermission &&
        permissionsCamera.hasCameraPermission) {
      await controller!.initCamera(2000000);
      cameraInfo = await controller!.getCameraInfo();
      currentCamera =
          cameraInfo.firstWhere((element) => element.cameraId == "0");
    } else {
      var requestPermossions = await controller!.requestPermissions();
      if (requestPermossions.hasCameraPermission) {
        await controller!.initCamera(2000000);
        cameraInfo = await controller!.getCameraInfo();
        currentCamera =
            cameraInfo.firstWhere((element) => element.cameraId == "0");
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
                          height: 92,
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
                                height: 76,
                                child: Column(
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CameraControlButton(
                                          icon:
                                              controller!.getMicrophoneStatus()
                                                  ? const Icon(
                                                      Icons.mic_off_sharp,
                                                      color: Colors.white,
                                                    )
                                                  : const Icon(
                                                      Icons.mic_rounded,
                                                      color: Colors.white,
                                                    ),
                                          onTap: () async {
                                            if (controller!
                                                .getMicrophoneStatus()) {
                                              await controller!
                                                  .startAudioCapture();
                                            } else {
                                              await controller!
                                                  .stopAudioCapture();
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
                                            currentCamera = cameraInfo
                                                .firstWhere((element) =>
                                                    element.cameraId !=
                                                    currentCamera.cameraId);
                                            if (currentCamera
                                                    .minimumFocusDistance ==
                                                0) {
                                              animationController.reverse();
                                              _currentSliderValue = 0.0;
                                              autoFocus = true;
                                            }
                                            setState(() {});
                                          },
                                        ),
                                        const SizedBox(width: 64, height: 64),
                                        CameraControlButton(
                                          icon: const Icon(
                                            Icons.settings,
                                            color: Colors.white,
                                          ),
                                          onTap: () => setState(() {
                                            openDialog = !openDialog;
                                          }),
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
                                  ],
                                ),
                              ),
                              Positioned(
                                top: 0,
                                left: 84,
                                child: RecordButton(
                                  controller: controller!,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                if (openDialog)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        bottom: 120,
                      ),
                      child: Container(
                        width: MediaQuery.of(context).size.width - 40,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: const BorderRadius.all(
                            Radius.circular(16),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedOpacity(
                              opacity: autoFocus ? 0 : 1,
                              duration: const Duration(milliseconds: 500),
                              child: Container(
                                height: animation.value,
                                child: Column(
                                  children: [
                                    const SizedBox(height: 18),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.filter_center_focus_outlined,
                                            size: 24,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            "Manual focus",
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyText2
                                                ?.copyWith(
                                                  color: Colors.white,
                                                ),
                                          ),
                                          const Spacer(),
                                          Slider(
                                              min: 0.0,
                                              max: currentCamera
                                                  .minimumFocusDistance,
                                              value: _currentSliderValue,
                                              onChanged: (_value) {
                                                setState(() {
                                                  _currentSliderValue = _value;
                                                  controller!.setFocus(
                                                    autoFocus,
                                                    _currentSliderValue,
                                                  );
                                                });
                                              }),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),
                            if (currentCamera.minimumFocusDistance != 0) ...[
                              const SizedBox(height: 18),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.filter_center_focus_outlined,
                                      size: 24,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      "autofocus",
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyText2
                                          ?.copyWith(
                                            color: Colors.white,
                                          ),
                                    ),
                                    const Spacer(),
                                    Switch(
                                      value: autoFocus,
                                      activeColor: Colors.green,
                                      onChanged: (value) async {
                                        setState(() {
                                          _currentSliderValue = 0;
                                          if (currentCamera
                                                  .minimumFocusDistance !=
                                              0) {
                                            if (!autoFocus) {
                                              animationController.reverse();
                                            } else {
                                              animationController.forward();
                                            }
                                          }
                                          controller!.setFocus(
                                              !autoFocus, _currentSliderValue);
                                          autoFocus = !autoFocus;
                                        });
                                      },
                                    )
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Row(
                                children: [
                                  controller?.getTorchIsOn() == true
                                      ? const Icon(
                                          Icons.flash_off,
                                          color: Colors.white,
                                        )
                                      : const Icon(
                                          Icons.flash_on,
                                          color: Colors.white,
                                        ),
                                  const SizedBox(width: 12),
                                  Text(
                                    "Flash",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyText2
                                        ?.copyWith(
                                          color: Colors.white,
                                        ),
                                  ),
                                  const Spacer(),
                                  Switch(
                                    value: controller?.getTorchIsOn() == true,
                                    activeColor: Colors.green,
                                    onChanged: (value) async {
                                      await controller!.toggleTorch();
                                      setState(() {});
                                    },
                                  )
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
