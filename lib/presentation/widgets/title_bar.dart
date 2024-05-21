import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../core/logging.dart';

final _log = Logger('TitleBar');

class TitleBar extends StatefulWidget implements PreferredSizeWidget {
  final void Function()? leadingOnPressed;
  final void Function()? endingOnPressed;
  final Widget leadingIcon;
  final Widget endingIcon;
  final ValueNotifier<String> titleNotifier;
  final Widget? bottom;
  final double titleHeight;
  final double titleFontSizeFactor;
  final double bottomHeight;
  final double titleMargin;
  final double dividerHeight;
  final void Function(String path)? onTitleTapped;

  const TitleBar(
      {super.key,
      required this.titleNotifier,
      this.leadingOnPressed,
      this.endingOnPressed,
      this.leadingIcon = const Icon(Icons.settings),
      this.endingIcon = const Icon(Icons.edit),
      this.bottom,
      this.titleHeight = 35,
      this.titleFontSizeFactor = 0.5,
      double bottomHeight = 40,
      this.titleMargin = 2,
      this.dividerHeight = 1,
      this.onTitleTapped})
      : bottomHeight = bottom == null ? 0 : bottomHeight;

  @override
  Size get preferredSize {
    return Size.fromHeight(
        titleHeight + bottomHeight + (titleMargin * 2) + dividerHeight);
  }

  @override
  State<TitleBar> createState() => _TitleBarState();
}

class _TitleBarState extends State<TitleBar> {
  late ScrollController _scrollController;
  Timer? _scrollTimer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener); // ←追加
  }

  @override
  void dispose() {
    super.dispose();
    _scrollController.dispose();
  }

  void _scrollTimerCallback() {
    if (_scrollTimer != null) {
      _scrollTimer = null;
    }

    if (!_scrollController.hasClients) return;

    _scrollController.animateTo(_scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 2000), curve: Curves.easeInOut);
  }

  void _scrollListener() {
    _resetScrollPosition(false);
  }

  void _resetScrollPosition(bool now) {
    int time = 5000;
    if (now) {
      time = 1;
    }
    _scrollTimer?.cancel();
    _scrollTimer = Timer(Duration(milliseconds: time), _scrollTimerCallback);
  }

  @override
  Widget build(context) {
    final statusBarHeight = MediaQuery.of(context).viewPadding.top;
    final buttonHeight = widget.titleHeight;
    final buttonWidth = buttonHeight * 1.3;
    final Color backgroundColor = Theme.of(context).canvasColor;
    final titleEdge =
        widget.titleHeight * (1.0 - widget.titleFontSizeFactor) / 2;

    final leading = MaterialButton(
      // color: backgroundColor,
      padding: EdgeInsets.zero,
      onPressed: widget.leadingOnPressed,
      child: widget.leadingIcon,
    );
    final ending = MaterialButton(
      padding: EdgeInsets.zero,
      onPressed: widget.endingOnPressed,
      child: widget.endingIcon,
    );

    // _dumpPositions(statusBarHeight, buttonWidth, buttonHeight);

    List<Widget> bottomWidgets;
    if (widget.bottom == null) {
      bottomWidgets = [];
    } else {
      bottomWidgets = [
        SizedBox(height: widget.bottomHeight, child: widget.bottom),
      ];
    }

    return Column(
      children: [
            SizedBox(
              height: statusBarHeight,
            ),
            Expanded(
              child: Container(
                padding: EdgeInsets.all(widget.titleMargin),
                child: Stack(
                  children: [
                    Center(
                      child: ListView(
                        controller: _scrollController,
                        shrinkWrap: true,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          SizedBox(
                            width: buttonWidth,
                          ),
                          ValueListenableBuilder<String>(
                              valueListenable: widget.titleNotifier,
                              builder: (context, title, _) {
                                final textStyle = TextStyle(
                                    fontSize: widget.titleHeight *
                                        widget.titleFontSizeFactor,
                                    // fontSize: 20,
                                    height: 1);
                                final parts = split(title);
                                List<Widget> buttons = [];
                                String path = "/";
                                for (var i = 0; i < parts.length; i++) {
                                  final p = parts[i];
                                  String newPath = path;
                                  if (i > 0) {
                                    newPath = join(path, p);
                                    path = newPath;
                                    buttons.add(Text(
                                      "/",
                                      style: textStyle,
                                    ));
                                  }
                                  buttons.add(MaterialButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.only(
                                        top: titleEdge,
                                        bottom: titleEdge,
                                        left: 10,
                                        right: 10),
                                    minWidth: 5,
                                    // style: ButtonStyle(
                                    //   // padding: MaterialStateProperty.all(EdgeInsets.zero),
                                    //   minimumSize:
                                    //       MaterialStateProperty.all(Size.zero),
                                    //   tapTargetSize:
                                    //       MaterialTapTargetSize.shrinkWrap,
                                    // ),
                                    onPressed: () {
                                      _log.info("Path button:$newPath clicked");
                                      widget.onTitleTapped?.call(newPath);
                                    },
                                    child: Text(
                                      p,
                                      style: textStyle,
                                    ),
                                  ));
                                }
                                _resetScrollPosition(true);
                                return Row(children: buttons);
                              }),
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
                                  backgroundColor,
                                  backgroundColor.withOpacity(.2),
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
                                  backgroundColor.withOpacity(.2),
                                  backgroundColor,
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
            Divider(
              height: widget.dividerHeight,
              thickness: widget.dividerHeight,
            ),
          ] +
          bottomWidgets,
    );
  }
}
