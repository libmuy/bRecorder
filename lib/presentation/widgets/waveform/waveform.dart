import 'dart:async';

import 'package:brecorder/core/global_info.dart';
import 'package:brecorder/core/logging.dart';
import 'package:flutter/material.dart';

import '../../../core/utils.dart';
import 'center_bar_painter.dart';
import 'waveform_painter.dart';

final log = Logger('WaveForm');

class WaveformDelegate {
  Function(double, bool)? _setPosition;
  Function(double, bool)? _setPositionByPercent;

  void setPosition(double positionSec, {bool dispatchNotification = false}) {
    _setPosition?.call(positionSec, dispatchNotification);
  }

  void setPositionByPercent(double percent,
      {bool dispatchNotification = false}) {
    _setPositionByPercent?.call(percent, dispatchNotification);
  }
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
  final double? height;
  final bool scrollable;
  final Function(AudioPositionInfo metircs)? positionListener;
  final Function(AudioPositionInfo metircs)? startSeek;
  final Function(AudioPositionInfo metircs)? endSeek;
  final WaveformDelegate? delegate;

  const Waveform(
    this.waveformData, {
    Key? key,
    // required Key key,
    this.zoomLevel = 1.0,
    this.height,
    this.scrollable = true,
    this.positionListener,
    this.startSeek,
    this.endSeek,
    this.delegate,
  }) : super(key: key);

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
  bool _noDispatchNotification = false;
  AudioPositionInfo? _notifiedMetrics;
  bool _seeking = false;

  @override
  initState() {
    super.initState();
    _zoom = widget.zoomLevel;
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener); // ←追加
    widget.delegate?._setPosition = _setPosition;
    widget.delegate?._setPositionByPercent = _setPositionByPercent;
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

  ///Unit : Second
  double get _duration {
    double dxDuration = 1.0 / GlobalInfo.WAVEFORM_SAMPLES_PER_SECOND.toDouble();
    double duration = dxDuration * widget.waveformData.length;
    // log.debug("duration:$duration, dx:$dxDuration");
    return duration;
  }

  ///Unit : Second
  AudioPositionInfo? get _metrics {
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
      return AudioPositionInfo(_duration, pos);
    }

    return null;
  }

  void _setPosition(double seconds, bool dispatchNotification) {
    if (_pointers.isNotEmpty) return;

    final percent = seconds / _duration;
    // log.debug("set position to $seconds ms, $percent%");
    _setPositionByPercent(percent, dispatchNotification);
  }

  void _setPositionByPercent(double percent, bool dispatchNotification) {
    // No scroll Mode
    if (!widget.scrollable) {
      return;

      // Scale Mode
    } else if (_isScaleMode) {
      return;

      // Normal Mode
    } else {
      _noDispatchNotification = !dispatchNotification;
      _scrollController
          .jumpTo(_scrollController.position.maxScrollExtent * percent);
    }
  }

  void _scrollListener() {
    final metrics = _metrics;
    if (_noDispatchNotification == true) {
      _noDispatchNotification = false;
    } else if (metrics != null && _notifiedMetrics != metrics) {
      widget.positionListener!(metrics);
    }
    _notifiedMetrics = metrics;
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
    // log.debug("build waveform from scale");
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

    // 1 Pointers Down: Entering Scroll Mode
    if (_pointers.length == 1) {
      final metrics = _metrics;
      if (widget.startSeek != null && metrics != null) {
        widget.startSeek!(_metrics!);
        _seeking = true;
      }

      // 2 Pointers Down: Entering Scale Mode
    } else if (_pointers.length == 2) {
      // log.debug("build waveform from pointer down");
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
      // log.debug("build waveform from pointer up");
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
    Timer.run(() => _scrollListener());

    return Container(
      color: Colors.black87,
      child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
        double height = widget.height ?? constraints.maxHeight;
        if (height == double.infinity) {
          height = MediaQuery.of(context).size.height;
        }
        int fromIndex = 0;
        double startX = 0;
        _screenWidth = constraints.maxWidth;
        if (_screenWidth == double.infinity) {
          _screenWidth = MediaQuery.of(context).size.width;
        }

        if (!widget.scrollable) {
          final drawableCount = _screenWidth / _dx;
          fromIndex = widget.waveformData.length - drawableCount.toInt();
          if (fromIndex <= 0) {
            fromIndex = 0;
            startX = _dx * (drawableCount - widget.waveformData.length);
          }
        }

        Widget waveformWidget = CustomPaint(
          size: Size(
            widget.scrollable ? _width + (_edge * 2) : _screenWidth,
            height,
          ),
          foregroundPainter: WaveformPainter(
            widget.waveformData,
            _dx,
            _edge + startX,
            fromIndex: fromIndex,
            color: const Color(0xff3994DB),
            // painterRuler: true,
          ),
        );

        if (widget.scrollable) {
          waveformWidget = NotificationListener<ScrollEndNotification>(
            // スクロールの状態をlisten

            onNotification: (notification) {
              // Ending Scoll Mode
              final metrics = _metrics;
              if (widget.endSeek != null && metrics != null && _seeking) {
                widget.endSeek!(_metrics!);
                _seeking = false;
              }

              return true;
            },
            // 初期状態でのマウススクロールを検知
            child: Listener(
                onPointerDown: _pointerDown,
                onPointerMove: _pointerMove,
                onPointerUp: _pointerUp,
                child: SizedBox(
                    height: height,
                    child: Stack(
                      children: [
                        ListView(
                            controller: _scrollController,
                            scrollDirection: Axis.horizontal,
                            physics: _isScaleMode
                                ? const NeverScrollableScrollPhysics()
                                : const BouncingScrollPhysics(),
                            children: [waveformWidget]),
                        Center(
                          child: CustomPaint(
                            size: Size(
                              4,
                              height,
                            ),
                            foregroundPainter: CenterBarPainter(),
                          ),
                        ),
                      ],
                    ))),
          );
        }
        // var dbgStr = "[BUILD] duration:${_duration.toStringAsFixed(2)} secs";
        // dbgStr += ", edge:$_edge, zoom:$_zoom, width:$_width";
        // log.debug(dbgStr);
        return waveformWidget;
      }),
    );
  }
}
