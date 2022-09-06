import 'package:equatable/equatable.dart';

enum RecordState {
  stopped,
  recording,
  paused,
}

enum PlaybackState {
  stopped,
  playing,
  paused,
}

class AudioPositionInfo extends Equatable {
  /// Unit: Seconds
  final double duration;

  /// Unit: Seconds
  final double position;

  @override
  List<Object> get props => [duration, position];

  const AudioPositionInfo(this.duration, this.position);
}
