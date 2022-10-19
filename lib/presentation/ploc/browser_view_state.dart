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
import '../../data/repository_type.dart';
import '../../domain/entities.dart';
import '../pages/browser_view.dart';
import '../widgets/audio_list_item/audio_list_item_state.dart';

final log = Logger('BrowserState', level: LogLevel.debug);

final fs = sl.getRepository(RepoType.filesystem);
final all = sl.getRepository(RepoType.allStoreage);

abstract class BrowserViewState {
  /*=======================================================================*\ 
    Variables
  \*=======================================================================*/
  // Common staffs
  bool _initialized = false;

  //About Repository
  final Repository _repo;
  final ForcibleValueNotifier<FolderInfo> _folderNotifier =
      ForcibleValueNotifier(FolderInfo.empty);

  // About Display
  final _modeNotifier = sl.get<GlobalModeNotifier>();
  late final BrowserView widget;
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
    _modeNotifier.addListener(_modeListener);
    if (!widget.folderOnly) {
      _agent.addAudioEventListener(AudioEventType.started, _playingListener);
      _agent.addAudioEventListener(AudioEventType.paused, _playingListener);
      _agent.addAudioEventListener(AudioEventType.complete, _playingListener);
    }
    _scrollToCallback = scrollTo;
    _initialized = true;
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

  FolderInfo get _currentFolder => _folderNotifier.value;
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
  void _notifyTitle() {
    if (_rootPath == "/") {
      widget.titleNotifier.value = _repo.name;
    } else {
      widget.titleNotifier.value = _repo.name + _rootPath;
    }
  }

  bool get _isEditMode => mode == GlobalMode.edit;

  GlobalMode get mode => _modeNotifier.value;
  set mode(GlobalMode value) {
    _modeNotifier.value = value;
  }

  List<AudioObject> get selectedObjects {
    return _currentFolder.subObjects.where((item) {
      final state = item.displayData as AudioListItemState;
      return state.selected;
    }).toList();
  }

  void _modeListener() {
    final itemMode =
        _isEditMode ? AudioListItemMode.notSelected : AudioListItemMode.normal;
    final itemStates = _currentFolder.subObjects
        .map((e) => e.displayData as AudioListItemState);
    for (final itemState in itemStates) {
      itemState.mode = itemMode;
      itemState.resetHighLight();
    }
    if (mode != GlobalMode.playback) {
      _agent.stopPlayIfPlaying();
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

  void folderOnTap(FolderInfo folder) {
    final state = folder.displayData as AudioListItemState;
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

  void audioOnTap(AudioInfo audio, bool iconOnTapped) async {
    final state = audio.displayData as AudioListItemState;
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

  void onBottomPanelClosed() {
    mode = GlobalMode.normal;
    _agent.stopPlayIfPlaying();
  }

  void onListItemLongPressed(AudioListItemState item) {
    log.debug("item:${basename(item.audioObject.path)}long pressed");
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
  void resetAudioItemDisplayData(AudioObject obj) {
    var itemState = AudioListItemMode.normal;
    if (widget.editable && _isEditMode) {
      itemState = AudioListItemMode.notSelected;
    }
    if (obj.displayData == null) {
      obj.displayData = AudioListItemState(obj, mode: itemState);
    } else {
      final state = obj.displayData as AudioListItemState;
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
    if (!_initialized) return;
    if (equals(path, _rootPath) && !force) return;
    _currentAudioIndex = null;
    _repo
        .getFolderInfo(path, folderOnly: widget.folderOnly)
        .then((result) async {
      final FolderInfo folderInfo = result.value;
      if (result.succeed) {
        Map<String, AudioItemGroupModel> groups;
        log.debug("folder changed to:${_repo.name}$path");

        if (widget.groupByDate) {
          DateFormat dateFormat = DateFormat('yyyy-MM-dd');
          final allAudios = folderInfo.allAudios;
          if (allAudios == null) return;

          // final groups = allAudios?.
          groups = groupBy(allAudios,
                  (AudioObject audio) => dateFormat.format(audio.timestamp))
              .map((key, value) =>
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

        // folderInfo.dump();
        _resetSelectedItem();
        _folderNotifier.update(newValue: folderInfo, forceNotify: force);
        widget.onFolderChanged?.call(folderInfo);
        _notifyTitle();
        if (mode == GlobalMode.playback) {
          await _agent.stopPlayIfPlaying();
          mode = GlobalMode.normal;
        }
      } else {
        log.critical("Failed to get folder($path) info");
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
      log.debug("create folder ok");
    } else {
      log.debug("create folder failed: ${ret.error}");
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
    final dstRepo = dst.repo;
    //TODO: implement move between repos
    if (dstRepo != _repo) {
      log.error("NOT implemented");
      return false;
    }

    final result = await _repo.moveObjects(selectedObjects, dst);
    if (result.failed) {
      log.error("Move to folder${dst.path} failed:${result.error}");
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
    var ret = await _agent.stopPlayIfPlaying();
    if (ret.failed) {
      log.error("stop playing failed");
      return;
    }

    ret = await _agent.startPlay(audio);
    if (ret.succeed) {
      if (_currentAudio != null) {
        var state = _currentAudio!.displayData as AudioListItemState;
        state.highlight = false;
        state.playing = false;
      }
      _currentAudioIndex = _audios!.indexOf(audio);
    }
  }

  void _playNext(bool repeat) {
    final current = _currentAudioIndex ?? 0;

    if ((!repeat) && current >= _audioCount - 1) {
      log.debug("this is the last one");
      return;
    }

    final nextIndex = (current + 1) % _audioCount;
    log.debug("playback next($nextIndex)");
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
    log.debug("playback previous(${_currentAudioIndex! - 1})");
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

  void sortItems(AudioItemSortType sortType, bool reverseOrder) {
    int Function(AudioObject, AudioObject)? compare;
    switch (sortType) {
      case AudioItemSortType.dateTime:
        compare = (a, b) => reverseOrder
            ? b.timestamp.compareTo(a.timestamp)
            : a.timestamp.compareTo(b.timestamp);
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
            ? b.bytes.compareTo(a.bytes)
            : a.bytes.compareTo(b.bytes);
        break;
    }

    folders?.sort(compare);
    audios?.sort(compare);
  }
}
