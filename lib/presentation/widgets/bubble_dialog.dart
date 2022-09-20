import 'package:flutter/material.dart';

class BubbleDialog extends StatefulWidget {
  final Widget child;
  final Offset position;
  final EdgeInsets padding;
  final double elevation;
  final Radius borderRadius;
  final Color? color;
  final double markWidth;
  final double markHeight;
  final double sideMargin;

  const BubbleDialog({
    Key? key,
    this.markHeight = 12,
    this.markWidth = 10,
    required this.position,
    required this.child,
    this.elevation = 10,
    this.sideMargin = 15,
    this.color,
    this.borderRadius = const Radius.circular(8),
    this.padding = const EdgeInsets.all(15),
  }) : super(key: key);

  @override
  State createState() => _BubbleDialogState();
}

class _BubbleDialogState extends State<BubbleDialog> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: widget.sideMargin,
          right: widget.sideMargin,
          bottom: MediaQuery.of(context).size.height - widget.position.dy,
          child: Material(
              color: widget.color,
              clipBehavior: Clip.antiAlias,
              shape: BubbleBorder(
                  markHeight: widget.markHeight,
                  markWidth: widget.markWidth,
                  borderRadius: widget.borderRadius,
                  markPositionX: widget.position.dx - widget.sideMargin),
              elevation: widget.elevation,
              child: Container(
                  width: MediaQuery.of(context).size.width,
                  padding: widget.padding.copyWith(
                      bottom: widget.padding.bottom + widget.markHeight),
                  child: widget.child)),
        ),
        // child: Container(
        //     width: MediaQuery.of(context).size.width,
        //     padding: widget.padding,
        //     decoration: ShapeDecoration(
        //       color: widget.color,
        //       shadows: [
        //         BoxShadow(
        //           color: Colors.black.withOpacity(0.5),
        //           offset: const Offset(0, 2),
        //           blurRadius: 2,
        //         )
        //       ],
        //       shape: BubbleBorder(
        //           borderRadius: widget.borderRadius,
        //           markPositionX: widget.position.dx),
        //     ),
        //     child: widget.child)),

        // Positioned(
        //     left: widget.position.dx - 5,
        //     top: widget.position.dy - 5,
        //     child: Container(
        //       width: 10,
        //       height: 10,
        //       color: Colors.blue,
        //     ))
      ],
    );
  }
}

class BubbleBorder extends ShapeBorder {
  static const double _minMarkPositionX = 20;
  final bool usePadding;
  final Radius borderRadius;
  final double markWidth;
  final double markHeight;
  final double markPositionX;

  const BubbleBorder({
    this.usePadding = true,
    required this.borderRadius,
    this.markHeight = 12,
    this.markWidth = 10,
    this.markPositionX = 20,
  });

  @override
  EdgeInsetsGeometry get dimensions =>
      EdgeInsets.only(bottom: usePadding ? markHeight : 0);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..addRRect(RRect.fromRectAndRadius(rect, borderRadius))
      ..close();
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    var markX = markPositionX;
    if (markX > _minMarkPositionX) markX = _minMarkPositionX;

    final r =
        Rect.fromPoints(rect.topLeft, rect.bottomRight - const Offset(0, 12));
    return Path()
      ..addRRect(RRect.fromRectAndRadius(r, borderRadius))
      ..moveTo(markPositionX - markWidth, r.bottomCenter.dy)
      ..relativeLineTo(markWidth, markHeight)
      ..relativeLineTo(markWidth, -markHeight)
      ..close();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}

Future<void> showBubbleDialog(
  BuildContext context, {
  Color? color,
  Duration duration = const Duration(milliseconds: 300),
  required Widget dialog,
  required Offset position,
}) async {
  await Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: duration,
        reverseTransitionDuration: duration,
        barrierDismissible: true,
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) {
          return BubbleDialog(
              color: color ?? Theme.of(context).primaryColor,
              position: position,
              child: dialog);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var tween =
              Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.ease));

          return FadeTransition(
            opacity: animation.drive(tween),
            child: child,
          );
        },
      ));
}
