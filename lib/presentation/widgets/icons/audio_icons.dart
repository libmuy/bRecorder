import 'package:flutter/material.dart';

class OverlayIcon extends StatelessWidget {
  final double? height;
  final IconData bigIcon;
  final IconData smallIcon;
  final Color? color;

  const OverlayIcon({
    Key? key,
    required this.bigIcon,
    required this.smallIcon,
    this.height,
    this.color,
  }) : super(key: key);

  @override
  Widget build(context) {
    return SizedBox(
      height: height ?? 23,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: Icon(
              bigIcon,
              color: color,
            ),
          ),
          Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Theme.of(context).primaryColor, width: 1)),
                child: Icon(
                  smallIcon,
                  color: color,
                  size: 9,
                ),
              )),
        ],
      ),
    );
  }

  static Widget pitchAddIcon({double? height}) => OverlayIcon(
        bigIcon: Icons.graphic_eq,
        smallIcon: Icons.add_circle_rounded,
        height: height,
      );
  static Widget pitchRemoveIcon({double? height}) => OverlayIcon(
        bigIcon: Icons.graphic_eq,
        smallIcon: Icons.remove_circle_rounded,
        height: height,
      );
  static Widget volumeAddIcon({double? height}) => OverlayIcon(
        bigIcon: Icons.volume_up_outlined,
        smallIcon: Icons.add_circle_rounded,
        height: height,
      );
  static Widget volumeRemoveIcon({double? height}) => OverlayIcon(
        bigIcon: Icons.volume_down_outlined,
        smallIcon: Icons.remove_circle_rounded,
        height: height,
      );
  static Widget speedAddIcon({double? height}) => OverlayIcon(
        bigIcon: Icons.fast_forward_outlined,
        smallIcon: Icons.add_circle_rounded,
        height: height,
      );
  static Widget speedRemoveIcon({double? height}) => OverlayIcon(
        bigIcon: Icons.fast_forward_outlined,
        smallIcon: Icons.remove_circle_rounded,
        height: height,
      );
  static Widget timerAddIcon({double? height}) => OverlayIcon(
        bigIcon: Icons.timer,
        smallIcon: Icons.add_circle_rounded,
        height: height,
      );
  static Widget timerRemoveIcon({double? height}) => OverlayIcon(
        bigIcon: Icons.timer,
        smallIcon: Icons.remove_circle_rounded,
        height: height,
      );
}
