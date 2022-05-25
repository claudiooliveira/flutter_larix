import 'package:flutter/material.dart';

extension CButton on ElevatedButton {
  ElevatedButton defaultButton(BuildContext context, {ButtonStyle? style}) {
    ButtonStyle defStyle = ButtonStyle(
      shape: MaterialStateProperty.all<RoundedRectangleBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
      ),
      backgroundColor: MaterialStateProperty.all<Color>(
        Theme.of(context).inputDecorationTheme.fillColor!,
      ),
    );
    return ElevatedButton(
      onPressed: onPressed,
      child: child,
      style: (this.style ?? defStyle).merge(style ?? defStyle),
    );
  }

  ElevatedButton whiteButton(BuildContext context, {ButtonStyle? style}) {
    ButtonStyle defStyle = ButtonStyle(
      shape: MaterialStateProperty.all<RoundedRectangleBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
      ),
      backgroundColor: MaterialStateProperty.all<Color>(Colors.white),
    );
    return ElevatedButton(
      onPressed: onPressed,
      child: child,
      style: (this.style ?? defStyle).merge(style ?? defStyle),
    );
  }

  ElevatedButton activeButton(BuildContext context, {ButtonStyle? style}) {
    ButtonStyle defStyle = ButtonStyle(
      shape: MaterialStateProperty.all<RoundedRectangleBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
      ),
      backgroundColor: MaterialStateProperty.all<Color>(
        Theme.of(context).colorScheme.secondary,
      ),
    );
    return ElevatedButton(
      onPressed: onPressed,
      child: child,
      style: (this.style ?? defStyle).merge(style ?? defStyle),
    );
  }

  ElevatedButton twitchButton(BuildContext context, {ButtonStyle? style}) {
    ButtonStyle defStyle = ButtonStyle(
      shape: MaterialStateProperty.all<RoundedRectangleBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
      ),
      backgroundColor: MaterialStateProperty.all<Color>(
        Color(0xff9146ff),
      ),
      elevation: MaterialStateProperty.all<double>(3),
    );
    return ElevatedButton(
      onPressed: onPressed,
      child: child,
      style: (this.style ?? defStyle).merge(style ?? defStyle),
    );
  }

  ElevatedButton greyButton(BuildContext context, {ButtonStyle? style}) {
    ButtonStyle defStyle = ButtonStyle(
      shape: MaterialStateProperty.all<RoundedRectangleBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
      ),
      backgroundColor: MaterialStateProperty.all<Color>(
        Colors.black54.withOpacity(0.5),
      ),
    );
    return ElevatedButton(
      onPressed: onPressed,
      child: child,
      style: (this.style ?? defStyle).merge(style ?? defStyle),
    );
  }
}
