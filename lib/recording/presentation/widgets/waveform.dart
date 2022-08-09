import 'dart:async';

import 'package:brecorder/core/global_info.dart';
import 'package:brecorder/core/logging.dart';
import 'package:brecorder/recording/domain/waveform_data_model.dart';
import 'package:brecorder/recording/presentation/widgets/center_bar_painter.dart';
import 'package:brecorder/recording/presentation/widgets/waveform_painter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

final log = Logger('WaveForm');

class WaveformMetrics {
  double duration;
  double position;

  WaveformMetrics(this.duration, this.position);
}

class _PointerInfo {
  int id;
  double startX;
  double endX;

  _PointerInfo({this.id = -1, this.startX = 0, this.endX = 0});
}

class Waveform extends StatefulWidget {
  final List<double> waveformData;
  final double zoomLevel;
  final double height;
  final bool scrollable;
  final Function(WaveformMetrics metircs)? positionListener;

  const Waveform(this.waveformData,
      {required Key key,
      this.zoomLevel = 1.0,
      this.height = 100,
      this.scrollable = true,
      this.positionListener})
      : super(key: key);

  @override
  State<Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<Waveform> {
  static const double _defaultDx = 0.5;
  static const _maxZoom = 5.0;
  static const _minZoom = 0.3;
  late double _zoom;
  bool _isScaleMode = false;
  late ScrollController _scrollController;
  double _screenWidth = 0;
  final _pointers = <int, _PointerInfo>{};
  double _startScrollPosition = 0;
  double _startZoom = 0;

  @override
  initState() {
    super.initState();
    _zoom = widget.zoomLevel;
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener); // ←追加
    log.debug("initState()");
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  double get _dx {
    return _defaultDx * _zoom;
  }

  double get _width {
    return _calcWidth(_zoom);
  }

  double get _duration {
    double dxDuration = 1000 / GlobalInfo.WAVEFORM_SAMPLES_PER_SECOND;
    double duration = dxDuration * widget.waveformData.length / 1000;
    return duration;
  }

  void _scrollListener() {
    if (widget.positionListener != null) {
      double pos;
      if (_scrollController.hasClients) {
        var percent = _scrollController.offset /
            _scrollController.position.maxScrollExtent;
        if (percent < 0) percent = 0;
        if (percent > 1) percent = 1;
        pos = _duration * percent;
      } else {
        pos = 0;
      }
      // log.debug("duration:$_duration, position:$pos");
      widget.positionListener!(WaveformMetrics(_duration, pos));
    }
  }

  // void _notifierWhenBuild(dynamic arg) {
  //   _scrollListener();
  // }

  double _availableZoom(double zoom) {
    if (zoom > _maxZoom) {
      return _maxZoom;
    } else if (zoom < _minZoom) {
      return _minZoom;
    } else {
      return zoom;
    }
  }

  double _calcWidth(double zoom) {
    final ret = _defaultDx * zoom * widget.waveformData.length;
    // log.debug("zoom:$zoom, width:$ret");
    return ret;
  }

  Widget _addScrollWrapper(Widget child) {
    if (widget.scrollable) {
      return SizedBox(
          height: widget.height,
          child: Stack(
            children: [
              ListView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: _isScaleMode
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                  children: [child]),
              Center(
                child: CustomPaint(
                  size: Size(
                    4,
                    widget.height,
                  ),
                  foregroundPainter: CenterBarPainter(),
                ),
              ),
            ],
          ));
    } else {
      return child;
    }
  }

  /*=======================================================================*\ 
    Calculate Edge in different MODE
  \*=======================================================================*/
  double get _edge {
    // No scroll Mode
    if (!widget.scrollable) {
      return 0;

      // Scale Mode
    } else if (_isScaleMode) {
      return _screenWidth / _minZoom * _zoom;

      // Normal Mode
    } else {
      return _screenWidth / 2;
    }
  }

