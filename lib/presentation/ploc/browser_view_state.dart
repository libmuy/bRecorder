import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';

import '../../core/audio_agent.dart';
import '../../core/logging.dart';
import '../../core/service_locator.dart';
import '../../core/utils/notifiers.dart';
import '../../core/utils/utils.dart';
import '../../data/repository.dart';
import '../../domain/entities.dart';
import '../pages/browser_view.dart';
import '../widgets/audio_list_item/audio_widget_state.dart';

final _log = Logger('BrowserState', level: LogLevel.debug);

abstract class BrowserViewState {
  /*=======================================================================*\ 
    Variables
  \*=======================================================================*/
  // Common staffs
  bool _initialized = false;

  //About Repository
  final Repository _repo;
  ForcibleValueNotifier<FolderInfo>? _folderNotifier;

  // About Display
  final _modeNotifier = sl.get<GlobalModeNotifier>();
  late BrowserView widget;
  ValueNotifier<AudioListItemSelectedState> selectStateNotifier =
      ValueNotifier(AudioListItemSelectedState.noSelected);
  List<FolderInfo> _selectedFolders = [];
  List<AudioInfo> _selectedAudios = [];
  final bottomPanelPlaceholderHeightNotifier = ValueNotifier(0.0);
  ScrollToFunc? _scrollToCallback;
  AudioItemSortType _sortType = AudioItemSortType.name;
  bool _sortReverse = false;

  final groupNotifier = ForcibleValueNotifier(<String, AudioItemGroupModel>{});

  // About Audio Playback
  final _agent = sl.get<AudioServiceAgent>();
  final loopNotifier = ValueNotifier<PlayLoopType>(PlayLoopType.noLoop);
  var groupByDate = false;

  /*=======================================================================*\ 
    Constructor, initializier, finalizer
  \*=======================================================================*/
  BrowserViewState(RepoType dataSourceType)
      : _repo = sl.getRepository(dataSourceType);

  void init({
    required BrowserView widget,
    ScrollToFunc? scrollTo,
  }) {
    this.widget = widget;

    //if show folder only, can not group audios, so disable it
    groupByDate = groupByDate;
    if (widget.folderOnly) groupByDate = false;

    _modeNotifier.addListener(_modeListener);
    if (!widget.folderOnly) {
      _agent.addAudioEventListener(AudioEventType.started, _playingListener);
      _agent.addAudioEventListener(AudioEventType.paused, _playingListener);
      _agent.addAudioEventListener(AudioEventType.complete, _playingListener);
    }
    _scrollToCallback = scrollTo;
    _initialized = true;
    _folderNotifier = ForcibleValueNotifier(FolderInfo.empty);
    refresh();
  }

  void dispose() {
    _modeNotifier.removeListener(_modeListener);
    if (!widget.folderOnly) {
      _agent.removeAudioEventListener(AudioEventType.started, _playingListener);
      _agent.removeAudioEventListener(AudioEventType.paused, _playingListener);
      _agent.removeAudioEventListener(
          AudioEventType.complete, _playingListener);
    }
  }

  /*=======================================================================*\ 
    Common Staff
  \*=======================================================================*/
  String get _rootPath {
    return _currentFolder.path;
  }

  FolderInfo get _currentFolder => _folderNotifier!.value;
  int? _currentAudioIndex;
  AudioInfo? get _currentAudio {
    if (_currentAudioIndex == null || _audioCount <= 0) {
      return null;
    }

    return _audios![_currentAudioIndex!];
  }

  List<AudioInfo>? get _audios {
    final groups = groupNotifier.value.values;
    if (groups.isEmpty) return null;

    List<AudioInfo> audios = [];
    for (var group in groups) {
      final subAudios = group.audios;
      if (subAudios != null) audios += subAudios;
    }

    return audios;
  }

  int get _audioCount => _audios?.length ?? 0;

  /*=======================================================================*\ 
    Display
  \*=======================================================================*/

  bool get _isEditMode => mode == GlobalMode.edit;

  GlobalMode get mode => _modeNotifier.value;
  set mode(GlobalMode value) {
    _modeNotifier.value = value;
  }

  List<AudioObject> get selectedObjects {
    return _currentFolder.subObjects.where((item) {
      final state = item.displayData as AudioWidgetState;
      return state.selected;
    }).toList();
  }

