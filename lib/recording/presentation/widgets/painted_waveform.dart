import 'package:brecorder/core/logging.dart';
import 'package:brecorder/recording/presentation/widgets/waveform_painter.dart';
import 'package:flutter/material.dart';

final log = Logger('WaveForm');

class _PointerInfo {
  int id;
  double startX;
  double endX;

  _PointerInfo({this.id = -1, this.startX = 0, this.endX = 0});
}

class PaintedWaveform extends StatefulWidget {
  final List<double> waveformData;
  final double zoomLevel;
  final double height;
  final bool scrollable;

  const PaintedWaveform(this.waveformData,
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
  static const _maxZoom = 5.0;
  static const _minZoom = 0.3;
  late double _zoom;
  bool _isScaleMode = false;
  late ScrollController _scrollController;
  double _width = 0;
  double _screenWidth = 0;
  final _pointers = <int, _PointerInfo>{};
  double _startScrollPosition = 0;
  double _startZoom = 0;

  @override
  initState() {
    super.initState();
    _zoom = widget.zoomLevel;
    _scrollController = ScrollController();
    // _scrollController.addListener(_scrollListener); // ←追加
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

  double get edge {
    if (_isScaleMode) {
      return _screenWidth / _minZoom * _zoom;
    } else {
      double screenEdge;
      if (_width < _screenWidth) {
        screenEdge = (_screenWidth - _width) / 2;
      } else {
        screenEdge = 0;
      }
      return screenEdge + (_screenWidth / 2);
    }
  }

  double _availableZoom(double zoom) {
    if (zoom > _maxZoom) {
      return _maxZoom;
    } else if (zoom < _minZoom) {
      return _minZoom;
    } else {
      return zoom;
    }
  }

  Widget _addScrollWrapper(Widget child) {
    if (widget.scrollable) {
      return SizedBox(
          height: widget.height,
          child: ListView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: _isScaleMode
                  ? const NeverScrollableScrollPhysics()
                  : const ScrollPhysics(),
              children: [child]));
    } else {
      return child;
    }
  }

  double _calcWidth(double zoom) {
    final ret = _defaultDx * zoom * widget.waveformData.length;
    // log.debug("zoom:$zoom, width:$ret");
    return ret;
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
        final normalEdge = edge;
        _isScaleMode = true;
        final diff = edge - normalEdge;
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
        final scaleEdge = edge;
        _isScaleMode = false;
        final diff = edge - scaleEdge;
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
    _width = _calcWidth(_zoom);
    int fromIndex = 0;

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
            if (fromIndex < 0) fromIndex = 0;
          }

          log.debug("[BUILD] edge:$edge, zoom:$_zoom, width:$_width");
          return _addScrollWrapper(CustomPaint(
            size: Size(
              _width + (edge * 2),
              widget.height,
            ),
            foregroundPainter: WaveformPainter(
              widget.waveformData,
              _dx,
              edge,
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
