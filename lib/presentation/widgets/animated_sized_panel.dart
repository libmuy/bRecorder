import 'dart:async';

import 'package:brecorder/core/utils.dart';
import 'package:flutter/material.dart';

import '../../core/logging.dart';
import 'size_measurer.dart';

class AnimatedSizedPanel extends StatefulWidget {
  final bool show;
  final bool relayNotification;
  final Duration duration;
  final void Function(double height)? onHeightChanged;
  final void Function(AnimationStatus from, AnimationStatus to)?
      onAnimationStatusChanged;
  final PriorityValueNotifier<AnimatedSizedPanelDragEvent>? dragNotifier;
  final int dragListenerPriority;
  final String debugLabel;
  final Widget child;
  const AnimatedSizedPanel({
    Key? key,
    required this.show,
    required this.child,
    this.relayNotification = false,
    this.duration = const Duration(milliseconds: 3000),
    this.onHeightChanged,
    this.onAnimationStatusChanged,
    this.dragNotifier,
    this.dragListenerPriority = 0,
    this.debugLabel = "",
  }) : super(key: key);

  @override
  State<AnimatedSizedPanel> createState() => _AnimatedSizedPanelState();
}

class _AnimatedSizedPanelState extends State<AnimatedSizedPanel>
    with SingleTickerProviderStateMixin {
  final log = Logger(
    'SizedPanel',
  );
  //Bottom Panel Drag Processing
  double _startDragPos = 0;
  double _endDragPos = 0;
  double _currentSizeRate = 1;
  double _panelHeight = 0;
  var _lastAnimationStatus = AnimationStatus.dismissed;
  int _quickScroll = 0; //0: no scroll, 1: scroll down, -1: scroll up
  bool _canceledNext = false;
  bool _dragEventCanceled = false;
  final _panelKey = GlobalKey(debugLabel: "panel key");
  final _originalPanelKey = GlobalKey(debugLabel: "original panel key");
  late final AnimationController _animationController;
  late final Animation<double> _sizeAnimation;

  @override
  void initState() {
    super.initState();
    log.name = widget.debugLabel;
    log.debug(
        "### initState, Name:${widget.debugLabel} priority:${widget.dragListenerPriority}");
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _sizeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(_animationController);
    _animationController.addStatusListener(_animationStatusListener);

    widget.dragNotifier
        ?.addListener(widget.dragListenerPriority, _dragEventListener);
  }

  @override
  void dispose() {
    log.debug(
        "### dispose, ID:${widget.debugLabel}, priority:${widget.dragListenerPriority}");
    _animationController.dispose();
    widget.dragNotifier
        ?.removeListener(widget.dragListenerPriority, _dragEventListener);
    super.dispose();
  }

  double _calculatePanelHeight(GlobalKey key) {
    final contex = key.currentContext;
    if (contex == null) {
      log.error("Playback Panel is not being rendered");
      return 0;
    }
    // final box = contex.findRenderObject() as RenderBox;
    // return box.size.height;
    return contex.size!.height;
  }

  void _animationStatusListener(AnimationStatus status) {
    log.debug("relay:${widget.relayNotification}"
        " animation state changed:$_lastAnimationStatus -> $status");
    widget.onAnimationStatusChanged?.call(_lastAnimationStatus, status);
    _lastAnimationStatus = status;
  }

  bool _dragEventListener() {
    final event = widget.dragNotifier!.value;
    final height = event.height;
    switch (event.type) {
      case AnimatedSizedPanelDragEventType.init:
        return false;
      case AnimatedSizedPanelDragEventType.start:
        log.debug("Drag Start:$height");
        _startDragPos = height!;
        _currentSizeRate = _animationController.value;
        _quickScroll = 0;
        _canceledNext = false;
        _dragEventCanceled = false;
        break;
      case AnimatedSizedPanelDragEventType.end:
        log.debug("Drag End: canceled:$_dragEventCanceled height:$height");
        if (_dragEventCanceled) return true;
        if (_quickScroll > 0) {
          _animationController.reverse();
        } else if (_quickScroll < 0) {
          _animationController.forward();
        } else if (_animationController.value < 0.5) {
          _animationController.reverse();
        } else {
          _animationController.forward();
        }
        break;
      case AnimatedSizedPanelDragEventType.update:
        if (event.cancel) _dragEventCanceled = true;
        if (_dragEventCanceled) return true;
        // log.debug("relay:${widget.relayNotification}"
        // ", panel height:$_panelHeight");
        // log.debug("Drag Update: "
        //     "delta: ${details.delta}, "
        //     "primaryDelta: ${details.primaryDelta}, "
        //     "globalPosition: ${details.globalPosition}, "
        //     "localPosition: ${details.localPosition}, ");
        if (event.delta! > 5) _quickScroll = 1;
        if (event.delta! < -5) _quickScroll = -1;
        _endDragPos = height!;
        final off = _endDragPos - _startDragPos;

        log.debug(
            "Drag Update: canceled:$_dragEventCanceled off:$off, value:${_animationController.value}");
        //relay notification when draw down and the size is zero
        if (off > 0 && _animationController.value == 0) break;
        if (off < 0 && _animationController.value == 1) break;

        final rate = off / _panelHeight;
        _animationController.value = _currentSizeRate - rate;

        if (!_canceledNext && widget.relayNotification) {
          event.cancel = true;
          _canceledNext = true;
          return true;
        }
        // log.debug("return false");
        return false;
    }

    if (widget.relayNotification) return true;
    return false;
  }

  void _animationCtrl() {
    final currentStatus = _animationController.status;
    final currentValue = _animationController.value;
    if (widget.show) {
      if (currentStatus == AnimationStatus.forward) return;
      if (currentValue == 1) return;
      Timer.run(() {
        _animationController.forward();
      });
    } else {
      if (currentStatus == AnimationStatus.reverse) return;
      if (currentValue == 0) return;
      Timer.run(() {
        _animationController.reverse();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _animationCtrl();
    return NotificationListener(
      onNotification: ((notification) {
        final height = _calculatePanelHeight(_panelKey);
        log.debug("panel size changed:$height");
        widget.onHeightChanged?.call(height);
        return true;
      }),
      child: SizeChangedLayoutNotifier(
        child: SizeTransition(
          key: _panelKey,
          axisAlignment: -1,
          sizeFactor: _sizeAnimation,
          child: NotificationListener(
            onNotification: ((notification) {
              Timer.run(() {
                final height = _calculatePanelHeight(_originalPanelKey);
                log.debug("original panel size changed:$height");
                _panelHeight = height;
              });
              return true;
            }),
            child: SizeChangedLayoutNotifier(
                key: _originalPanelKey, child: widget.child),
          ),
        ),
      ),
    );
  }
}

enum AnimatedSizedPanelDragEventType {
  start,
  end,
  update,
  init,
}

class AnimatedSizedPanelDragEvent {
  final AnimatedSizedPanelDragEventType type;
  final double? height;
  final double? delta;
  var cancel = false;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AnimatedSizedPanelDragEvent) return false;
    return runtimeType == other.runtimeType &&
        height == other.height &&
        delta == other.delta &&
        type == other.type;
  }

  @override
  int get hashCode => type.hashCode + super.hashCode;

  AnimatedSizedPanelDragEvent(this.type, {this.height, this.delta});

  static AnimatedSizedPanelDragEvent fromDragStartEvent(
      DragStartDetails details) {
    return AnimatedSizedPanelDragEvent(AnimatedSizedPanelDragEventType.start,
        height: details.localPosition.dy);
  }

  static AnimatedSizedPanelDragEvent fromDragEndEvent(DragEndDetails details) {
    return AnimatedSizedPanelDragEvent(AnimatedSizedPanelDragEventType.end);
  }

  static AnimatedSizedPanelDragEvent fromDragUpdateEvent(
      DragUpdateDetails details) {
    return AnimatedSizedPanelDragEvent(AnimatedSizedPanelDragEventType.update,
        height: details.localPosition.dy, delta: details.delta.dy);
  }
}
