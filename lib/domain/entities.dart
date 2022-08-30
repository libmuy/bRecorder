import 'package:equatable/equatable.dart';

class AudioObject extends Equatable {
  final String path;
  final int bytes;
  final DateTime timestamp;

  const AudioObject(this.path, this.bytes, this.timestamp);

  @override
  List<Object> get props => [path, bytes, timestamp];
}

class AudioInfo extends AudioObject {
  final int durationMS;

  const AudioInfo(this.durationMS, String path, int bytes, DateTime timestamp)
      : super(path, bytes, timestamp);

  @override
  List<Object> get props => [durationMS, path, bytes, timestamp];
}

class FolderInfo extends AudioObject {
  final List<FolderInfo> subfolders;
  final List<AudioInfo> audios;

  const FolderInfo(
      String path, int bytes, DateTime timestamp, this.subfolders, this.audios)
      : super(path, bytes, timestamp);

  @override
  List<Object> get props => [path, bytes, timestamp, subfolders, audios];
}
