import 'package:brecorder/core/logging.dart';
import 'package:flutter/material.dart';

final log = Logger('OnOffIconButton');

class OnOffIconButton extends StatefulWidget {
  final IconData? icon;
  final void Function(bool state)? onStateChanged;
  final void Function()? onTap;
  final ValueNotifier<bool>? stateNotifier;
  final ValueNotifier<double>? valueNotifier;
  final double? defaultValue;
  final String Function(double value)? labelFormater;
  final IconData Function(double value)? iconGenerator;
  final double minWidth;
  final bool labelAnimation;

  const OnOffIconButton({
    Key? key,
    this.icon,
    this.onStateChanged,
    this.onTap,
    this.stateNotifier,
    this.valueNotifier,
    this.defaultValue,
    this.labelFormater,
    this.iconGenerator,
    this.minWidth = 50,
    this.labelAnimation = true,
  }) : super(key: key);

  @override
  State<OnOffIconButton> createState() => _OnOffIconButtonState();
}

class _OnOffIconButtonState extends State<OnOffIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  Animation? _colorTween;
  Animation? _optacityTween;
  final highlightNotifier = ValueNotifier(false);

  @override
  void initState() {
    //Button state trasition depends on [widget.stateNotifier] or [widget.iconGenerator]
    assert(widget.stateNotifier != null || widget.iconGenerator != null);
    super.initState();
    _animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    widget.stateNotifier?.addListener(_updateHighligt);
    widget.valueNotifier?.addListener(_updateHighligt);
  }

  void _updateHighligt() {
    if (widget.stateNotifier?.value == true) {
      highlightNotifier.value = true;
    } else if (widget.defaultValue == null || widget.valueNotifier == null) {
      highlightNotifier.value = false;
    } else if (widget.valueNotifier!.value != widget.defaultValue) {
      highlightNotifier.value = true;
    } else {
      highlightNotifier.value = false;
    }
  }

  Widget _buildLabelText(BuildContext context) {
    if (widget.valueNotifier == null) {
      return Text(
        "",
        style: Theme.of(context).textTheme.labelSmall!,
      );
    }
    assert(widget.valueNotifier != null && widget.defaultValue != null);

    return ValueListenableBuilder<double>(
        valueListenable: widget.valueNotifier!,
        builder: (context, value, _) {
          String labelStr = "";
          if (value == widget.defaultValue) {
            labelStr = "";
          } else if (widget.labelFormater == null) {
            labelStr = value.toStringAsFixed(2);
          } else {
            labelStr = widget.labelFormater!(value);
          }

          final labelWidget = Text(
            labelStr,
            key: ValueKey<String>(labelStr),
            style: Theme.of(context)
                .textTheme
                .labelSmall!
                .copyWith(color: Theme.of(context).indicatorColor),
          );

          if (!widget.labelAnimation) return labelWidget;

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (Widget child, Animation<double> animation) {
              // return ScaleTransition(scale: animation, child: child);
              // return RotationTransition(turns: animation, child: child);
              return FadeTransition(opacity: animation, child: child);
            },
            child: labelWidget,
          );
          // return AnimatedOpacity(
          //   duration: const Duration(milliseconds: 300),
          //   opacity: value == widget.defaultValue ? 0 : 1,
          //   child: Text(
          //     widget.labelFormater == null
          //         ? value.toStringAsFixed(2)
          //         : widget.labelFormater!(value),
          //     style: Theme.of(context)
          //         .textTheme
          //         .labelSmall!
          //         .copyWith(color: Theme.of(context).indicatorColor),
          //   ),
          // );
        });
  }

  Widget _buildIcon(BuildContext context) {
    if (widget.iconGenerator == null) {
      return AnimatedBuilder(
          animation: _colorTween!,
          builder: (context, _) {
            return Icon(
              widget.icon,
              color: _colorTween!.value,
            );
          });
    }

    return ValueListenableBuilder<double>(
        valueListenable: widget.valueNotifier!,
        builder: (context, value, _) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (Widget child, Animation<double> animation) {
              // return ScaleTransition(scale: animation, child: child);
              // return RotationTransition(turns: animation, child: child);
              return FadeTransition(opacity: animation, child: child);
            },
            child: Icon(
              widget.iconGenerator!(value),
              color: highlightNotifier.value
                  ? Theme.of(context).indicatorColor
                  : null,
              // This key causes the AnimatedSwitcher to interpret this as a "new"
              // child each time the count changes, so that it will begin its animation
              // when the count changes.
              key: ValueKey<double>(value),
            ),
          );
        });
  }

  @override
  Widget build(context) {
    _colorTween ??= ColorTween(
            begin: Theme.of(context).textTheme.bodyText1!.color,
            end: Theme.of(context).indicatorColor)
        .animate(_animationController);
    _optacityTween ??= Tween(begin: 0, end: 1).animate(_animationController);
    return ValueListenableBuilder<bool>(
        valueListenable: highlightNotifier,
        builder: (context, on, _) {
          if (on) {
            _animationController.forward();
          } else {
            _animationController.reverse();
          }
          return SizedBox(
            width: widget.minWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                    customBorder: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    onTap: () {
                      if (widget.stateNotifier != null) {
                        widget.stateNotifier?.value =
                            !widget.stateNotifier!.value;
                        widget.onStateChanged
                            ?.call(widget.stateNotifier!.value);
                      }
                      widget.onTap?.call();
                    },
                    child: Ink(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        // color: Colors.purpleAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _buildIcon(context),
                    )),
                _buildLabelText(context),
              ],
            ),
          );
        });
  }
}
