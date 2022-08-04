import 'package:brecorder/core/logging.dart';
import 'package:flutter/cupertino.dart';

final log = Logger('WaveForm');

class _ScrollPosition extends ScrollPositionWithSingleContext {
  bool scaling;

  _ScrollPosition({
    required ScrollPhysics physics,
    required ScrollContext context,
    double? initialPixels = 0.0,
    bool keepScrollOffset = true,
    ScrollPosition? oldPosition,
    String? debugLabel,
    this.scaling = false,
  }) : super(
          physics: physics,
          context: context,
          keepScrollOffset: keepScrollOffset,
          oldPosition: oldPosition,
          debugLabel: debugLabel,
        );

  @override
  void jumpTo(double value) {
    // goIdle();
    if (pixels != value) {
      final double oldPixels = pixels;
      correctPixels(value);
      // didStartScroll();
      // didUpdateScrollPositionBy(pixels - oldPixels);
      // didEndScroll();
      log.debug("jumpto2");
    }
    // goBallistic(0.0);
  }

  @override
  void goBallistic(double velocity) {
    if (scaling) {
      return;
    }
    log.debug("ballistic2:$scaling");
    assert(hasPixels);
    final Simulation? simulation =
        physics.createBallisticSimulation(this, velocity);
    if (simulation != null) {
      beginActivity(BallisticScrollActivity(this, simulation, context.vsync));
    } else {
      goIdle();
    }
  }
}

class WaveformScrollController extends ScrollController {
  bool _scaling = false;
  @override
  void attach(ScrollPosition position) {
    super.attach(position);
    log.debug("attached the scrollposition");
  }

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _ScrollPosition(
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
      scaling: _scaling,
    );
  }

  void scaleStart() {
    log.debug("set scale to true");
    _scaling = true;
  }

  void scaleStop() {
    log.debug("set scale to false");
    _scaling = false;
  }
}
