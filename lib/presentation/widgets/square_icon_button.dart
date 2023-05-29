import 'package:flutter/material.dart';

import '../../core/logging.dart';

final log = Logger('SquareIconButton');

class SquareIconButton extends StatelessWidget {
  final EdgeInsets padding;
  final Widget child;
  final Widget? label;
  final double? minWidth;
  final void Function()? onPressed;

  const SquareIconButton({
    Key? key,
    this.onPressed,
    required this.child,
    this.label,
    this.minWidth = 50,
    this.padding = const EdgeInsets.all(3),
  }) : super(key: key);
  @override
  Widget build(context) {
    return SizedBox(
      width: minWidth,
      //Wrap with column for shrink the InkWell's width
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
              customBorder: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              onTap: () {
                onPressed?.call();
              },
              child: Ink(
                padding: padding,
                decoration: BoxDecoration(
                  // color: Colors.purpleAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: child,
              )),
          label ?? Container(),
        ],
      ),
    );
  }
}
