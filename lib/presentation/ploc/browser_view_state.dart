import 'dart:math';

import 'package:brecorder/core/audio_agent.dart';
import 'package:brecorder/core/logging.dart';
import 'package:brecorder/core/service_locator.dart';
import 'package:brecorder/domain/abstract_repository.dart';
import 'package:brecorder/presentation/widgets/audio_list_item/audio_list_item_state.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart';

import '../../data/repository_type.dart';
import '../../domain/entities.dart';

final log = Logger('HomeState');

abstract class BrowserViewState {
  /*=======================================================================*\ 
    Variables
  \*=======================================================================*/
  // Common staffs
  bool _initialized = false;

  //About Repository
  late final Repository _repo;
  bool _folderOnly = false;
  late ValueNotifier<FolderInfo> _folderNotifier;
  void Function(String path)? _onFolderChanged;

  // About Display
  late ValueNotifier<BrowserViewMode> _modeNotifier;
  late ValueNotifier<String> _titleNotifier;
  List<AudioListItemState> itemStateList = [];
  int? _currentAudioIndex;
  ValueNotifier<AudioListItemSelectedState>? _selectStateNotifier;
  List<AudioListItemState> _selectedFolders = [];
  List<AudioListItemState> _selectedAudios = [];

  // About Audio Playback
  final _agent = sl.get<AudioServiceAgent>();
  final loopNotifier = ValueNotifier<PlayLoopType>(PlayLoopType.noLoop);

  /*=======================================================================*\ 
    Constructor, initializier, finalizer
  \*=======================================================================*/
  BrowserViewState(RepoType dataSourceType) {
    _repo = sl.getRepository(dataSourceType);
  }

  void init(
      {required bool folderOnly,
      required ValueNotifier<BrowserViewMode> modeNotifier,
      required ValueNotifier<String> titleNotifier,
      required ValueNotifier<AudioListItemSelectedState> selectStateNotifier,
      required ValueNotifier<FolderInfo> folderNotifier,
      void Function(String path)? onFolderChanged}) {
    assert(titleNotifier.value != "");

    _modeNotifier = modeNotifier;
    _onFolderChanged = onFolderChanged;
    _titleNotifier = titleNotifier;
    _selectStateNotifier = selectStateNotifier;
    _folderNotifier = folderNotifier;
    _modeNotifier.addListener(_modeListener);
    _folderOnly = folderOnly;
    if (!_folderOnly) {
      _agent.addAudioEventListener(AudioEventType.started, _playingListener);
      _agent.addAudioEventListener(AudioEventType.paused, _playingListener);
      _agent.addAudioEventListener(AudioEventType.stopped, _playingListener);
    }
    _initialized = true;
    refresh();
  }

  void dispose() {
    _modeNotifier.removeListener(_modeListener);
    if (!_folderOnly) {
      _agent.removeAudioEventListener(AudioEventType.started, _playingListener);
      _agent.removeAudioEventListener(AudioEventType.paused, _playingListener);
      _agent.removeAudioEventListener(AudioEventType.stopped, _playingListener);
    }
  }

  /*=======================================================================*\ 
    Common Staff
  \*=======================================================================*/
  String get _currentPath {
    return _folderNotifier.value.path;
  }

  AudioListItemState? get currentAudio {
    if (_currentAudioIndex == null) {
      return null;
    }

    return itemStateList[_currentAudioIndex!];
  }

  /*=======================================================================*\ 
    Display
  \*=======================================================================*/
  void _notifyTitle() {
    if (_currentPath == "/") {
      _titleNotifier.value = _repo.name;
    } else {
      _titleNotifier.value = _repo.name + _currentPath;
    }
  }

  // bool get editMode => modeNotifier.value == BrowserViewMode.edit;
  BrowserViewMode get mode => _modeNotifier.value;
  set mode(BrowserViewMode value) {
    _modeNotifier.value = value;
  }

  void _modeListener() {
    final itemMode = (mode == BrowserViewMode.edit)
        ? AudioListItemMode.notSelected
        : AudioListItemMode.normal;
    for (final itemState in itemStateList) {
      itemState.mode = itemMode;
      itemState.resetHighLight();
    }
    if (mode != BrowserViewMode.playback) {
      _agent.stopPlayIfPlaying();
    }
  }

