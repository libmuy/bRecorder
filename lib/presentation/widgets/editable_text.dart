import 'package:flutter/material.dart';
import 'package:brecorder/core/logging.dart';

final log = Logger('EditableText');

class EditableText extends StatefulWidget {
  final String initialText;
  final double height;
  final EdgeInsets padding;
  final TextAlign textAlign;

  const EditableText(this.initialText,
      {Key? key,
      this.height = 35,
      this.padding = const EdgeInsets.all(0),
      this.textAlign = TextAlign.start})
      : super(key: key);

  @override
  State<EditableText> createState() => _EditableTextState();
}

class _EditableTextState extends State<EditableText> {
  bool _isEditingText = false;
  late TextEditingController _editingController;
  late String textString;
  late final double fontSize;
  final FocusNode focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    textString = widget.initialText;
    _editingController = TextEditingController(text: textString);
    fontSize = widget.height * 0.8;
    focusNode.addListener(() {
      if (!focusNode.hasFocus) {
        setState(() {
          textString = _editingController.text;
          _isEditingText = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _editingController.dispose();
    super.dispose();
  }

  Widget editableText() {
    return Stack(
      children: [
        Expanded(
          child: Padding(
            padding: widget.padding,
            child: SizedBox(
              height: widget.height,
              child: Center(
                child: TextField(
                  textAlignVertical: TextAlignVertical.center,
                  textAlign: widget.textAlign,
                  style: TextStyle(
                    height: 1,
                    fontSize: fontSize,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.all(0),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (newValue) {
                    setState(() {
                      textString = newValue;
                      _isEditingText = false;
                    });
                  },
                  autofocus: true,
                  controller: _editingController,
                ),
              ),
            ),
          ),
        ),
        GestureDetector(
            onTap: () {
              _editingController.clear();
            },
            child: Padding(
              padding: EdgeInsets.all(widget.height * 0.2),
              child: Icon(size: widget.height * 0.6, Icons.clear),
            )),
      ],
    );
  }

  Widget notEditableText() {
    AlignmentGeometry align;
    switch (widget.textAlign) {
      case TextAlign.center:
        align = Alignment.center;
        break;
      case TextAlign.left:
      case TextAlign.start:
      case TextAlign.justify:
        align = Alignment.centerLeft;
        break;
      case TextAlign.right:
      case TextAlign.end:
        align = Alignment.centerRight;
        break;
    }

    return Padding(
      padding: widget.padding,
      child: SizedBox(
        height: widget.height,
        child: InkWell(
          onTap: () {
            setState(() {
              _isEditingText = true;
            });
          },
          child: Center(
            child: TextField(
              textAlignVertical: TextAlignVertical.center,
              textAlign: widget.textAlign,
              style: TextStyle(
                height: 1,
                fontSize: fontSize,
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.all(0),
                border: InputBorder.none,
              ),
              enabled: false,
              controller: _editingController,
            ),
          ),

          // child: Align(
          //   alignment: align,
          //   child: Text(
          //     textAlign: widget.textAlign,
          //     maxLines: 1,
          //     textString,
          //     style: TextStyle(
          //       height: 1,
          //       fontSize: fontSize,
          //     ),
          //   ),
          // ),
        ),
      ),
    );
  }

  Widget textWidget() {
    if (_isEditingText) {
      return editableText();
    }

    return notEditableText();
  }

  Widget addDelButton(Widget textField) {
    return Stack(
      children: [
        textField,
        Align(
          alignment: Alignment.centerRight,
          child: InkWell(
              onTap: () {
                _editingController.clear();
              },
              child: Padding(
                padding:
                    widget.padding.add(EdgeInsets.all(widget.height * 0.2)),
                child: Icon(size: widget.height * 0.6, Icons.clear),
              )),
        ),
      ],
    );
  }

  Widget textWidget2() {
    final textField = Padding(
      padding: widget.padding,
      child: SizedBox(
        height: widget.height,
        child: Center(
          child: TextField(
            textAlignVertical: TextAlignVertical.center,
            textAlign: widget.textAlign,
            style: TextStyle(
              height: 1,
              fontSize: fontSize,
            ),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.all(0),
              border: InputBorder.none,
            ),
            onSubmitted: (newValue) {
              setState(() {
                textString = newValue;
                _isEditingText = false;
              });
            },
            enabled: _isEditingText,
            autofocus: true,
            controller: _editingController,
            focusNode: focusNode,
          ),
        ),
      ),
    );

    if (_isEditingText) {
      return addDelButton(textField);
    }

    return InkWell(
        onTap: () {
          setState(() {
            _isEditingText = true;
          });
        },
        child: textField);
  }

  @override
  Widget build(BuildContext context) {
    // return Stack(children: [
    //   Align(
    //     alignment: Alignment(0, 0),
    //     child: textWidget(),
    //   ),
    //   Align(
    //       alignment: Alignment(1, 0),
    //       child: IconButton(onPressed: () {}, icon: Icon(Icons.clear)))
    // ]);

    return textWidget2();
  }
}
