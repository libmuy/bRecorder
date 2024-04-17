import 'dart:io';

import 'package:brecorder/domain/entities.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/repository.dart';
import '../service_locator.dart';

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
  FolderInfo? currentFolder;
  RepoType repoType;
  bool enabled;

  String get currentPath => currentFolder == null ? '/' : currentFolder!.path;

  TabInfo({
    this.enabled = true,
    required this.repoType,
  });

  String get title => repoType.title;

  factory TabInfo.fromJson(Map<String, dynamic> json) {
    final tab = TabInfo(
      repoType: RepoType.fromString(json['repoType']!),
      enabled: json['enabled']!.toLowerCase() == "true",
    );
    Map<String, dynamic> folderCache = json['folderCache'];
    final folder = FolderInfo.fromJson(folderCache['root']);

    //sub folders map
    List<Map<String, dynamic>>? subFoldersList = folderCache['subFolders'];
    if (subFoldersList != null) {
      final subFolders =
          subFoldersList.map((json) => FolderInfo.fromJson(json));
      final subFolderKeys = subFolders.map((f) => f.mapKey);
      folder.subfoldersMap = Map.fromIterables(subFolderKeys, subFolders);
    }

    //sub audios map
    List<Map<String, dynamic>>? subAudiosList = folderCache['subAudios'];
    if (subAudiosList != null) {
      final subAudios = subAudiosList.map((json) => AudioInfo.fromJson(json));
      final subAudioKeys = subAudios.map((a) => a.mapKey);
      folder.audiosMap = Map.fromIterables(subAudioKeys, subAudios);
    }

    tab.currentFolder = folder;
    return tab;
  }
  Map<String, dynamic> toJson() => {
        'repoType': repoType.toString(),
        'enabled': enabled ? 'true' : 'false',
        'folderCache': {
          'root': currentFolder,
          'subFolders': currentFolder!.subfolders,
          'subAudios': currentFolder!.audios,
        }
      };
}

class PathProvider {
  static Future<String> _createAndReturnPath(
      Future<Directory?> base, String sub) async {
    final docDir = await base;
    final dir = join(docDir!.path, sub);
    await Directory(dir).create(recursive: true);
    return dir;
  }

  static Future<Directory?> get _docDir => Platform.isIOS
      ? getApplicationDocumentsDirectory()
      : getExternalStorageDirectory();

  static Future<Directory?> get _appDataDir => Platform.isIOS
      ? getApplicationSupportDirectory()
      : getApplicationDocumentsDirectory();

  static Future<String> get localStoragePath =>
      _createAndReturnPath(_docDir, "bRecorder");

  static Future<String> get waveformPath =>
      _createAndReturnPath(_appDataDir, "bRecorder/waveform");

  static Future<String> get googleDrivePath =>
      _createAndReturnPath(_appDataDir, "bRecorder/googleDrive");

  static Future<String> get iCloudPath =>
      _createAndReturnPath(_appDataDir, "bRecorder/iCloudDrive");
}

void showSnackBar(Widget content) {
  sl.messageState.currentState!.showSnackBar(SnackBar(content: content));
}
