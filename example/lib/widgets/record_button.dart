import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_larix/flutter_larix.dart';

class RecordButton extends StatefulWidget {
  final FlutterLarixController controller;

  const RecordButton({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton>
    with SingleTickerProviderStateMixin {
  late double _scale;
  bool _pulse = true;
  Timer? _timer;

  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 1200,
      ),
      lowerBound: 0.0,
      upperBound: 0.15,
    )..addListener(() {
        setState(() {});
      });
  }

  bool get isStreaming =>
      widget.controller.getStreamStatus() == STREAM_STATUS.ON;

  void _onTapStartStream() {
    //Start stream
    if (!isStreaming) {
      _animStart();
      widget.controller.startStream();
    } else {
      //Close stream
      _animStop();
      widget.controller.stopStream();
    }
  }

  void _animStart() {
    _animController.forward();
    _timer ??= Timer.periodic(const Duration(milliseconds: 1200), (timer) {
      if (_pulse) {
        _animController.reverse();
      } else {
        _animController.forward();
      }
      _pulse = !_pulse;
    });
  }

  void _animStop() {
    if (_pulse) {
      _animController.reverse();
    }
    _timer?.cancel();
    _timer = null;
  }

  @override
  Widget build(BuildContext context) {
    _scale = 1 + _animController.value;
    return GestureDetector(
      onTap: _onTapStartStream,
      child: Transform.scale(
        scale: _scale,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100.0),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x80000000),
                  blurRadius: 12.0,
                  offset: Offset(0.0, 5.0),
                ),
              ],
              color: isStreaming ? Colors.red : Colors.white,
            ),
            child: SizedBox(
              width: 64,
              height: 64,
              child: Center(
                child: isStreaming
                    ? const Text(
                        "LIVE ON",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
