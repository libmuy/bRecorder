import 'package:flutter/material.dart';

import '../../../core/logging.dart';

final _log = Logger('WaveForm');

class WaveformPainter extends CustomPainter {
  Paint painter = Paint();
  final Color color;
  final double strokeWidth;
  List<double> data;
  double dx;
  double startX;
  int fromIndex;
  // bool painterRuler;

  WaveformPainter(
    this.data,
    this.dx,
    this.startX, {
    this.strokeWidth = 10.0,
    this.color = Colors.blue,
    this.fromIndex = 0,
    // this.painterRuler = false,
  }) {
    painter = Paint()
      ..style = PaintingStyle.fill
      ..color = color
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = getWaveformPath(size);
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

  Path getWaveformPath(Size size) {
    final middle = size.height / 2;
    final path = Path();
    double max = 0.012;

    if (data.isEmpty) {
      _log.debug("no data draw a line");
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

    // if (painterRuler) {
    //   final height = size.height / 6;
    //   final width = 1;
    //   final scale = 10;
    //   for (var i = 0; i < drawData.length / scale; i++) {
    //     path.lineTo(startX + (i * dx * scale) - (width / 2), size.height);
    //     path.lineTo(
    //         startX + (i * dx * scale) - (width / 2), size.height - height);
    //     path.lineTo(
    //         startX + (i * dx * scale) + (width / 2), size.height - height);
    //     path.lineTo(startX + (i * dx * scale) + (width / 2), size.height);
    //   }

    //   path.lineTo(0, size.height);
    // }
    path.close();
    return path;
  }
}