  void _modeListener() {
    final itemMode =
        _isEditMode ? AudioListItemMode.notSelected : AudioListItemMode.normal;
    final objs = groupByDate ? _currentFolder.allAudios : _currentFolder.subObjects;
    final itemStates = objs!.map((e) => e.displayData);
    for (final itemState in itemStates) {
      itemState?.mode = itemMode;
      itemState?.resetHighLight();
    }
    if (mode != GlobalMode.playback) {
      _agent.stopPlay();
    }
  }

  void _addSelectedItem(AudioObject obj) {
    if (obj is FolderInfo) _selectedFolders.add(obj);
    if (obj is AudioInfo) _selectedAudios.add(obj);

    selectStateNotifier.value = AudioListItemSelectedState(
        folderSelected: _selectedFolders.isNotEmpty,
        audioSelected: _selectedAudios.isNotEmpty);
  }

  void _removeSelectedItem(AudioObject obj) {
    if (obj is FolderInfo) _selectedFolders.remove(obj);
    if (obj is AudioInfo) _selectedAudios.remove(obj);

    selectStateNotifier.value = AudioListItemSelectedState(
        folderSelected: _selectedFolders.isNotEmpty,
        audioSelected: _selectedAudios.isNotEmpty);
  }

  void _resetSelectedItem() {
    selectStateNotifier.value = AudioListItemSelectedState.noSelected;
    _selectedAudios = [];
    _selectedFolders = [];
  }

  void itemOnTap(AudioObject item, bool iconOnTapped) async {
    if (item is FolderInfo) _folderOnTap(item);
    if (item is PlaylistInfo) _playlistOnTap(item);
    if (item is AudioInfo) _audioOnTap(item, iconOnTapped);
  }

  void _folderOnTap(FolderInfo folder) {
    final state = folder.displayData as AudioWidgetState;
    if (_isEditMode && widget.editable) {
      state.toggleSelected();
      if (state.selected) {
        _addSelectedItem(folder);
      } else {
        _removeSelectedItem(folder);
      }
    } else {
      cd(folder.path);
    }
  }

  void _audioOnTap(AudioInfo audio, bool iconOnTapped) async {
    final state = audio.displayData as AudioWidgetState;
    switch (mode) {
      case GlobalMode.normal:
        if (!iconOnTapped) {
          sl.playbackPanelExpandNotifier.value = true;
        }
        _playNewAudio(audio);
        break;

      case GlobalMode.edit:
        state.toggleSelected();
        if (state.selected) {
          _addSelectedItem(audio);
        } else {
          _removeSelectedItem(audio);
        }
        break;

      case GlobalMode.playback:
        if (_currentAudio != audio) {
          await _agent.stopPlay();
          _playNewAudio(audio);
        } else {
          _agent.togglePlay(audio);
        }
        if (!iconOnTapped) {
          sl.playbackPanelExpandNotifier.value = true;
        }
        break;
    }
  }
  void _playlistOnTap(PlaylistInfo playlist) async {
  }

  void onBottomPanelClosed() {
    mode = GlobalMode.normal;
    _agent.stopPlay();
  }

  void onListItemLongPressed(AudioWidgetState item) {
    _log.debug("item:${basename(item.audioObject.path)}long pressed");
    switch (mode) {
      case GlobalMode.normal:
      case GlobalMode.playback:
        mode = GlobalMode.edit;
        item.mode = AudioListItemMode.selected;
        _addSelectedItem(item.audioObject);
        break;
      case GlobalMode.edit:
        break;
    }
  }

  void scrollTo(
    AudioObject audioObject, {
    required Duration duration,
    required Curve curve,
  }) {
    _scrollToCallback?.call(audioObject, duration: duration, curve: curve);
  }

  /*=======================================================================*\ 
    Repository
  \*=======================================================================*/
  void setInitialPath(String path) {
    _folderNotifier ??= ForcibleValueNotifier(FolderInfo.empty);
    _folderNotifier!.value = FolderInfo(path);
  }

  void resetAudioItemDisplayData(AudioObject obj) {
    var itemState = AudioListItemMode.normal;
    if (widget.editable && _isEditMode) {
      itemState = AudioListItemMode.notSelected;
    }
    if (obj.displayData == null) {
      obj.displayData = AudioWidgetState(obj, mode: itemState);
    } else {
      final state = obj.displayData as AudioWidgetState;
      state.mode = itemState;
      state.resetHighLight();
    }
  }

  void setAudioItemsSortOrder(AudioItemSortType type, bool reverse) {
    if (_sortType == type && _sortReverse == reverse) return;
    _sortType = type;
    _sortReverse = reverse;
    _sortAllAudioItems();
  }

