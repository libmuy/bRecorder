import 'package:equatable/equatable.dart';

class AudioObject extends Equatable {
  final String path;

  const AudioObject(this.path);

  @override
  List<Object> get props => [path];
}

class AudioInfo extends AudioObject {
  final int durationMS;

  const AudioInfo(this.durationMS, path) : super(path);

  @override
  List<Object> get props => [durationMS, path];
}

class FolderInfo extends AudioObject {
  final List<FolderSimpleInfo> subfolders;
  final List<AudioInfo> audios;

  const FolderInfo(path, this.subfolders, this.audios) : super(path);
}

class FolderSimpleInfo extends AudioObject {
  const FolderSimpleInfo(path) : super(path);
}