  void _addSelectedItem(
      {AudioListItemState? audio, AudioListItemState? folder}) {
    if (audio != null) {
      _selectedAudios.add(audio);
    }
    if (folder != null) {
      _selectedFolders.add(folder);
    }

    _selectStateNotifier?.value = AudioListItemSelectedState(
        folderSelected: _selectedFolders.isNotEmpty,
        audioSelected: _selectedAudios.isNotEmpty);
  }

  void _removeSelectedItem(
      {AudioListItemState? audio, AudioListItemState? folder}) {
    if (audio != null) {
      _selectedAudios.remove(audio);
    }
    if (folder != null) {
      _selectedFolders.remove(folder);
    }

    _selectStateNotifier?.value = AudioListItemSelectedState(
        folderSelected: _selectedFolders.isNotEmpty,
        audioSelected: _selectedAudios.isNotEmpty);
  }

  void _resetSelectedItem() {
    _selectStateNotifier?.value = AudioListItemSelectedState.noSelected;
    _selectedAudios = [];
    _selectedFolders = [];
  }

  void folderOnTap(AudioListItemState itemState) {
    switch (mode) {
      case BrowserViewMode.normal:
        cd(itemState.audioObject.path);
        break;

      case BrowserViewMode.edit:
        itemState.toggleSelected();
        if (itemState.selected) {
          _addSelectedItem(folder: itemState);
        } else {
          _removeSelectedItem(folder: itemState);
        }
        break;

      case BrowserViewMode.playback:
        mode = BrowserViewMode.normal;
        cd(itemState.audioObject.path);
        break;
    }
  }

  void audioOnTap(AudioListItemState itemState, bool iconOnTapped) async {
    switch (mode) {
      case BrowserViewMode.normal:
        if (iconOnTapped) {
          _playNewAudio(itemState);
        } else {
          //TODO: implement
          // playbackAudioInNewPage(itemState);
        }
        break;

      case BrowserViewMode.edit:
        itemState.toggleSelected();
        if (itemState.selected) {
          _addSelectedItem(audio: itemState);
        } else {
          _removeSelectedItem(audio: itemState);
        }
        break;

      case BrowserViewMode.playback:
        if (iconOnTapped) {
          if (currentAudio != itemState) {
            await _agent.stopPlay();
            _playNewAudio(itemState);
          } else {
            _agent.togglePlay(itemState.audioObject as AudioInfo);
          }
        } else {
          // agent.stopPlay();
          //TODO: implement
          // playbackAudioInNewPage(itemState);
        }
        break;
    }
  }

  void onPlaybackPanelClosed() {
    mode = BrowserViewMode.normal;
    _agent.stopPlayIfPlaying();
  }

  void onListItemLongPressed(AudioListItemState item) {
    log.debug("item:${basename(item.audioObject.path)}long pressed");
    switch (mode) {
      case BrowserViewMode.normal:
      case BrowserViewMode.playback:
        mode = BrowserViewMode.edit;
        item.mode = AudioListItemMode.selected;
        break;
      case BrowserViewMode.edit:
        break;
    }
  }

  /*=======================================================================*\ 
    Repository
  \*=======================================================================*/
  void cd(String path, {bool force = false}) {
    if (!_initialized) return;
    if (equals(path, _currentPath) && !force) return;
    // mode = BrowserViewMode.normal;
    _currentAudioIndex = null;
    _repo.getFolderInfo(path, folderOnly: _folderOnly).then((result) {
      if (result.succeed) {
        log.debug("folder changed to:${_repo.name}$path");
        final FolderInfo folderInfo = result.value;
        final List<AudioObject> tmpList =
            // ignore: unnecessary_cast
            folderInfo.subfolders.map((e) => e as AudioObject).toList();
        final list = tmpList + folderInfo.audios;
        itemStateList = list.map((e) => AudioListItemState(e)).toList();
        _resetSelectedItem();
        _folderNotifier.value = folderInfo;
        _onFolderChanged?.call(folderInfo.path);
        _notifyTitle();
      } else {
        log.critical("Failed to get folder($path) info");
      }
    });
  }

