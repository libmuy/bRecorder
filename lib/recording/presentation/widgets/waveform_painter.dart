import 'package:brecorder/core/logging.dart';
import 'package:flutter/material.dart';

final log = Logger('WaveForm');

class WaveformPainter extends CustomPainter {
  Paint painter = Paint();
  final Color color;
  final double strokeWidth;
  List<double> data;
  double dx;
  double startX;
  int fromIndex;

  WaveformPainter(this.data, this.dx, this.startX,
      {this.strokeWidth = 10.0, this.color = Colors.blue, this.fromIndex = 0}) {
    painter = Paint()
      ..style = PaintingStyle.fill
      ..color = color
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = getNewMidPath(size);
    canvas.drawPath(path, painter);
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    if (oldDelegate.data != data) {
      // debugPrint("Redrawing");
      return true;
    }
    return false;
  }

  Path getNewMidPath(Size size) {
    final middle = size.height / 2;
    final path = Path();
    double max = 0.012;

    if (data.isEmpty) {
      log.debug("no data draw a line");
      path.moveTo(0, middle);
      path.lineTo(size.width, middle);
      path.lineTo(0, middle);
      path.close();

      return path;
    }

    for (var d in data) {
      if (max < d) max = d;
    }

    final drawData = data.sublist(fromIndex);
    path.moveTo(startX, middle);
    for (var i = 0; i < drawData.length; i++) {
      path.lineTo(startX + (i * dx), middle - (middle * drawData[i] / max));
    }
    for (var i = drawData.length - 1; i >= 0; i--) {
      path.lineTo(startX + (i * dx), middle + (middle * drawData[i] / max));
    }

    path.close();
    return path;
  }

  Path getMidPath(Size size) {
    final middle = size.height / 2;
    final path = Path();
    List<Offset> minPoints = [];
    List<Offset> maxPoints = [];
    List<Offset> midPoints = [];
    double min = -0.1;
    double max = 0.1;

    if (data.isEmpty) {
      log.debug("no data draw a line");
      path.moveTo(0, middle);
      path.lineTo(size.width, middle);
      path.lineTo(0, middle);
      path.close();

      return path;
    }

    for (var d in data) {
      if (min > d) min = d;
      if (max < d) max = d;
    }

    final drawData = data.sublist(fromIndex);
    // log.debug("drawing waveform:$drawData");
    for (var i = 0; i < drawData.length; i++) {
      var d = drawData[i];
      if (d > 0) {
        d = d / max;
      } else if (d < 0) {
        d = d / min.abs();
      }

      if (i % 2 != 0) {
        minPoints.add(Offset(dx * i, d));
      } else {
        maxPoints.add(Offset(dx * i, d));
      }
    }

    for (var i = 0; i < minPoints.length; i++) {
      final diff = maxPoints[i].dy - minPoints[i].dy;
      midPoints.add(Offset(maxPoints[i].dx, diff / 2));
    }

    path.moveTo(startX, middle);
    for (var o in midPoints) {
      path.lineTo(startX + o.dx, middle - (middle * o.dy));
    }
    // back to zero
    path.lineTo(size.width, middle);
    // draw the minimums backwards so we can fill the shape when done.
    final rev = midPoints.reversed;
    // final rev = maxPoints.reversed;
    for (var o in rev) {
      // final y = middle - (middle - o.dy);
      path.lineTo(startX + o.dx, middle + (middle * o.dy));
      // path.lineTo(startX + o.dx, middle - (o.dy - middle));
    }

    // log.debug("min points:$minPoints");
    // log.debug("max points:$maxPoints");

    path.close();
    return path;
  }

  Path getPath(Size size) {
    final middle = size.height / 2;
    final path = Path();
    List<Offset> minPoints = [];
    List<Offset> maxPoints = [];
    double min = -0.1;
    double max = 0.1;

    if (data.isEmpty) {
      log.debug("no data draw a line");
      path.moveTo(0, middle);
      path.lineTo(size.width, middle);
      path.lineTo(0, middle);
      path.close();

      return path;
    }

    for (var d in data) {
      if (min > d) min = d;
      if (max < d) max = d;
    }

    List<double> points = [];
    final drawData = data.sublist(fromIndex);
    // log.debug("drawing waveform:$drawData");
    for (var i = 0; i < drawData.length; i++) {
      var d = drawData[i];
      if (d > 0) {
        d = d / max;
      } else if (d < 0) {
        d = d / min.abs();
      }
      points.add(d);
      // log.debug("d:${data[i]} -> $d");
      if (i % 2 != 0) {
        minPoints.add(Offset(dx * i, middle + (middle * d)));
      } else {
        maxPoints.add(Offset(dx * i, middle + (middle * d)));
      }
    }
    // var printPoints1 = "";
    // var printPoints2 = "";
    // for (var i = 0; i < points.length; i++) {
    //   final d = points[i].toStringAsFixed(4).padLeft(7);
    //   if (i % 2 != 0) {
    //     printPoints1 = "$printPoints1, $d";
    //   } else {
    //     printPoints2 = "$printPoints2, $d";
    //   }
    // }
    // log.debug("drawing min points:($printPoints1)");
    // log.debug("drawing max points:($printPoints2)");
    // log.debug("draw waveform from:$startX");
    path.moveTo(startX, middle);
    for (var o in maxPoints) {
      path.lineTo(startX + o.dx, o.dy);
    }
    // back to zero
    path.lineTo(size.width, middle);
    // draw the minimums backwards so we can fill the shape when done.
    final rev = minPoints.reversed;
    // final rev = maxPoints.reversed;
    for (var o in rev) {
      // final y = middle - (middle - o.dy);
      path.lineTo(startX + o.dx, o.dy);
      // path.lineTo(startX + o.dx, middle - (o.dy - middle));
    }

    // log.debug("min points:$minPoints");
    // log.debug("max points:$maxPoints");

    path.close();
    return path;
  }
}
