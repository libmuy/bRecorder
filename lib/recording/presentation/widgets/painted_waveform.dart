import 'package:brecorder/core/global_info.dart';
import 'package:brecorder/core/logging.dart';
import 'package:brecorder/recording/presentation/widgets/waveform_painter.dart';
import 'package:flutter/material.dart';

final log = Logger('WaveForm');

class PaintedWaveform extends StatefulWidget {
  final List<double> waveformData;
  double zoomLevel;
  final double height;
  final bool scrollable;

  PaintedWaveform(this.waveformData,
      {required Key key,
      this.zoomLevel = 1.0,
      this.height = 100,
      this.scrollable = true})
      : super(key: key);

  @override
  State<PaintedWaveform> createState() => _PaintedWaveformState();
}

class _PaintedWaveformState extends State<PaintedWaveform> {
  static const double _defaultDx = 0.5;
  static const double _maxDx = 1;
  static const double _minDx = 0.01;

  Widget _addScrollWrapper(Widget child) {
    if (widget.scrollable) {
      return SizedBox(
          height: widget.height,
          child: ListView(scrollDirection: Axis.horizontal, children: [child]));
    } else {
      return child;
    }
  }

  double get _dxPerSecond {
    return _calcDx(widget.zoomLevel) * GlobalInfo.WAVEFORM_SAMPLES_PER_SECOND;
  }

  double _calcDx(double zoom) {
    double dx = _defaultDx * zoom;
    if (dx > _maxDx) dx = _maxDx;
    if (dx < _minDx) dx = _minDx;

    return dx;
  }

  @override
  Widget build(context) {
    double dx = _calcDx(widget.zoomLevel);
    log.debug("drawing with dx:$dx");

    double width = dx * widget.waveformData.length;
    double startX = 0;
    int fromIndex = 0;

    return GestureDetector(
      onScaleUpdate: (details) {
        if (details.scale == 1.0) return;
        final newZoom = widget.zoomLevel * details.scale;
        final newDx = _calcDx(newZoom);
        if (dx != newDx) {
          log.debug("scale update: ${details.scale}, dx:$dx -> $newDx");
          setState(() {
            widget.zoomLevel = newZoom;
          });
        }
      },
      onScaleEnd: (details) {
        //  setState(() {
        //  });
        log.debug(
            "scale end: pointer count:${details.pointerCount}, velocity: ${details.velocity}");
      },
      child: Container(
        color: Colors.black87,
        child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
          if (width < constraints.maxWidth) {
            startX = constraints.maxWidth - width;
            width = constraints.maxWidth;
          }
          if (!widget.scrollable) {
            final drawableCount = constraints.maxWidth / dx;
            fromIndex = widget.waveformData.length - drawableCount.toInt();
            if (fromIndex < 0) fromIndex = 0;
          }

          return _addScrollWrapper(CustomPaint(
            size: Size(
              width,
              widget.height,
            ),
            foregroundPainter: WaveformPainter(
              widget.waveformData,
              dx,
              startX,
              fromIndex: fromIndex,
              color: const Color(0xff3994DB),
            ),
          ));
        }),
      ),
    );
  }
}
