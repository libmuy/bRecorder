import 'package:brecorder/domain/abstract_repository.dart';
import 'package:equatable/equatable.dart';

class AudioObject extends Equatable {
  final Repository? repo;
  String path;
  final int bytes;
  final DateTime timestamp;
  Future<String> get realPath async {
    if (repo == null) {
      return path;
    }
    return await repo!.absolutePath(path);
  }

  AudioObject(this.path, this.bytes, this.timestamp, {this.repo});

  @override
  List<Object> get props => [path, bytes, timestamp];
}

class AudioInfo extends AudioObject {
  final int durationMS;
  int currentPosition;

  AudioInfo(this.durationMS, String path, int bytes, DateTime timestamp,
      {this.currentPosition = 0, Repository? repo})
      : super(path, bytes, timestamp, repo: repo);

  @override
  List<Object> get props => [durationMS, path, bytes, timestamp];
}

class FolderInfo extends AudioObject {
  final List<FolderInfo> subfolders;
  final List<AudioInfo> audios;
  final int audioCount;

  FolderInfo(String path, int bytes, DateTime timestamp, this.subfolders,
      this.audios, this.audioCount,
      {Repository? repo})
      : super(path, bytes, timestamp, repo: repo);

  static FolderInfo get empty {
    return FolderInfo(
      "",
      0,
      DateTime(1907),
      List.empty(),
      List.empty(),
      0,
    );
  }

  @override
  List<Object> get props =>
      [path, bytes, timestamp, subfolders, audios, audioCount];
}
