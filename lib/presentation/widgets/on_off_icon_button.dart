import 'package:flutter/material.dart';

import '../../core/logging.dart';
import 'square_icon_button.dart';

final log = Logger('OnOffIconButton');

class OnOffIconButton extends StatefulWidget {
  final IconData? icon;
  final IconData? onStateIcon;
  final EdgeInsets padding;
  final void Function(bool state)? onStateChanged;
  final void Function()? onTap;
  final ValueNotifier<bool>? stateNotifier;
  final ValueNotifier<double>? valueNotifier;
  final double? defaultValue;
  final String Function(double value)? labelFormater;
  final IconData Function(double value)? iconGenerator;
  final double minWidth;
  final bool labelAnimation;
  final bool noLabel;
  final Duration duration;

  const OnOffIconButton({
    Key? key,
    this.icon,
    this.onStateIcon,
    this.onStateChanged,
    this.onTap,
    this.stateNotifier,
    this.valueNotifier,
    this.defaultValue,
    this.labelFormater,
    this.noLabel = false,
    this.iconGenerator,
    this.minWidth = 50,
    this.labelAnimation = true,
    this.padding = const EdgeInsets.all(3),
    this.duration = const Duration(milliseconds: 100),
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
    super.initState();
    _animationController =
        AnimationController(vsync: this, duration: widget.duration);
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

  Widget? _buildLabelText(BuildContext context) {
    if (widget.noLabel) return null;
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
            duration: widget.duration,
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
      var icon = widget.icon;
      if (widget.stateNotifier != null &&
          widget.stateNotifier!.value == true &&
          widget.onStateIcon != null) {
        icon = widget.onStateIcon;
      }
      return AnimatedBuilder(
          animation: _colorTween!,
          builder: (context, _) {
            return Icon(
              icon,
              color: _colorTween!.value,
            );
          });
    }

    return ValueListenableBuilder<double>(
        valueListenable: widget.valueNotifier!,
        builder: (context, value, _) {
          return AnimatedSwitcher(
            duration: widget.duration,
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
    log.debug("duration${widget.duration}");
    _colorTween ??= ColorTween(
            begin: Theme.of(context).textTheme.bodyLarge!.color,
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
          return SquareIconButton(
            padding: widget.padding,
            onPressed: () {
              if (widget.stateNotifier != null) {
                widget.stateNotifier?.value = !widget.stateNotifier!.value;
                widget.onStateChanged?.call(widget.stateNotifier!.value);
              }
              widget.onTap?.call();
            },
            label: _buildLabelText(context),
            child: _buildIcon(context),
          );
        });
  }
}
