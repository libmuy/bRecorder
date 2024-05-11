import 'package:flutter/material.dart';

import '../../core/logging.dart';
import 'icons/audio_icons.dart';
import 'square_icon_button.dart';

final log = Logger('OnOffIconButton', 
// level: LogLevel.debug
);

class RectThumbSlider extends StatefulWidget {
  final ValueNotifier<double> valueNotifier;
  final ValueNotifier<double>? minNotifier;
  final ValueNotifier<double>? maxNotifier;
  final double min;
  final double max;
  final double? initValue;
  final double thumbSize;
  final int? divisions;
  final IconData? icon;
  final Color? color;
  final void Function(double value)? onChanged;
  final void Function(double value)? onChangeStart;
  final void Function(double value)? onChangeEnd;
  final String Function(double value)? labelFormater;

  const RectThumbSlider(
      {super.key,
      this.onChangeEnd,
      this.onChangeStart,
      this.onChanged,
      required this.valueNotifier,
      this.minNotifier,
      this.maxNotifier,
      this.min = 0.0,
      this.max = 1.0,
      this.thumbSize = 8,
      this.labelFormater,
      this.divisions,
      this.icon,
      this.color,
      this.initValue});
  @override
  State<RectThumbSlider> createState() => _RectThumbSliderState();
}

class _RectThumbSliderState extends State<RectThumbSlider> {
  @override
  void initState() {
    super.initState();
    widget.minNotifier?.addListener(_rebuild);
    widget.maxNotifier?.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.minNotifier?.removeListener(_rebuild);
    widget.maxNotifier?.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    setState(() {});
  }

