import 'dart:math';

import 'package:brecorder/core/audio_agent.dart';
import 'package:brecorder/core/logging.dart';
import 'package:brecorder/core/service_locator.dart';
import 'package:brecorder/data/abstract_repository.dart';
import 'package:brecorder/presentation/widgets/audio_list_item/audio_list_item_state.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart';

import '../../data/repository_type.dart';
import '../../domain/entities.dart';

final log = Logger('HomeState');

final fs = sl.getRepository(RepoType.filesystem);
final all = sl.getRepository(RepoType.allStoreage);

abstract class BrowserViewState {
  /*=======================================================================*\ 
    Variables
  \*=======================================================================*/
  // Common staffs
  bool _initialized = false;

  //About Repository
  late final Repository _repo;
  bool _folderOnly = false;
  late FolderChangeNotifier _folderNotifier;
  void Function(FolderInfo folder)? _onFolderChanged;

  // About Display
  late ValueNotifier<BrowserViewMode> _modeNotifier;
  late ValueNotifier<String> _titleNotifier;
  int? _currentAudioIndex;
  ValueNotifier<AudioListItemSelectedState>? _selectStateNotifier;
  List<FolderInfo> _selectedFolders = [];
  List<AudioInfo> _selectedAudios = [];

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
      required FolderChangeNotifier folderNotifier,
      void Function(FolderInfo folder)? onFolderChanged}) {
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
  String get _rootPath {
    return _rootFolder.path;
  }

  FolderInfo get _rootFolder => _folderNotifier.value;
  List<AudioInfo>? get _audios => _rootFolder.audios;
  int get _audioCount => _rootFolder.audioCount;

  AudioInfo? get _currentAudio {
    if (_currentAudioIndex == null || _audioCount <= 0) {
      return null;
    }

    return _audios![_currentAudioIndex!];
  }

  /*=======================================================================*\ 
    Display
  \*=======================================================================*/
  void _notifyTitle() {
    if (_rootPath == "/") {
      _titleNotifier.value = _repo.name;
    } else {
      _titleNotifier.value = _repo.name + _rootPath;
    }
  }

  bool get _isEditMode => mode == BrowserViewMode.edit;

  BrowserViewMode get mode => _modeNotifier.value;
  set mode(BrowserViewMode value) {
    _modeNotifier.value = value;
  }

  List<AudioObject> get selectedObjects {
    return _rootFolder.subObjects.where((item) {
      final state = item.displayData as AudioListItemState;
      return state.selected;
    }).toList();
  }

  void _modeListener() {
    final itemMode =
        _isEditMode ? AudioListItemMode.notSelected : AudioListItemMode.normal;
    for (final itemState in _rootFolder.subObjects
        .map((e) => e.displayData as AudioListItemState)) {
      itemState.mode = itemMode;
      itemState.resetHighLight();
    }
    if (mode != BrowserViewMode.playback) {
      _agent.stopPlayIfPlaying();
    }
  }

  void _addSelectedItem(AudioObject obj) {
    if (obj is FolderInfo) _selectedFolders.add(obj);
    if (obj is AudioInfo) _selectedAudios.add(obj);

    _selectStateNotifier?.value = AudioListItemSelectedState(
        folderSelected: _selectedFolders.isNotEmpty,
        audioSelected: _selectedAudios.isNotEmpty);
  }

  void _removeSelectedItem(AudioObject obj) {
    if (obj is FolderInfo) _selectedFolders.remove(obj);
    if (obj is AudioInfo) _selectedAudios.remove(obj);

    _selectStateNotifier?.value = AudioListItemSelectedState(
        folderSelected: _selectedFolders.isNotEmpty,
        audioSelected: _selectedAudios.isNotEmpty);
  }

  void _resetSelectedItem() {
    _selectStateNotifier?.value = AudioListItemSelectedState.noSelected;
    _selectedAudios = [];
    _selectedFolders = [];
  }

  void folderOnTap(FolderInfo folder) {
    final state = folder.displayData as AudioListItemState;
    switch (mode) {
      case BrowserViewMode.normal:
      case BrowserViewMode.normalAnimationDone:
        cd(folder.path);
        break;

      case BrowserViewMode.edit:
        state.toggleSelected();
        if (state.selected) {
          _addSelectedItem(folder);
        } else {
          _removeSelectedItem(folder);
        }
        break;

      case BrowserViewMode.playback:
        cd(folder.path);
        break;
    }
  }

  void audioOnTap(AudioInfo audio, bool iconOnTapped) async {
    final state = audio.displayData as AudioListItemState;
    switch (mode) {
      case BrowserViewMode.normal:
      case BrowserViewMode.normalAnimationDone:
        if (iconOnTapped) {
          _playNewAudio(audio);
        } else {
          //TODO: implement
          // playbackAudioInNewPage(itemState);
        }
        break;

      case BrowserViewMode.edit:
        state.toggleSelected();
        if (state.selected) {
          _addSelectedItem(audio);
        } else {
          _removeSelectedItem(audio);
        }
        break;

      case BrowserViewMode.playback:
        if (iconOnTapped) {
          if (_currentAudio != audio) {
            await _agent.stopPlay();
            _playNewAudio(audio);
          } else {
            _agent.togglePlay(audio);
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
      case BrowserViewMode.normalAnimationDone:
      case BrowserViewMode.playback:
        mode = BrowserViewMode.edit;
        item.mode = AudioListItemMode.selected;
        _addSelectedItem(item.audioObject);
        break;
      case BrowserViewMode.edit:
        break;
    }
  }

  /*=======================================================================*\ 
    Repository
  \*=======================================================================*/
  void cd(String path, {bool force = false}) async {
    if (!_initialized) return;
    if (equals(path, _rootPath) && !force) return;
    _currentAudioIndex = null;
    _repo.getFolderInfo(path, folderOnly: _folderOnly).then((result) async {
      if (result.succeed) {
        final FolderInfo folderInfo = result.value;
        for (var sub in folderInfo.subObjects) {
          sub.displayData ??= AudioListItemState(sub,
              mode: _isEditMode
                  ? AudioListItemMode.notSelected
                  : AudioListItemMode.normal);
        }
        log.debug("folder changed to:${_repo.name}$path");
        // folderInfo.dump();
        _resetSelectedItem();
        _folderNotifier.update(folderInfo, forceNotify: force);
        _onFolderChanged?.call(folderInfo);
        _notifyTitle();
        _currentAudioIndex = 0;
        if (mode == BrowserViewMode.playback) {
          await _agent.stopPlayIfPlaying();
          mode = BrowserViewMode.normal;
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

  void cdParent() {
    final path = dirname(_rootFolder.path);
    cd(path);
  }

  void newFolder(String newFolderName) async {
    final path = join(_rootFolder.path, newFolderName);
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
    cd(_rootFolder.path, force: true);
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
    if (mode != BrowserViewMode.playback) return;
    if (event == AudioEventType.stopped) {
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
        case PlayLoopType.random:
          final randomIndex = Random().nextInt(_audioCount);
          final nextAudio = _audios![randomIndex].displayData;
          _playNewAudio(nextAudio);
          break;
        case PlayLoopType.noLoop:
      }
    }
  }

  void _playNewAudio(AudioInfo audio) async {
    mode = BrowserViewMode.playback;
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

class FolderChangeNotifier extends ValueNotifier<FolderInfo> {
  void update(FolderInfo folder, {bool forceNotify = false}) {
    if (value == folder && forceNotify) {
      notifyListeners();
    }
    value = folder;
  }

  FolderChangeNotifier(FolderInfo value) : super(value);
}

enum BrowserViewMode {
  normal,
  normalAnimationDone,
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
