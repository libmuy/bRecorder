import 'package:brecorder/core/logging.dart';
import 'package:flutter/material.dart';

final log = Logger('SearchBox');

class SearchBox extends StatefulWidget {
  final double height;
  final double padding;

  const SearchBox({
    Key? key,
    this.height = 35.0,
    this.padding = 4.0,
  }) : super(key: key);

  @override
  State<SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<SearchBox> with TickerProviderStateMixin {
  bool lastShowState = false;
  late final AnimationController _animationController;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // assert(widget.showNotifier != null || widget.show != null);
    // _animationController = AnimationController(
    //   duration: const Duration(milliseconds: 300),
    //   vsync: this,
    // );
    // _animation = Tween<double>(
    //   begin: 0,
    //   end: 1,
    // ).animate(_animationController);
  }

  @override
  void dispose() {
    // _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(context) {
    final fontSize = widget.height * 0.6;
    const borderWidth = 0.5;
    return Container(
      padding: EdgeInsets.only(
          left: widget.padding, top: widget.padding, right: widget.padding),
      alignment: Alignment.center,
      color: Theme.of(context).primaryColor,
      child: Container(
        height: widget.height + (borderWidth * 2),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          border: Border.all(
            color: Theme.of(context).hintColor,
            width: borderWidth,
          ),
          borderRadius: BorderRadius.circular(fontSize * 0.6),
        ),
        child: Stack(clipBehavior: Clip.antiAlias, children: [
          Positioned(
            left: (widget.height - fontSize) / 2,
            bottom: (widget.height - fontSize) / 2,
            child: Icon(
              Icons.search,
              size: fontSize,
            ),
          ),
          Positioned(
            left: widget.height,
            bottom: (widget.height - fontSize) / 2,
            right: (widget.height - fontSize) / 2,
            child: TextFormField(
              // autofocus: true, //TextFieldが表示されるときにフォーカスする（キーボードを表示する）
              cursorColor: Colors.white, //カーソルの色
              style: TextStyle(
                fontWeight: FontWeight.w300,
                color: Colors.white,
                fontSize: fontSize,
                height: 1,
              ),

              textInputAction: TextInputAction.search, //キーボードのアクションボタンを指定
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                // enabledBorder: OutlineInputBorder(),
                hintText: 'Search', //何も入力してないときに表示されるテキスト
                hintStyle: TextStyle(
                  color: Colors.white60,
                  fontSize: fontSize,
                  height: 1,
                ),
              ),
            ),
          )
        ]),
      ),
    );
  }
}