  Widget _internalSlider(
      BuildContext context, double value, double min, double max) {
    final sliderFontStyle = Theme.of(context).textTheme.labelSmall;
    log.debug("slider min:$min, max:$max, value:$value");
    return Container(
      color: widget.color ?? Theme.of(context).primaryColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderThemeData(
                overlayShape: RoundSliderOverlayShape(
                  overlayRadius: widget.thumbSize * 1.8,
                ),
                thumbShape:
                    RectSliderThumbShape(enabledThumbRadius: widget.thumbSize)),
            child: Slider(
              divisions: widget.divisions,
              activeColor: Theme.of(context).indicatorColor.withOpacity(0.4),
              inactiveColor: Theme.of(context).focusColor,
              thumbColor: Theme.of(context).indicatorColor,
              value: value,
              min: min,
              max: max,
              onChanged: widget.onChanged,
              onChangeStart: widget.onChangeStart,
              onChangeEnd: widget.onChangeEnd,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 15.0),
                child: Text(
                  widget.labelFormater == null
                      ? min.toStringAsFixed(2)
                      : widget.labelFormater!.call(min),
                  style: sliderFontStyle,
                ),
              ),
              Text(
                widget.labelFormater == null
                    ? value.toStringAsFixed(2)
                    : widget.labelFormater!.call(value),
                style: sliderFontStyle,
              ),
              Padding(
                padding: const EdgeInsets.only(right: 15.0),
                child: Text(
                  widget.labelFormater == null
                      ? max.toStringAsFixed(2)
                      : widget.labelFormater!.call(max),
                  style: sliderFontStyle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(context) {
    final min =
        (widget.minNotifier == null) ? widget.min : widget.minNotifier!.value;
    final max =
        (widget.maxNotifier == null) ? widget.max : widget.maxNotifier!.value;

    return ValueListenableBuilder<double>(
        valueListenable: widget.valueNotifier,
        builder: (context, value, _) {
          if (value > max) value = max;
          if (value.isNaN) value = 0;
          if (widget.icon == null) {
            return _internalSlider(context, value, min, max);
          }
          assert(widget.initValue != null);

          return IntrinsicHeight(
            child: Row(
              children: [
                SizedBox(
                  height: double.infinity,
                  child: Container(
                    alignment: Alignment.center,
                    child: SquareIconButton(
                      minWidth: 30,
                      onPressed: (() {
                        final div = widget.divisions ?? 20;
                        var newValue = value - (max / div);
                        if (newValue < min) newValue = min;
                        widget.valueNotifier.value = newValue;
                        widget.onChangeEnd?.call(newValue);
                      }),
                      child: OverlayIcon(
                        bigIcon: widget.icon!,
                        smallIcon: Icons.remove_circle_rounded,
                        color: value < widget.initValue!
                            ? Theme.of(context).indicatorColor
                            : null,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _internalSlider(context, value, min, max),
                ),
                SizedBox(
                  height: double.infinity,
                  child: Container(
                    alignment: Alignment.center,
                    child: SquareIconButton(
                      minWidth: 30,
                      onPressed: (() {
                        final div = widget.divisions ?? 20;
                        var newValue = value + (max / div);
                        if (newValue > max) newValue = max;
                        log.debug("value: ${widget.valueNotifier.value} ->"
                            "$newValue");
                        widget.valueNotifier.value = newValue;
                        widget.onChangeEnd?.call(newValue);
                      }),
                      child: OverlayIcon(
                        bigIcon: widget.icon!,
                        smallIcon: Icons.add_circle_rounded,
                        color: value > widget.initValue!
                            ? Theme.of(context).indicatorColor
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        });
  }
}

/// The default shape of a [Slider]'s thumb.
///
/// There is a shadow for the resting, pressed, hovered, and focused state.
///
/// ![A slider widget, consisting of 5 divisions and showing the round slider thumb shape.]
/// (https://flutter.github.io/assets-for-api-docs/assets/material/round_slider_thumb_shape.png)
///
/// See also:
///
///  * [Slider], which includes a thumb defined by this shape.
///  * [SliderTheme], which can be used to configure the thumb shape of all
///    sliders in a widget subtree.
class RectSliderThumbShape extends SliderComponentShape {
  /// Create a slider thumb that draws a circle.
  const RectSliderThumbShape({
    this.enabledThumbRadius = 10.0,
    this.disabledThumbRadius,
    this.elevation = 1.0,
    this.pressedElevation = 6.0,
    this.overlay = false,
  });

  final bool overlay;

  /// The preferred radius of the round thumb shape when the slider is enabled.
  ///
  /// If it is not provided, then the material default of 10 is used.
  final double enabledThumbRadius;

  /// The preferred radius of the round thumb shape when the slider is disabled.
  ///
  /// If no disabledRadius is provided, then it is equal to the
  /// [enabledThumbRadius]
  final double? disabledThumbRadius;
  double get _disabledThumbRadius => disabledThumbRadius ?? enabledThumbRadius;

  /// The resting elevation adds shadow to the unpressed thumb.
  ///
  /// The default is 1.
  ///
  /// Use 0 for no shadow. The higher the value, the larger the shadow. For
  /// example, a value of 12 will create a very large shadow.
  ///
  final double elevation;

  /// The pressed elevation adds shadow to the pressed thumb.
  ///
  /// The default is 6.
  ///
  /// Use 0 for no shadow. The higher the value, the larger the shadow. For
  /// example, a value of 12 will create a very large shadow.
  final double pressedElevation;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(
        isEnabled == true ? enabledThumbRadius : _disabledThumbRadius);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    assert(sliderTheme.disabledThumbColor != null);
    assert(sliderTheme.thumbColor != null);

    final Canvas canvas = context.canvas;
    final Tween<double> radiusTween = Tween<double>(
      begin: _disabledThumbRadius,
      end: enabledThumbRadius,
    );
    final ColorTween colorTween = ColorTween(
      begin: sliderTheme.disabledThumbColor,
      end: sliderTheme.thumbColor,
    );

    final Color color = colorTween.evaluate(enableAnimation)!;
    final double radius = radiusTween.evaluate(enableAnimation);

    final Tween<double> elevationTween = Tween<double>(
      begin: elevation,
      end: pressedElevation,
    );
    final width = radius / 2;
    final height = radius;
    final shadowWidth = width + (radius * 1);
    final shadowHeight = height + (radius * 0.5);

    final double evaluatedElevation =
        elevationTween.evaluate(activationAnimation);

    if (overlay) {
      canvas.drawRRect(
          RRect.fromLTRBR(
              center.dx - (width / 2),
              center.dy - height,
              center.dx + (width / 2),
              center.dy + height,
              Radius.circular(radius / 6)),
          Paint()
            ..color = Colors.red
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
    } else {
      final Path path = Path()
        ..addRRect(RRect.fromLTRBR(
            center.dx - (shadowWidth / 2),
            center.dy - shadowHeight,
            center.dx + (shadowWidth / 2),
            center.dy + shadowHeight,
            Radius.circular(radius / 6)));
      canvas.drawShadow(
          path, Colors.black.withOpacity(0.1), evaluatedElevation, true);

      canvas.drawRRect(
          RRect.fromLTRBR(
              center.dx - (width / 2),
              center.dy - height,
              center.dx + (width / 2),
              center.dy + height,
              Radius.circular(radius / 6)),
          Paint()..color = color);
    }
  }
}