  /*=======================================================================*\ 
    Scale waveform
  \*=======================================================================*/
  void scaleWaveform() {
    if (_pointers.length != 2) {
      return;
    }

    final pointers = _pointers.values.toList();
    final p1 = pointers[0];
    final p2 = pointers[1];

    final scale = (p1.endX - p2.endX) / (p1.startX - p2.startX);
    final targetZoom = _availableZoom(_startZoom * scale);

    final startPos = _startScrollPosition + p1.startX;
    final targetPos = startPos * scale;
    var targetScrollOffset = targetPos - p1.endX;

    if (targetZoom == _zoom &&
        (targetScrollOffset == _startScrollPosition ||
            _zoom == _maxZoom ||
            _zoom == _minZoom)) {
      // log.debug(
      //     "no need scale, same zoom($_zoom)! startZoom:$_startZoom, scale:$scale");
      return;
    }

    // final targetWidth = _calcWidth(targetZoom);
    // var dbgStr = "Scale waveform: ZOOM:${targetZoom.toStringAsFixed(2)}";
    // dbgStr += ", Scale:${scale.toStringAsFixed(2)}";
    // dbgStr += ", StartPos:${startPos.toStringAsFixed(2)}";
    // dbgStr += ", TargetPos:${targetPos.toStringAsFixed(2)}";
    // dbgStr += ", Offset:${targetScrollOffset.toStringAsFixed(2)}";
    // dbgStr += ", TargetWidth:${targetWidth.toStringAsFixed(2)}";
    // log.debug(dbgStr);
    setState(() {
      _zoom = targetZoom;
      _scrollController.jumpTo(targetScrollOffset);
    });
  }

  /*=======================================================================*\ 
    Pointer Events:
  \*=======================================================================*/
  void _pointerDown(PointerEvent details) {
    _pointers[details.pointer] = _PointerInfo(
        id: details.pointer,
        startX: details.position.dx,
        endX: details.position.dx);

    // 2 Pointers Down: Entering Scale Mode
    if (_pointers.length == 2) {
      setState(() {
        final normalEdge = _edge;
        _isScaleMode = true;
        final diff = _edge - normalEdge;
        _startScrollPosition = _scrollController.offset + diff;
        _startZoom = _zoom;
        // var dbgStr =
        //     "Start ScrollOffset:${_startScrollPosition.toStringAsFixed(1)}";
        // dbgStr += ", Zoom:${_startZoom.toStringAsFixed(1)}";
        // log.debug(dbgStr);
        _scrollController.jumpTo(_startScrollPosition);
      });
    }
  }

  /*-----------------------------------------------------------------*/
  void _pointerUp(PointerEvent details) {
    // Ending Scale Mode
    if (_pointers.length == 2) {
      setState(() {
        final scaleEdge = _edge;
        _isScaleMode = false;
        final diff = _edge - scaleEdge;
        _scrollController.jumpTo(_scrollController.offset + diff);
        // if (edge > 0) {
        //   _scrollController.jumpTo(0);
        // } else {
        //   _scrollController.jumpTo(_scrollController.offset - scaleEdge);
        // }
      });
    }
    _pointers.remove(details.pointer);
  }

  /*-----------------------------------------------------------------*/
  void _pointerMove(PointerEvent details) {
    final info = _pointers[details.pointer];
    info!.endX = details.position.dx;

    if (_pointers.length == 1) {
      info.startX = info.endX;
    } else if (_pointers.length == 2) {
      scaleWaveform();
    }
  }

  /*=======================================================================*\ 
    build() medthod
  \*=======================================================================*/
  @override
  Widget build(context) {
    int fromIndex = 0;
    double startX = 0;

    // compute(_notifierWhenBuild, null);
    Timer.run(() => _scrollListener());

    return Listener(
      onPointerDown: _pointerDown,
      onPointerMove: _pointerMove,
      onPointerUp: _pointerUp,
      child: Container(
        color: Colors.black87,
        child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
          _screenWidth = constraints.maxWidth;
          if (!widget.scrollable) {
            final drawableCount = _screenWidth / _dx;
            fromIndex = widget.waveformData.length - drawableCount.toInt();
            if (fromIndex <= 0) {
              fromIndex = 0;
              startX = _dx * (drawableCount - widget.waveformData.length);
            }
          }
          // var dbgStr = "[BUILD] duration:${_duration.toStringAsFixed(2)} secs";
          // dbgStr += ", edge:$_edge, zoom:$_zoom, width:$_width";
          // log.debug(dbgStr);
          return _addScrollWrapper(CustomPaint(
            size: Size(
              widget.scrollable ? _width + (_edge * 2) : _screenWidth,
              widget.height,
            ),
            foregroundPainter: WaveformPainter(
              widget.waveformData,
              _dx,
              _edge + startX,
              fromIndex: fromIndex,
              color: const Color(0xff3994DB),
              // painterRuler: true,
            ),
          ));
        }),
      ),
    );
  }
}
