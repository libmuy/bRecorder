import 'package:flutter/material.dart';
import 'package:brecorder/core/logging.dart';

final log = Logger('StateButton');

class StateButton extends StatelessWidget {
  final Widget trueStateWidget;
  final Widget? falseStateWidget;
  final bool reverseColor;
  final void Function()? onPressed;
  final double? height;
  final bool state;

  const StateButton(
      {Key? key,
      required this.trueStateWidget,
      this.falseStateWidget,
      this.reverseColor = false,
      this.onPressed,
      this.height,
      required this.state})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialButton(
      height: height,
      onPressed: () {
        if (onPressed != null) {
          onPressed!();
        }
      },
      child: state ? falseStateWidget : trueStateWidget,
    );
  }
}
