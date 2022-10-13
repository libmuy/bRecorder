import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../core/global_info.dart';
import '../core/logging.dart';
import '../core/service_locator.dart';
import '../data/repository.dart';

const _prefKeyNextAudioId = "nextAudioId";

final log = Logger('Entity');

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
  int bytes;
  DateTime timestamp;
  FolderInfo? parent;
  dynamic displayData;
  AudioObject? copyFrom;
  Future<String> get realPath async {
    if (repo == null) {
      return path;
    }
    return await repo!.absolutePath(path);
  }

  void destory() {}

  String get mapKey => basename(path);
  AudioObject(this.path, this.bytes, this.timestamp,
      {this.repo, this.parent, this.displayData});

  @override
  List<Object> get props => [path, bytes, timestamp];

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
class AudioInfo extends AudioObject {
  int? _id;
  final int durationMS;
  int currentPosition;
  bool broken;
  String _path;
  AudioPref? _pref;
  Float32List? _waveformData;
  void Function()? onPlayStopped;
  void Function()? onPlayPaused;
  void Function()? onPlayStarted;

  AudioInfo(this.durationMS, String path, int bytes, DateTime timestamp,
      {this.currentPosition = 0,
      this.broken = false,
      Repository? repo,
      FolderInfo? parent,
      displayData})
      : _path = path,
        super(path, bytes, timestamp,
            repo: repo, parent: parent, displayData: displayData);

  @override
  List<Object> get props => [durationMS, path, bytes, timestamp];

  @override
  String get path => _path;

  @override
  set path(String newPath) => _setPath(newPath);

  void _setPath(String newPath) async {
    if (!await hasPerf) {
      _path = newPath;
      return;
    } else {
      final sharedPref = await sl.asyncPref;
      final oldIdKey = _prefIdKey;
      _path = newPath;
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
      _id = sharedPref.getInt(_prefKeyNextAudioId) ?? 0;

      sl.pref.setInt(_prefKeyNextAudioId, _id! + 1);
      sl.pref.setInt(_prefIdKey, _id!);
      log.debug("create audio($this)'s id:$_id");
    } else {
      log.debug("get    audio($this)'s id:$_id");
    }
    return _id!;
  }

  Future<bool> get hasPerf async {
    if (_id == null) {
      final sharedPref = await sl.asyncPref;
      _id = sharedPref.getInt(_prefIdKey);
    }

    return _id != null;
  }

  Future<String> get _prefKey async {
    return "audio_${await id}";
  }

  Future<String> get _waveformPath async {
    final docDir = await getApplicationDocumentsDirectory();
    var dir = join(docDir.path, "brecorder/waveform");
    await Directory(dir).create(recursive: true);

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
    log.debug("save perf key: ${await _prefKey}");
    log.debug("    json: ${jsonEncode(await pref)}");
    sharedPref.setString(await _prefKey, jsonEncode(await pref));
  }

  Future<AudioPref> get pref async {
    final sharedPref = await sl.asyncPref;
    if (_pref != null) return _pref!;
    final prefStr = sharedPref.getString(await _prefKey);
    if (prefStr != null) {
      log.debug("Perf: restored");
      _pref = AudioPref.fromJson(jsonDecode(prefStr));
    } else {
      log.debug("Perf: create new");
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
      durationMS ?? this.durationMS,
      path ?? this.path,
      bytes ?? this.bytes,
      timestamp ?? this.timestamp,
      repo: repo ?? this.repo,
      currentPosition: currentPosition ?? this.currentPosition,
      parent: parent ?? this.parent,
    );

    audio.copyFrom = this;
    return audio;
  }

  static AudioInfo brokenAudio(
      {int durationMS = 0,
      String path = "",
      int bytes = 0,
      DateTime? timestamp,
      Repository? repo}) {
    return AudioInfo(durationMS, path, bytes, timestamp ?? DateTime(1970),
        broken: true, repo: repo);
  }

  @override
  String toString() => basename(path);
}

/*=======================================================================*\ 
  Folder Information
\*=======================================================================*/
class FolderInfo extends AudioObject {
  Map<String, FolderInfo>? subfoldersMap;
  Map<String, AudioInfo>? audiosMap;
  int allAudioCount;

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

  int get audioCount {
    if (audiosMap == null) return 0;

    return audiosMap!.length;
  }

  FolderInfo(String path, int bytes, DateTime timestamp, this.allAudioCount,
      {this.subfoldersMap,
      this.audiosMap,
      Repository? repo,
      FolderInfo? parent,
      displayData})
      : super(path, bytes, timestamp,
            repo: repo, parent: parent, displayData: displayData);

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
      bytes ?? this.bytes,
      timestamp ?? this.timestamp,
      allAudioCount ?? this.allAudioCount,
      repo: repo ?? this.repo,
      parent: parent ?? this.parent,
    );

    if (deep) {
      Map<String, FolderInfo>? localSubfoldersMap = subfoldersMap?.map(
          (key, folder) => MapEntry(key, folder.copyWith(parent: folder)));
      Map<String, AudioInfo>? localAudiosMap = audiosMap
          ?.map((key, audio) => MapEntry(key, audio.copyWith(parent: folder)));

      folder.subfoldersMap = localSubfoldersMap;
      folder.audiosMap = localAudiosMap;
    }
    folder.copyFrom = this;
    return folder;
  }

  List<AudioInfo>? get allAudios {
    if (subfolders == null) return audios;
    var ret = <AudioInfo>[];
    for (final f in subfolders!) {
      if (f.audios != null) ret += f.audios!;
    }

    if (audios == null) return ret;
    return ret + audios!;
  }

  static FolderInfo get empty {
    return FolderInfo(
      "/",
      0,
      DateTime(1907),
      0,
    );
  }

  @override
  List<Object> get props => [path, bytes, timestamp, allAudioCount];

  @override
  String toString() => "${basename(path)}/";
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