  void cdParent() {
    final path = dirname(_folderNotifier.value.path);
    cd(path);
  }

  void newFolder(String newFolderName) async {
    final path = join(_folderNotifier.value.path, newFolderName);
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
    cd(_folderNotifier.value.path, force: true);
  }

  Future<bool> deleteSelected() async {
    bool ret = true;
    bool deleted = false;
    for (final item in itemStateList) {
      if (item.selected) {
        final result = await _repo.removeObject(item.audioObject);
        if (result.failed) {
          ret = false;
          break;
        } else {
          deleted = true;
        }
      }
    }

    if (deleted) {
      refresh();
    }

    return ret;
  }

  Future<bool> moveSelectedToFolder(Repository dstRepo, String dstPath) async {
    //TODO: implement move between repos
    if (dstRepo != _repo) {
      log.error("NOT implemented");
      return false;
    }

    final srcList = itemStateList
        .where((item) => item.selected)
        .map((item) => item.audioObject.path)
        .toList();
    final result = await _repo.moveObjects(srcList, dstPath);
    if (result.failed) {
      log.error("Move to folder$dstPath failed:${result.error}");
      return false;
    }

    refresh();

    return true;
  }

  /*=======================================================================*\ 
    Playback
  \*=======================================================================*/
  void _playingListener(event, audio) {
    if (event == AudioEventType.started) {
      //All new file playback is from this object
      assert(audio == currentAudio!.audioObject);
      currentAudio!.highlight = true;
      currentAudio!.playing = true;
    } else if (event == AudioEventType.paused) {
      currentAudio!.playing = false;
    } else if (event == AudioEventType.stopped) {
      currentAudio!.playing = false;
      currentAudio?.highlight = false;
      if (mode != BrowserViewMode.playback) {
        return;
      }
      final loopType = loopNotifier.value;
      switch (loopType) {
        case PlayLoopType.list:
          _playNext(false);
          break;
        case PlayLoopType.loopAll:
          _playNext(true);
          break;
        case PlayLoopType.loopOne:
          _agent.startPlay(currentAudio!.audioObject as AudioInfo);
          break;
        case PlayLoopType.random:
          final audioCounts = _folderNotifier.value.audios.length;
          final audioStartIndex = _folderNotifier.value.subfolders.length;
          final relativeIndex = Random().nextInt(audioCounts);
          final nextAudio = itemStateList[audioStartIndex + relativeIndex];
          _playNewAudio(nextAudio);
          break;
        case PlayLoopType.noLoop:
      }
    }
  }

  void _playNewAudio(AudioListItemState itemState) async {
    mode = BrowserViewMode.playback;
    final ret = await _agent.startPlay(itemState.audioObject as AudioInfo);
    if (ret.succeed) {
      currentAudio?.highlight = false;
      currentAudio?.playing = false;
      _currentAudioIndex = itemStateList.indexOf(itemState);
      Scrollable.ensureVisible(itemState.key.currentContext!,
          duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }

  void _playNext(bool repeat) {
    final audioCounts = _folderNotifier.value.audios.length;
    final audioStartIndex = _folderNotifier.value.subfolders.length;
    final currentRelativeIndex = _currentAudioIndex! - audioStartIndex;

    if ((!repeat) && currentRelativeIndex >= audioCounts - 1) {
      log.debug("this is the last one");
      return;
    }

    final nextIndex =
        (currentRelativeIndex + 1) % audioCounts + audioStartIndex;
    log.debug("playback next($nextIndex)");
    _playNewAudio(itemStateList[nextIndex]);
  }

  void playNext() {
    _playNext(false);
  }

  void playPrevious() {
    if (_currentAudioIndex == 0) {
      return;
    }

    final prev = itemStateList[_currentAudioIndex! - 1];
    if (prev.audioObject is FolderInfo) {
      log.debug("previous(${_currentAudioIndex! - 1})"
          " is a folder, can not playback");
      return;
    }
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

enum BrowserViewMode {
  normal,
  edit,
  playback,
}

enum PlayLoopType {
  loopAll,
  loopOne,
  random,
  noLoop,
  list,
}
