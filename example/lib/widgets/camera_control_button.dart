import 'package:flutter/material.dart';

class CameraControlButton extends StatelessWidget {
  final Widget icon;
  final Function onTap;
  const CameraControlButton({
    Key? key,
    required this.icon,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      child: SizedBox(
        width: 36,
        height: 36,
        child: icon,
      ),
      onTap: () => onTap.call(),
    );
  }
}
