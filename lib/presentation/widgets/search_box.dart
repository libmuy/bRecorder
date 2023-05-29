import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/logging.dart';
import '../../core/utils/notifiers.dart';

final log = Logger('SearchBox');

class SearchBox extends StatefulWidget {
  final double height;
  final double padding;
  final void Function(String text)? onTextChanged;
  final SimpleNotifier? cancelNotifier;

  const SearchBox({
    Key? key,
    this.height = 35.0,
    this.padding = 4.0,
    this.onTextChanged,
    this.cancelNotifier,
  }) : super(key: key);

  @override
  State<SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<SearchBox> with TickerProviderStateMixin {
  bool lastShowState = false;
  String _text = "";
  late final AnimationController _clearAnimationController;
  late final AnimationController _cancelAnimationController;
  late final Animation<double> _clearAnimation;
  late final Animation<double> _cancelAnimation;
  late final TextEditingController _textEditingController;
  final _focusNode = FocusNode();
  final _cancelTxtKey = GlobalKey();
  Size? _cancelTextSize;
  late final _fontSize = widget.height * 0.6;

  @override
  void initState() {
    super.initState();

    _focusNode.addListener(() => _onFocusChange(_focusNode.hasFocus));

    // assert(widget.showNotifier != null || widget.show != null);
    _clearAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _cancelAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _cancelAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(_cancelAnimationController);
    _clearAnimation = CurvedAnimation(
      parent: _clearAnimationController,
      curve: Curves.easeIn,
    );
    _textEditingController = TextEditingController();
    widget.cancelNotifier?.addListener(_cancelSearch);
  }

  @override
  void dispose() {
    _clearAnimationController.dispose();
    _cancelAnimationController.dispose();
    _textEditingController.dispose();
    super.dispose();
  }

  void _onFocusChange(bool hasFocus) {
    if (hasFocus) {
      _cancelAnimationController.forward();
    } else {
      _cancelAnimationController.reverse();
    }
  }

  void _onTextChanged(String newText) {
    if (_text == newText) return;
    _text = newText;
    if (_text.isNotEmpty) {
      _clearAnimationController.forward();
    } else {
      _clearAnimationController.reverse();
    }
    widget.onTextChanged?.call(newText);
  }

  void _clearInput() {
    _textEditingController.clear();
    _onTextChanged("");
  }

  void _cancelSearch() {
    _clearInput();
    _focusNode.unfocus();
  }

  Widget _buildCancelText() {
    final cancelTxt = Text(
      key: _cancelTxtKey,
      "Cancel",
      style: TextStyle(
        fontWeight: FontWeight.w300,
        color: Colors.white,
        fontSize: _fontSize,
        height: 1,
      ),
    );
    if (_cancelTextSize == null) {
      SchedulerBinding.instance.addPostFrameCallback(
        (_) {
          final box =
              _cancelTxtKey.currentContext?.findRenderObject() as RenderBox?;
          setState(() {
            _cancelTextSize = box?.size;
          });
        },
      );
      return cancelTxt;
    }

    return GestureDetector(
      onTap: () {
        _focusNode.unfocus();
      },
      child: SizeTransition(
        axis: Axis.horizontal,
        sizeFactor: _cancelAnimation,
        child: SizedBox(
          height: double.infinity,
          width: _cancelTextSize!.width + widget.padding,
          child: Stack(
            // alignment: Alignment.bottomCenter,
            // // height: widget.height + widget.padding + (borderWidth * 2),
            // height: double.infinity,
            // // color: Colors.red,
            // padding: EdgeInsets.only(
            //     right: widget.padding, bottom: widget.padding * 3),
            children: [
              Positioned(
                right: widget.padding,
                bottom: (widget.height - _fontSize) / 2 + widget.padding,
                child: cancelTxt,
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(context) {
    final cancelButtonFontSize = widget.height * 0.4;
    const borderWidth = 0.5;
    final boderRadius = _fontSize * 0.6;
    final cancelButtonBoderRadius = cancelButtonFontSize * 0.6;

    return Container(
      color: Theme.of(context).primaryColor,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  _focusNode.requestFocus();
                },
                child: Container(
                  // color: Colors.green,
                  // padding: EdgeInsets.only(
                  //   left: widget.padding,
                  //   right: widget.padding,
                  // ),
                  padding: EdgeInsets.all(widget.padding),
                  child: Container(
                    height: widget.height + (borderWidth * 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      border: Border.all(
                        color: Theme.of(context).hintColor,
                        width: borderWidth,
                      ),
                      borderRadius: BorderRadius.circular(boderRadius),
                    ),
                    child: Stack(clipBehavior: Clip.antiAlias, children: [
                      Positioned(
                        left: (widget.height - _fontSize) / 2,
                        bottom: (widget.height - _fontSize) / 2,
                        child: Icon(
                          Icons.search,
                          size: _fontSize,
                        ),
                      ),
                      Positioned(
                        left: widget.height,
                        bottom: (widget.height - _fontSize) / 2,
                        right: (widget.height - _fontSize) / 2,
                        child: TextFormField(
                          onChanged: _onTextChanged,
                          controller: _textEditingController,
                          focusNode: _focusNode,
                          // autofocus: true, //TextFieldが表示されるときにフォーカスする（キーボードを表示する）
                          cursorColor: Colors.white, //カーソルの色
                          style: TextStyle(
                            fontWeight: FontWeight.w300,
                            color: Colors.white,
                            fontSize: _fontSize,
                            height: 1,
                          ),

                          textInputAction:
                              TextInputAction.search, //キーボードのアクションボタンを指定
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            // enabledBorder: OutlineInputBorder(),
                            hintText: 'Search', //何も入力してないときに表示されるテキスト
                            hintStyle: TextStyle(
                              color: Colors.white60,
                              fontSize: _fontSize,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                          bottom: (widget.height - cancelButtonFontSize) / 4,
                          right: (widget.height - cancelButtonFontSize) / 4,
                          child: FadeTransition(
                            opacity: _clearAnimation,
                            child: GestureDetector(
                              onTap: _clearInput,
                              child: Material(
                                clipBehavior: Clip.antiAlias,
                                color: Theme.of(context).highlightColor,
                                shadowColor: Colors.black,
                                // surfaceTintColor: Colors.red,
                                borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(
                                        cancelButtonBoderRadius),
                                    topRight: Radius.circular(
                                        cancelButtonBoderRadius),
                                    bottomLeft: Radius.circular(
                                        cancelButtonBoderRadius),
                                    bottomRight: Radius.circular(
                                        cancelButtonBoderRadius)),
                                elevation: 10,
                                child: Container(
                                    alignment: Alignment.center,
                                    padding: EdgeInsets.all(
                                        (widget.height - cancelButtonFontSize) /
                                            4),
                                    child: Icon(
                                      Icons.clear,
                                      size: cancelButtonFontSize,
                                    )),
                              ),
                            ),
                          ))
                    ]),
                  ),
                ),
              ),
            ),
            _buildCancelText(),
          ],
        ),
      ),
    );
  }
}
