import 'package:flutter/painting.dart';

class WaveformData {
  int? channels;
  // original sample rate
  int? sampleRate;
  // indicates how many original samples have been analyzed per frame. 256 samples -> frame of min/max
  int? waveformSampleRate;
  // bit depth of the data
  int? bits;
  // the number of frames contained in the data
  List<double> data;
  double dx;

  WaveformData(this.data, this.dx,
      {this.channels = 1,
      this.sampleRate = 44100,
      this.waveformSampleRate = 100,
      this.bits = 16});

  // factory WaveformData.fromJson(String str) =>
  //     WaveformData.fromMap(json.decode(str));

  // String toJson() => json.encode(toMap());

  // factory WaveformData.fromMap(Map<String, dynamic> json) => WaveformData(
  //       version: json["version"],
  //       channels: json["channels"],
  //       sampleRate: json["sample_rate"],
  //       samplePerPixel: json["samples_per_pixel"],
  //       bits: json["bits"],
  //       length: json["length"],
  //       data: List<int>.from(json["data"].map((x) => x)),
  //     );

  // Map<String, dynamic> toMap() => {
  //       "version": version,
  //       "channels": channels,
  //       "sample_rate": sampleRate,
  //       "samples_per_pixel": samplePerPixel,
  //       "bits": bits,
  //       "length": length,
  //       "data": List<dynamic>.from(data!.map((x) => x)),
  //     };

  // // get the frame position at a specific percent of the waveform. Can use a 0-1 or 0-100 range.
  // int frameIdxFromPercent(double percent) {
  //   // if (percent == null) {
  //   //   return 0;
  //   // }

  //   // if the scale is 0-1.0
  //   if (percent < 0.0) {
  //     percent = 0.0;
  //   } else if (percent > 100.0) {
  //     percent = 100.0;
  //   }

  //   if (percent > 0.0 && percent < 1.0) {
  //     return ((data!.length.toDouble() / 2) * percent).floor();
  //   }

  //   int idx = ((data!.length.toDouble() / 2) * (percent / 100)).floor();
  //   final maxIdx = (data!.length.toDouble() / 2 * 0.98).floor();
  //   if (idx > maxIdx) {
  //     idx = maxIdx;
  //   }
  //   return idx;
  // }
  int frameIdxFromPercent(double percent) {
    return 1;
  }

  Path path(Size size) {
    final middle = size.height / 2;
    final path = Path();
    List<Offset> minPoints = [];
    List<Offset> maxPoints = [];

    path.moveTo(0, middle);

    if (data.isEmpty) {
      path.lineTo(size.width, middle);
      path.lineTo(0, middle);
      path.close();
      return path;
    }

    for (var i = 0, len = data.length; i < len; i++) {
      var d = data[i];

      if (i % 2 != 0) {
        minPoints.add(Offset(dx * i, middle - middle * d));
      } else {
        maxPoints.add(Offset(dx * i, middle - middle * d));
      }
    }

    for (var o in maxPoints) {
      path.lineTo(o.dx, o.dy);
    }
    // back to zero
    path.lineTo(size.width, middle);
    // draw the minimums backwards so we can fill the shape when done.
    for (var o in minPoints.reversed) {
      path.lineTo(o.dx, middle - (middle - o.dy));
    }

    path.close();
    return path;
  }
}
