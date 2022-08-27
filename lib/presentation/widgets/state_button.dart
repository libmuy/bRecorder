import 'package:flutter/material.dart';
import 'package:brecorder/core/logging.dart';

final log = Logger('StateButton');

class StateButton extends StatefulWidget {
  final Widget state1Widget;
  final Widget? state2Widget;
  final bool reverseColor;
  final void Function()? onPressed;
  final double? height;

  const StateButton(
      {Key? key,
      required this.state1Widget,
      this.state2Widget,
      this.reverseColor = false,
      this.onPressed,
      this.height})
      : super(key: key);

  @override
  State<StateButton> createState() => _StateButtonState();
}

class _StateButtonState extends State<StateButton> {
  bool state = false;

  // @override
  // void initState() {
  //   super.initState();
  // }

  @override
  Widget build(BuildContext context) {
    return MaterialButton(
      height: widget.height,
      onPressed: () {
        if (widget.state2Widget != null) {
          setState(() {
            state = !state;
          });
        }
        if (widget.onPressed != null) {
          widget.onPressed!();
        }
      },
      child: state ? widget.state2Widget : widget.state1Widget,
    );
  }
}
