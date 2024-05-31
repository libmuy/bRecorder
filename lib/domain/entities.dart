import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:googleapis/youtube/v3.dart';
import 'package:path/path.dart';

import '../core/global_info.dart';
import '../core/logging.dart';
import '../core/service_locator.dart';
import '../core/utils/utils.dart';
import '../data/google_drive_repository.dart';
import '../data/repository.dart';
import '../presentation/widgets/audio_list_item/audio_widget_state.dart';

const _prefKeyNextAudioId = "nextAudioId";

final _log = Logger('Entity');

/*=======================================================================*\ 
  Audio Object Equatable (copy from equatable)
\*=======================================================================*/
abstract class AudioEqual {
  /// Returns a `hashCode` for [props].
  int mapPropsToHashCode(Iterable? props) =>
      _finish(props == null ? 0 : props.fold(0, _combine));

  List<Object?> get props;

  /// Jenkins Hash Functions
  /// https://en.wikipedia.org/wiki/Jenkins_hash_function
  int _combine(int hash, dynamic object) {
    if (object is Map) {
      object.keys
          .sorted((dynamic a, dynamic b) => a.hashCode - b.hashCode)
          .forEach((dynamic key) {
        hash = hash ^ _combine(hash, <dynamic>[key, object[key]]);
      });
      return hash;
    }
    if (object is Iterable) {
      for (final value in object) {
        hash = hash ^ _combine(hash, value);
      }
      return hash ^ object.length;
    }

    hash = 0x1fffffff & (hash + object.hashCode);
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  int _finish(int hash) {
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }

  bool equals(List? list1, List? list2) {
    if (identical(list1, list2)) return true;
    if (list1 == null || list2 == null) return false;
    final length = list1.length;
    if (length != list2.length) return false;

    for (var i = 0; i < length; i++) {
      final dynamic unit1 = list1[i];
      final dynamic unit2 = list2[i];

      if (unit1 is AudioInfo && unit2 is AudioInfo) {
        if (unit1 != unit2) return false;
      } else if (unit1?.runtimeType != unit2?.runtimeType) {
        return false;
      } else if (unit1 != unit2) {
        return false;
      }
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Equatable &&
          runtimeType == other.runtimeType &&
          equals(props, other.props);

  @override
  int get hashCode => runtimeType.hashCode ^ mapPropsToHashCode(props);
}

/*=======================================================================*\ 
  Audio Object
\*=======================================================================*/
class AudioObject extends AudioEqual {
  Repository? repo;
  String path;
  int? bytes;
  DateTime? timestamp;
  FolderInfo? parent;
  AudioWidgetState? displayData;
  CloudFileData? cloudData;
  AudioObject? copyFrom;

  void updateUI() => displayData?.updateWidget?.call();

  String get name => basename(path);

  Future<String> get realPath async {
    if (repo == null) {
      return path;
    }
    return await repo!.absolutePath(path);
  }

  void updatePath(Repository newRepo, String newPath) {
    path = newPath;
    repo = newRepo;
  }

  void destory() {}

  String get mapKey => basename(path);
  AudioObject(this.path,
      {this.bytes, this.timestamp, this.repo, this.parent, this.displayData});

  @override
  List<Object?> get props => [path, bytes, timestamp];

  void _dumpAudioObject(int lv, AudioObject obj) {
    var indent = " " * (lv * 4);
    final type = obj is FolderInfo ? "+" : " ";
    final name = obj.mapKey;
    debugPrint("$indent $type$name");
    if (obj is FolderInfo) {
      for (var e in obj.subObjects) {
        _dumpAudioObject(lv + 1, e);
      }
    }
  }

  void dump() {
    _dumpAudioObject(0, this);
  }
}

/*=======================================================================*\ 
  Audio Information
\*=======================================================================*/
class FileObject extends AudioObject {
  FileObject(super.path,
      {super.bytes,
      super.timestamp,
      super.repo,
      super.parent,
      super.displayData});

  Future<File> get file async => File(await realPath);
}

/*=======================================================================*\ 
  Audio Information
\*=======================================================================*/
class AudioInfo extends FileObject {
  int? _prefId;
  int? durationMS;
  int currentPosition;
  bool broken;
  AudioPref? _pref;
  Float32List? get _waveformData => displayData?.waveformData;
  set _waveformData(Float32List? newValue) =>
      displayData?.waveformData = newValue;
  void Function()? get onPlayStopped => displayData?.onPlayStopped;
  void Function()? get onPlayPaused => displayData?.onPlayPaused;
  void Function()? get onPlayStarted => displayData?.onPlayStarted;

  AudioInfo(super.path,
      {this.durationMS,
      super.bytes,
      super.timestamp,
      this.currentPosition = 0,
      this.broken = false,
      super.repo,
      super.parent,
      super.displayData});

  @override
  List<Object?> get props => [durationMS, path, bytes, timestamp];

  @override
  void updatePath(Repository newRepo, String newPath) async {
    if (!await hasPerf) {
      super.updatePath(newRepo, newPath);
      return;
    } else {
      final sharedPref = await sl.asyncPref;
      final oldIdKey = _prefIdKey;
      super.updatePath(newRepo, newPath);
      final newIdKey = _prefIdKey;
      sharedPref.setInt(newIdKey, await id);
      sharedPref.remove(oldIdKey);
    }
  }

  @override
  void destory() async {
    if (!await hasPerf) return;
    final sharedPref = await sl.asyncPref;
    sharedPref.remove(await _prefKey);
    sharedPref.remove(_prefIdKey);
  }

  String get _prefIdKey {
    return "id_of_${repo!.name}$path".hashCode.toString();
  }

  Future<int> get id async {
    if (!await hasPerf) {
      final sharedPref = await sl.asyncPref;
      _prefId = sharedPref.getInt(_prefKeyNextAudioId) ?? 0;

      sl.pref.setInt(_prefKeyNextAudioId, _prefId! + 1);
      sl.pref.setInt(_prefIdKey, _prefId!);
      _log.debug("create audio($this)'s id:$_prefId");
    } else {
      _log.debug("get    audio($this)'s id:$_prefId");
    }
    return _prefId!;
  }

  Future<bool> get hasPerf async {
    if (_prefId == null) {
      final sharedPref = await sl.asyncPref;
      _prefId = sharedPref.getInt(_prefIdKey);
    }

    return _prefId != null;
  }

  Future<String> get _prefKey async {
    return "audio_${await id}";
  }

  Future<String> get _waveformPath async {
    final dir = await PathProvider.waveformPath;

    return join(dir, "${await _prefKey}.waveform");
  }

  Future<Float32List?> get waveformData async {
    if (_waveformData != null) return _waveformData!;
    final file = File(await _waveformPath);
    if (!await file.exists()) return null;
    final bin = await file.readAsBytes();
    _waveformData = bin.buffer.asFloat32List();
    return _waveformData!;
  }

  void setWaveformData(Float32List data) {
    _waveformData = data;
    _waveformPath.then((path) {
      final output = File(path);
      output.writeAsBytes(data.buffer.asUint8List());
    });
  }

  void savePref() async {
    final sharedPref = await sl.asyncPref;
    _log.debug("save perf key: ${await _prefKey}");
    _log.debug("    json: ${jsonEncode(await pref)}");
    sharedPref.setString(await _prefKey, jsonEncode(await pref));
  }

  Future<AudioPref> get pref async {
    final sharedPref = await sl.asyncPref;
    if (_pref != null) return _pref!;
    final prefStr = sharedPref.getString(await _prefKey);
    if (prefStr != null) {
      _log.debug("Perf: restored");
      _pref = AudioPref.fromJson(jsonDecode(prefStr));
    } else {
      _log.debug("Perf: create new");
      _pref = AudioPref();
      savePref();
    }
    return _pref!;
  }

  AudioInfo copyWith(
      {String? path,
      int? bytes,
      DateTime? timestamp,
      Repository? repo,
      int? durationMS,
      int? currentPosition,
      FolderInfo? parent,
      displayData}) {
    var audio = AudioInfo(
      durationMS: durationMS ?? this.durationMS,
      path ?? this.path,
      bytes: bytes ?? this.bytes,
      timestamp: timestamp ?? this.timestamp,
      repo: repo ?? this.repo,
      currentPosition: currentPosition ?? this.currentPosition,
      parent: parent ?? this.parent,
    );

    audio.cloudData = cloudData;
    audio.copyFrom = this;
    return audio;
  }

  static AudioInfo brokenAudio(
      {int durationMS = 0,
      String path = "",
      int bytes = 0,
      DateTime? timestamp,
      Repository? repo}) {
    return AudioInfo(path,
        durationMS: durationMS,
        bytes: bytes,
        timestamp: timestamp ?? DateTime(1970),
        broken: true,
        repo: repo);
  }

  @override
  String toString() => basename(path);

  factory AudioInfo.fromJson(Map<String, dynamic> json) {
    return AudioInfo(json['path'],
        durationMS: json['durationMS'],
        bytes: json['bytes'],
        timestamp: DateTime.parse(json['timestamp']),
        repo: sl.getRepository(RepoType.fromString(json['repoType'])));
  }
  Map<String, dynamic> toJson() => {
        'path': path,
        'durationMS': durationMS,
        'bytes': bytes,
        'timestamp': timestamp,
        'repoType': repo!.type.toString()
      };
}

/*=======================================================================*\ 
  Folder Information
\*=======================================================================*/
class FolderInfo extends AudioObject {
  Map<String, FolderInfo>? subfoldersMap;
  Map<String, AudioInfo>? audiosMap;
  Map<String, PlaylistInfo>? playlistMap;
  int? allAudioCount;

  List<AudioObject> get subObjects {
    List<AudioObject> ret;
    if (subfoldersMap == null) {
      ret = [];
    } else {
      // ignore: unnecessary_cast
      ret = subfolders!.map((e) => e as AudioObject).toList();
    }

    if (audios != null) {
      ret += audios!;
    }

    return ret;
  }

  List<FolderInfo>? get subfolders {
    if (subfoldersMap == null) return null;
    return subfoldersMap!.values.toList();
  }

  List<AudioInfo>? get audios {
    if (audiosMap == null) return null;
    return audiosMap!.values.toList();
  }

  List<PlaylistInfo>? get playlists {
    if (playlistMap == null) return null;
    return playlistMap!.values.toList();
  }

  int get subFolderCount {
    if (subfoldersMap == null) return 0;

    return subfoldersMap!.length;
  }

  bool hasSubfolder(String path) {
    final key = basename(path);
    if (subfoldersMap == null) return false;

    return subfoldersMap!.containsKey(key);
  }

  bool hasAudio(String path) {
    final key = basename(path);
    if (audiosMap == null) return false;

    return audiosMap!.containsKey(key);
  }

  bool hasPlaylist(String path) {
    final key = basename(path);
    if (playlistMap == null) return false;

    return playlistMap!.containsKey(key);
  }

  int get audioCount {
    if (audiosMap == null) return 0;

    return audiosMap!.length;
  }

  int get playlistCount {
    if (playlistMap == null) return 0;

    return playlistMap!.length;
  }

  FolderInfo(super.path,
      {super.bytes,
      super.timestamp,
      this.allAudioCount,
      this.subfoldersMap,
      this.audiosMap,
      this.playlistMap,
      super.repo,
      super.parent,
      super.displayData});

  FolderInfo copyWith({
    String? path,
    int? bytes,
    DateTime? timestamp,
    Repository? repo,
    int? allAudioCount,
    FolderInfo? parent,
    displayData,
    bool deep = true,
  }) {
    var folder = FolderInfo(
      path ?? this.path,
      bytes: bytes ?? this.bytes,
      timestamp: timestamp ?? this.timestamp,
      allAudioCount: allAudioCount ?? this.allAudioCount,
      repo: repo ?? this.repo,
      parent: parent ?? this.parent,
    );

    if (deep) {
      Map<String, FolderInfo>? localSubfoldersMap = subfoldersMap?.map(
          (key, folder) => MapEntry(key, folder.copyWith(parent: folder)));
      Map<String, AudioInfo>? localAudiosMap = audiosMap
          ?.map((key, audio) => MapEntry(key, audio.copyWith(parent: folder)));
      Map<String, PlaylistInfo>? localPlaylistMap = playlistMap
          ?.map((key, pl) => MapEntry(key, pl.copyWith(parent: folder)));

      folder.subfoldersMap = localSubfoldersMap;
      folder.audiosMap = localAudiosMap;
      folder.playlistMap = localPlaylistMap;
    }
    folder.cloudData = cloudData;
    folder.copyFrom = this;
    return folder;
  }

  List<AudioInfo>? get allAudios {
    if (subfolders == null) return audios;
    var ret = <AudioInfo>[];
    for (final f in subfolders!) {
      final audios = f.allAudios;
      if (audios != null) ret += audios;
    }

    if (audios == null) return ret;
    return ret + audios!;
  }

  static FolderInfo get empty {
    return FolderInfo(
      "/",
    );
  }

  @override
  List<Object?> get props => [path, bytes, timestamp, allAudioCount];

  @override
  String toString() => "${basename(path)}/";

  factory FolderInfo.fromJson(Map<String, dynamic> json) {
    return FolderInfo(json['path'],
        allAudioCount: json['allAudioCount'],
        bytes: json['bytes'],
        timestamp: DateTime.parse(json['timestamp']),
        repo: sl.getRepository(RepoType.fromString(json['repoType'])));
  }
  Map<String, dynamic> toJson() => {
        'path': path,
        'allAudioCount': allAudioCount,
        'bytes': bytes,
        'timestamp': timestamp,
        'repoType': repo!.type.toString()
      };
}

/*=======================================================================*\ 
  PlayList Information
\*=======================================================================*/
class PlaylistInfo extends FileObject {
  bool broken;
  String? json;
  List<AudioInfo>? audios;

  @override
  String get name => basenameWithoutExtension(path);

  PlaylistInfo(super.path,
      {this.audios,
      this.broken = false,
      super.repo,
      super.parent,
      super.displayData});

  PlaylistInfo copyWith(
      {String? path,
      String? name,
      DateTime? timestamp,
      Repository? repo,
      FolderInfo? parent,
      displayData}) {
    var audio = PlaylistInfo(
      path ?? this.path,
      repo: repo ?? this.repo,
      parent: parent ?? this.parent,
    );

    audio.cloudData = cloudData;
    audio.copyFrom = this;
    return audio;
  }

  static PlaylistInfo brokenPlaylist(
      {
      String path = "",
      Repository? repo}) {
    return PlaylistInfo(path,
        broken: true,
        repo: repo);
  }

  @override
  String toString() => basename(path);

  static Future<PlaylistInfo> fromJson(Map<String, dynamic> json) async {
    final List<Map<String, dynamic>> jsonAudios = json['audios'];
    List<AudioInfo> audios = [];
    for (final a in jsonAudios) {
      final repo = sl.getRepository(RepoType.fromString(a['repoType']));
      final audio = repo.findObjectFromCache(a['path']);
      if (audio != null) {
        audios.add(audio as AudioInfo);
      } else {
        AudioInfo.brokenAudio(path: a['path']);
      }
    }
    return PlaylistInfo(json['path'], audios: audios);
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'audios': audios == null
            ? '{}'
            : audios!.map(
                (a) => {'repoType': a.repo!.type.toString(), 'path': a.path}),
      };
}

class AudioPref {
  double pitch;
  double speed;
  double volume;
  int position;

  AudioPref({double? pitch, this.speed = 1, this.volume = 1, this.position = 0})
      : pitch = pitch ?? GlobalInfo.PLATFORM_PITCH_DEFAULT_VALUE;

  factory AudioPref.fromJson(Map<String, dynamic> json) {
    return AudioPref(
        pitch: json['pitch'],
        speed: json['speed'],
        volume: json['volume'],
        position: json['position']);
  }
  Map<String, dynamic> toJson() => {
        'pitch': pitch,
        'speed': speed,
        'volume': volume,
        'position': position,
      };
}
