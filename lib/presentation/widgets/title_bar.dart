import 'package:brecorder/core/logging.dart';
import 'package:flutter/material.dart';

final log = Logger('TitleBar');

class TitleBar extends StatelessWidget implements PreferredSizeWidget {
  final void Function()? leadingOnPressed;
  final void Function()? endingOnPressed;
  final Icon leadingIcon;
  final Icon endingIcon;
  final Widget title;
  final Widget bottom;
  final double titleHeight;
  final double bottomHeight;
  final double titleMargin;

  const TitleBar(
      {Key? key,
      this.leadingOnPressed,
      this.endingOnPressed,
      this.leadingIcon = const Icon(Icons.settings),
      this.endingIcon = const Icon(Icons.edit),
      this.title = const Text("title"),
      this.bottom = const Text(""),
      this.titleHeight = 35,
      this.bottomHeight = 35,
      this.titleMargin = 2})
      : super(key: key);

  @override
  Size get preferredSize {
    return Size.fromHeight(titleHeight + bottomHeight + (titleMargin * 2));
  }

  // void _dumpPositions(
  //     double statusBarHeight, double buttonWidth, double buttonHeight) {
  //   String str = "status bar height:$statusBarHeight";
  //   str += " button width:$buttonWidth";
  //   str += " button height:$buttonHeight";
  //   str += " bottom height:$bottomHeight";
  //   str += " preferredSize:$preferredSize";
  //   log.debug(str);
  // }

  @override
  Widget build(context) {
    final leading = MaterialButton(
      padding: EdgeInsets.zero,
      onPressed: leadingOnPressed,
      child: leadingIcon,
    );
    final ending = MaterialButton(
      padding: EdgeInsets.zero,
      onPressed: endingOnPressed,
      child: endingIcon,
    );
    final statusBarHeight = MediaQuery.of(context).viewPadding.top;
    final buttonHeight = titleHeight;
    final buttonWidth = buttonHeight * 1.3;
    final Color backgroundColor = Theme.of(context).canvasColor;

    // _dumpPositions(statusBarHeight, buttonWidth, buttonHeight);

    return Column(
      children: [
        SizedBox(
          height: statusBarHeight,
        ),
        Expanded(
          child: Container(
            padding: EdgeInsets.all(titleMargin),
            child: Stack(
              children: [
                Center(
                  child: ListView(
                    shrinkWrap: true,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      SizedBox(
                        width: buttonWidth,
                      ),
                      Container(
                        padding: EdgeInsets.only(
                            top: buttonHeight * 0.2,
                            bottom: buttonHeight * 0.2),
                        child: FittedBox(fit: BoxFit.fitHeight, child: title),
                      ),
                      SizedBox(
                        width: buttonWidth,
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: const Alignment(-1, 0),
                  child: ShaderMask(
                      blendMode: BlendMode.dstATop,
                      shaderCallback: (rect) => LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.white,
                              Colors.white.withOpacity(.2),
                              Colors.transparent
                            ],
                            stops: const [.8, .9, 1.0],
                          ).createShader(rect),
                      child: Container(
                          width: buttonWidth,
                          alignment: Alignment.centerLeft,
                          color: backgroundColor,
                          child: Padding(
                            padding: EdgeInsets.only(
                                right: buttonWidth - buttonHeight),
                            child: leading,
                          ))),
                ),
                Align(
                  alignment: const Alignment(1, 0),
                  child: ShaderMask(
                      blendMode: BlendMode.dstATop,
                      shaderCallback: (rect) => LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.transparent,
                              Colors.white.withOpacity(.2),
                              Colors.white,
                            ],
                            stops: const [0.0, .1, .2],
                          ).createShader(rect),
                      child: Container(
                          width: buttonWidth,
                          alignment: Alignment.centerLeft,
                          color: backgroundColor,
                          child: Padding(
                            padding: EdgeInsets.only(
                                left: buttonWidth - buttonHeight),
                            child: ending,
                          ))),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: bottomHeight, child: bottom),
      ],
    );
  }
}