import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../data/repository.dart';

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

enum GlobalMode {
  normal,
  edit,
  playback,
}

enum PlayLoopType {
  noLoop(0, "", Icons.repeat),
  list(1, "List", Icons.low_priority),
  loopOne(2, "One", Icons.repeat_one),
  loopAll(3, "All", Icons.repeat),
  shuffle(4, "Shuffle", Icons.shuffle);

  const PlayLoopType(this.doubleValue, this.label, this.icon);

  final double doubleValue;
  final String label;
  final IconData icon;
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

class TabInfo {
  String currentPath;
  RepoType repoType;
  bool enabled;

  TabInfo({
    this.currentPath = "/",
    this.enabled = true,
    required this.repoType,
  });

  factory TabInfo.fromJson(Map<String, String> json) {
    return TabInfo(
      currentPath: json['currentPath']!,
      repoType: RepoType.fromString(json['repoType']!),
      enabled: json['enabled']!.toLowerCase() == "true",
    );
  }
  Map<String, dynamic> toJson() => {
        'currentPath': currentPath,
        'repoType': repoType,
        'enabled': enabled,
      };
}
