import 'package:equatable/equatable.dart';

class FilesystemObject extends Equatable {
  final String path;

  const FilesystemObject(this.path);

  @override
  List<Object> get props => [path];
}

class AudioInfo extends FilesystemObject {
  final int durationMS;

  const AudioInfo(this.durationMS, path) : super(path);

  @override
  List<Object> get props => [durationMS, path];
}

class FolderInfo extends FilesystemObject {
  final List<FolderSimpleInfo> subfolders;
  final List<AudioInfo> audios;

  const FolderInfo(path, this.subfolders, this.audios) : super(path);
}

class FolderSimpleInfo extends FilesystemObject {
  const FolderSimpleInfo(path) : super(path);
}