  void _sortAllAudioItems() {
    groupNotifier.value.forEach(
      (key, group) {
        group.sortItems(_sortType, _sortReverse);
      },
    );
    groupNotifier.notify();
  }

  void cd(String path, {bool force = false}) async {
    _log.debug("cd($path)");
    if (!_initialized) return;
    if (equals(path, _rootPath) && !force) return;
    _currentAudioIndex = null;
    _repo
        .getFolderInfo(path, folderOnly: widget.folderOnly)
        .then((result) async {
      final FolderInfo folderInfo = result.value;
      if (result.succeed) {
        Map<String, AudioItemGroupModel> groups;
        _log.info("folder changed to:${_repo.name}$path, "
            "count:${folderInfo.subObjects.length}");

        if (groupByDate) {
          DateFormat dateFormat = DateFormat('yyyy-MM-dd');
          final allAudios = folderInfo.allAudios;
          if (allAudios == null) return;

          // final groups = allAudios?.
          groups = groupBy(
              allAudios,
              (AudioObject audio) => audio.timestamp == null
                  ? '----/--/--'
                  : dateFormat.format(audio.timestamp!)).map((key, value) =>
              MapEntry(key, AudioItemGroupModel(audios: value)));
        } else {
          groups = {
            "/": AudioItemGroupModel(
                folders: folderInfo.subfolders, audios: folderInfo.audios)
          };
        }
        for (var group in groups.values) {
          group.sortItems(_sortType, _sortReverse);
          group.audios?.forEach((audio) => resetAudioItemDisplayData(audio));
          group.folders?.forEach((audio) => resetAudioItemDisplayData(audio));
        }

        groupNotifier.value = groups;

        // if (_currentFolder.path != folderInfo.path) {
        // folderInfo.dump();
        _resetSelectedItem();
        _currentFolder.displayData?.updateWidget = null;
        _log.debug("set folder updateWidget func:${folderInfo.path}");
        folderInfo.displayData ??= AudioWidgetState(folderInfo);
        folderInfo.displayData!.updateWidget =
            () => cd(folderInfo.path, force: true);
        _folderNotifier!.update(newValue: folderInfo, forceNotify: force);
        widget.onFolderChanged?.call(folderInfo);
        if (mode == GlobalMode.playback) {
          await _agent.stopPlay();
          mode = GlobalMode.normal;
        }
        // }
      } else {
        _log.critical("Failed to get folder($path) info");
      }
    });
  }

  void destoryRepositoryCache() {
    _repo.destoryCache();
    // _folderNotifier.value = FolderInfo.empty;
  }

  bool cdParent() {
    final path = dirname(_currentFolder.path);
    if (path == _currentFolder.path) return false;
    cd(path);
    return true;
  }

  void newFolder(String newFolderName) async {
    final path = join(_currentFolder.path, newFolderName);
    final ret = await _repo.newFolder(path);
    if (ret.succeed) {
      _log.debug("create folder ok");
    } else {
      _log.debug("create folder failed: ${ret.error}");
    }

    refresh();
  }

  void refresh() {
    if (!_initialized) return;
    cd(_currentFolder.path, force: true);
  }

  Future<bool> deleteSelected() async {
    bool ret = true;
    bool deleted = false;

    for (final item in selectedObjects) {
      final result = await _repo.removeObject(item);
      if (result.failed) {
        ret = false;
        break;
      } else {
        deleted = true;
      }
    }

    if (deleted) {
      refresh();
    }

    return ret;
  }

  Future<bool> moveSelectedToFolder(FolderInfo dst) async {
    final result = await dst.repo!.moveObjects(selectedObjects, dst);
    if (result.failed) {
      _log.error("Move to folder${dst.path} failed:${result.error}");
      return false;
    }

    refresh();

    return true;
  }

  /*=======================================================================*\ 
    Playback
  \*=======================================================================*/
  void _playingListener(event, audio) {
    if (mode != GlobalMode.playback) return;
    if (event == AudioEventType.complete) {
      final loopType = loopNotifier.value;
      switch (loopType) {
        case PlayLoopType.list:
          _playNext(false);
          break;
        case PlayLoopType.loopAll:
          _playNext(true);
          break;
        case PlayLoopType.loopOne:
          _agent.startPlay(_currentAudio!);
          break;
        case PlayLoopType.shuffle:
          final randomIndex = Random().nextInt(_audioCount);
          _playNewAudio(_audios![randomIndex]);
          break;
        case PlayLoopType.noLoop:
      }
    }
  }

