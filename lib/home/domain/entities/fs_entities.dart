import 'package:equatable/equatable.dart';

class FsEntity extends Equatable {
  final String path;

  const FsEntity(this.path);

  @override
  List<Object> get props => [path];
}

class AudioInfo extends FsEntity {
  final int durationMS;

  const AudioInfo(this.durationMS, path) : super(path);

  @override
  List<Object> get props => [durationMS, path];
}

class FolderInfo extends FsEntity {
  final List<FolderSimpleInfo> subfolders;
  final List<AudioInfo> audios;

  const FolderInfo(path, this.subfolders, this.audios) : super(path);
}

class FolderSimpleInfo extends FsEntity {
  const FolderSimpleInfo(path) : super(path);
}
