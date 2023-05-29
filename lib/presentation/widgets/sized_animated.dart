import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/logging.dart';

final log = Logger('SizedAnimated');

class SizedAnimated extends StatefulWidget {
  final Widget child;
  final bool? show;
  final ValueNotifier<bool>? showNotifier;
  final EdgeInsets? padding;

  const SizedAnimated({
    Key? key,
    required this.child,
    this.show,
    this.showNotifier,
    this.padding,
  }) : super(key: key);

  @override
  State<SizedAnimated> createState() => _SizedAnimatedState();
}

class _SizedAnimatedState extends State<SizedAnimated>
    with TickerProviderStateMixin {
  bool lastShowState = false;
  late final AnimationController _animationController;
  late final Animation<double> _animation;

  @override
  void initState() {
    assert(widget.showNotifier != null || widget.show != null);
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildWidget(BuildContext context, bool show) {
    //Initial state: not showing
    if (!lastShowState && !show) return Container();

    if (!lastShowState && show) {
      Timer.run(
        () => _animationController.forward(),
      );
    } else if (lastShowState && !show) {
      Timer.run(
        () => _animationController.reverse(),
      );
    } else if (lastShowState && show) {}
    lastShowState = show;
    return SizeTransition(
        // key: _bottomPanelKey,
        axisAlignment: -1,
        sizeFactor: _animation,
        child: Padding(
          padding: widget.padding ?? const EdgeInsets.only(bottom: 5, top: 5),
          child: widget.child,
        ));
  }

  @override
  Widget build(context) {
    if (widget.showNotifier != null) {
      return ValueListenableBuilder<bool>(
          valueListenable: widget.showNotifier!,
          builder: (context, show, _) {
            return _buildWidget(context, show);
          });
    }

    return _buildWidget(context, widget.show!);
  }
}