  void _playNewAudio(AudioInfo audio) async {
    mode = GlobalMode.playback;
    var ret = await _agent.stopPlay();
    if (ret.failed) {
      _log.error("stop playing failed");
      return;
    }

    ret = await _agent.startPlay(audio);
    if (ret.succeed) {
      if (_currentAudio != null) {
        var state = _currentAudio!.displayData as AudioWidgetState;
        state.highlight = false;
        state.playing = false;
      }
      _currentAudioIndex = _audios!.indexOf(audio);
    }
  }

  void _playNext(bool repeat) {
    final current = _currentAudioIndex ?? 0;

    if ((!repeat) && current >= _audioCount - 1) {
      _log.debug("this is the last one");
      return;
    }

    final nextIndex = (current + 1) % _audioCount;
    _log.debug("playback next($nextIndex)");
    _playNewAudio(_audios![nextIndex]);
  }

  void playNext() {
    _playNext(false);
  }

  void playPrevious() {
    if (_currentAudioIndex == 0) {
      return;
    }

    final prev = _audios![_currentAudioIndex! - 1];
    _log.debug("playback previous(${_currentAudioIndex! - 1})");
    _playNewAudio(prev);
  }
}

/*=======================================================================*\ 
  Sub-classes
\*=======================================================================*/
class FilesystemBrowserViewState extends BrowserViewState {
  FilesystemBrowserViewState() : super(RepoType.filesystem);
}

class ICloudBrowserViewState extends BrowserViewState {
  ICloudBrowserViewState() : super(RepoType.iCloud);
}

class GoogleDriveBrowserViewState extends BrowserViewState {
  GoogleDriveBrowserViewState() : super(RepoType.googleDrive);
}

class PlaylistBrowserViewState extends BrowserViewState {
  PlaylistBrowserViewState() : super(RepoType.playlist);
}

class TrashBrowserViewState extends BrowserViewState {
  TrashBrowserViewState() : super(RepoType.trash);
}

class AllStoreageBrowserViewState extends BrowserViewState {
  AllStoreageBrowserViewState() : super(RepoType.allStoreage);
}

/*=======================================================================*\ 
  Helper Types
\*=======================================================================*/
class AudioListItemSelectedState {
  bool folderSelected;
  bool audioSelected;

  AudioListItemSelectedState(
      {required this.audioSelected, required this.folderSelected});

  static AudioListItemSelectedState get noSelected {
    return AudioListItemSelectedState(
        audioSelected: false, folderSelected: false);
  }
}

enum AudioItemSortType { dateTime, name, size }

class AudioItemGroupModel {
  List<FolderInfo>? folders;
  List<AudioInfo>? audios;

  AudioItemGroupModel({this.folders, this.audios});

  List<AudioObject> get objects {
    if (folders == null && audios == null) return [];
    if (folders == null) return audios!;
    if (audios == null) return folders!;
    return folderObjects! + audioObjects!;
  }

  List<AudioObject>? get audioObjects =>
      // ignore: unnecessary_cast
      audios?.map((e) => e as AudioObject).toList();
  List<AudioObject>? get folderObjects =>
      // ignore: unnecessary_cast
      folders?.map((e) => e as AudioObject).toList();

  int compareWitNull<T extends Comparable>(T? t1, T? t2) {
    if (t1 == null && t2 == null) {
      return 0;
    } else if (t1 == null && t2 != null) {
      return 1;
    } else if (t1 != null && t2 == null) {
      return -1;
    } else {
      return t1!.compareTo(t2!);
    }
  }

  void sortItems(AudioItemSortType sortType, bool reverseOrder) {
    int Function(AudioObject, AudioObject)? compare;
    switch (sortType) {
      case AudioItemSortType.dateTime:
        compare = (a, b) => reverseOrder
            ? compareWitNull(b.timestamp, a.timestamp)
            : compareWitNull(a.timestamp, b.timestamp);
        break;
      case AudioItemSortType.name:
        compare = (a, b) {
          final nameA = basename(a.path);
          final nameB = basename(b.path);

          return reverseOrder ? nameB.compareTo(nameA) : nameA.compareTo(nameB);
        };
        break;
      case AudioItemSortType.size:
        compare = (a, b) => reverseOrder
            ? compareWitNull(b.bytes, a.bytes)
            : compareWitNull(a.bytes, b.bytes);
        break;
    }

    folders?.sort(compare);
    audios?.sort(compare);
  }
}
