import 'dart:async';

import 'package:brecorder/core/logging.dart';
import 'package:brecorder/core/service_locator.dart';
import 'package:brecorder/data/repository_type.dart';
import 'package:brecorder/presentation/widgets/audio_list_item/audio_list_item_state.dart';
import 'package:brecorder/presentation/widgets/folder_selector.dart';
import 'package:brecorder/presentation/widgets/new_folder_dialog.dart';
import 'package:flutter/material.dart';

import '../../domain/entities.dart';
import '../ploc/browser_view_state.dart';
import '../widgets/audio_list_item/audio_list_item.dart';
import '../widgets/playback_panel.dart';

final log = Logger('BrowserView');

class BrowserView extends StatefulWidget {
  final RepoType repoType;
  final bool folderOnly;
  final bool persistPath;
  final bool destoryRepoCache;
  final ValueNotifier<String> titleNotifier;
  final void Function(FolderInfo folder)? onFolderChanged;
  final ValueNotifier<BrowserViewMode>? modeNotifier;
  const BrowserView(
      {Key? key,
      required this.repoType,
      required this.titleNotifier,
      this.folderOnly = false,
      this.persistPath = true,
      this.modeNotifier,
      this.destoryRepoCache = false,
      this.onFolderChanged})
      : super(key: key);

  @override
  State<BrowserView> createState() => _BrowserViewState();
}

class _BrowserViewState extends State<BrowserView>
    with
        AutomaticKeepAliveClientMixin<BrowserView>,
        SingleTickerProviderStateMixin {
  late BrowserViewState state;
  final _selectStateNotifier =
      ValueNotifier(AudioListItemSelectedState.noSelected);
  final _folderNotifier = FolderChangeNotifier(FolderInfo.empty);
  late ValueNotifier<BrowserViewMode> modeNotifier;
  late ScrollController _scrollController;
  bool _scrollSwitch = false;
  BrowserViewMode _lastMode = BrowserViewMode.normal;
  final _bottomPanelHeightNotifier = ValueNotifier<double>(0);

  //Bottom Panel Drag Processing
  double _startDragPos = 0;
  double _endDragPos = 0;
  double _currentSizeRate = 1;
  double _bottomPanelHeight = 0;
  bool _quickSwiped = false;
  var _lastAnimationStatus = AnimationStatus.dismissed;
  final _bottomPanelKey = GlobalKey();
  late final AnimationController _animationController;
  late final Animation<double> _sizeAnimation;

  @override
  void initState() {
    // log.debug("initState");
    super.initState();
    state = sl.getBrowserViewState(widget.repoType);
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);
    modeNotifier = widget.modeNotifier ?? ValueNotifier(BrowserViewMode.normal);
    state.init(
        folderOnly: widget.folderOnly,
        modeNotifier: modeNotifier,
        titleNotifier: widget.titleNotifier,
        selectStateNotifier: _selectStateNotifier,
        folderNotifier: _folderNotifier,
        onFolderChanged: widget.onFolderChanged);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _sizeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(_animationController);
    _animationController.addStatusListener(_animationStatusListener);
  }

  @override
  void dispose() {
    log.debug("dispose");
    if (widget.destoryRepoCache) state.destoryRepositoryCache();
    state.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => widget.persistPath;

  void _animationStatusListener(AnimationStatus status) {
    log.debug("animation state: $status");
    switch (status) {
      case AnimationStatus.dismissed:
      case AnimationStatus.completed:
        // The bottom panel is disappeared reset the controller
        if (_lastAnimationStatus == AnimationStatus.reverse) {
          if (modeNotifier.value == BrowserViewMode.normal) {
            modeNotifier.value = BrowserViewMode.normalAnimationDone;
          } else {
            state.onPlaybackPanelClosed();
          }
        }
        break;
      case AnimationStatus.reverse:
        break;
      case AnimationStatus.forward:
        break;
    }

    _lastAnimationStatus = status;
  }

  void _scrollListener() {
    final offset = _scrollController.offset;

    // log.debug("offset:$offset, sw:$_scrollSwitch");
    if (_scrollSwitch == false) {
      if (offset < -50.0) {
        _scrollSwitch = true;
        _folderNotifier.value.dump();
      }
    } else {
      if (offset > -50.0) _scrollSwitch = false;
    }
  }

  double _calculateBottomPanelHeight() {
    final contex = _bottomPanelKey.currentContext;
    if (contex == null) {
      log.error("Playback Panel is not being rendered");
      return 0;
    }
    final box = contex.findRenderObject() as RenderBox;
    return box.size.height;
  }

  void _showNewFolderDialog(BuildContext context) {
    showModalBottomSheet<void>(
      elevation: 20,
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
        ),
      ),
      builder: (BuildContext context) {
        return SizedBox(
            height: 400,
            // color: Colors.amber,
            child: FolderSelector(
              folderNotify: (folder) {
                log.debug("selected folder:${folder.path}");
                state.moveSelectedToFolder(folder);
              },
            ));
      },
    );
  }

  List<Widget> _listItemWidgets(FolderInfo folder) {
    List<AudioObject> list;
    if (widget.folderOnly) {
      list = folder.subfolders as List<AudioObject>;
    } else {
      list = folder.subObjects;
    }
    List<Widget> ret = list.map((obj) {
      final itemState = obj.displayData as AudioListItemState;
      // ignore: unnecessary_cast
      return AudioListItem(
        key: itemState.key,
        audioItem: obj,
        state: itemState,
        onTap: (iconOnTapped) {
          if (obj is FolderInfo) {
            state.folderOnTap(obj);
          } else if (obj is AudioInfo) {
            state.audioOnTap(obj, iconOnTapped);
          }
        },
        onLongPressed: state.onListItemLongPressed,
      ) as Widget;
    }).toList();

    ret.add(
      ValueListenableBuilder<double>(
          valueListenable: _bottomPanelHeightNotifier,
          builder: (context, height, _) {
            return SizedBox(
              height: height,
            );
          }),
    );

    return ret;
  }

  Widget _buildBottomPanelInternal(BuildContext context, BrowserViewMode mode) {
    if (mode == BrowserViewMode.playback) {
      return PlaybackPanel(
        onClose: state.onPlaybackPanelClosed,
        onPlayNext: state.playNext,
        onPlayPrevious: state.playPrevious,
        loopNotifier: state.loopNotifier,
      );
    }

    return ValueListenableBuilder<AudioListItemSelectedState>(
        valueListenable: _selectStateNotifier,
        builder: (context, selectState, _) {
          return SizedBox(
              height: 50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  MaterialButton(
                      onPressed: selectState.audioSelected ||
                              selectState.folderSelected
                          ? () {
                              _showNewFolderDialog(context);
                            }
                          : null,
                      child: const Icon(Icons.drive_file_move_outline)),
                  MaterialButton(
                      onPressed: selectState.audioSelected ||
                              selectState.folderSelected
                          ? () {
                              state.deleteSelected();
                            }
                          : null,
                      child: const Icon(Icons.delete_outlined)),
                  MaterialButton(
                      child: const Icon(Icons.create_new_folder_outlined),
                      onPressed: () {
                        //New Folder Dialog
                        showNewFolderDialog(context, (value) {
                          state.newFolder(value);
                        });
                      }),
                ],
              ));
        });
  }

  Widget _buildBottomPanel(BuildContext context, BrowserViewMode mode) {
    if (mode == BrowserViewMode.normalAnimationDone) {
      return Container();
    }

    bool animateToNormal = (mode == BrowserViewMode.normal);

    Widget bottomPanel =
        _buildBottomPanelInternal(context, animateToNormal ? _lastMode : mode);

    Timer.run(() {
      if (animateToNormal) {
        _animationController.reverse();
      } else {
        _animationController.reset();
        _animationController.forward();
      }
    });
    log.debug("show playback panel, mode:$mode");
    _lastMode = mode;

    return Container(
      // color: Colors.black,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          // bottomLeft: Radius.circular(10),
          // bottomRight: Radius.circular(10)
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2), // changes position of shadow
          ),
        ],
      ),
      child: GestureDetector(
        onVerticalDragStart: (details) {
          log.debug("Drag Start:$details");
          _startDragPos = details.localPosition.dy;
          _currentSizeRate = _animationController.value;
          _quickSwiped = false;
          _bottomPanelHeight = _calculateBottomPanelHeight();
        },
        onVerticalDragEnd: (details) {
          log.debug("Drag End:$details");
          if (_animationController.value < 0.5 || _quickSwiped) {
            log.debug(
                "controller value:${_animationController.value}, reverse()");
            _animationController.reverse();
          } else {
            log.debug(
                "controller value:${_animationController.value}, forward()");
            _animationController.forward();
          }
        },
        onVerticalDragUpdate: (details) {
          // log.debug("Drag Update: "
          //     "delta: ${details.delta}, "
          //     "primaryDelta: ${details.primaryDelta}, "
          //     "globalPosition: ${details.globalPosition}, "
          //     "localPosition: ${details.localPosition}, ");
          if (details.delta.dy > 5) _quickSwiped = true;
          _endDragPos = details.localPosition.dy;
          final off = _endDragPos - _startDragPos;
          final rate = off / _bottomPanelHeight;
          _animationController.value = _currentSizeRate - rate;
          // log.debug(
          //     "animation controller value:${_currentSizeRate - rate}");
        },
        child: Container(
          //The transparent color is IMPORANT! this enable the hit test of GestureDector
          color: Colors.transparent,
          child: NotificationListener(
            onNotification: (SizeChangedLayoutNotification notification) {
              Timer.run(() {
                _bottomPanelHeightNotifier.value =
                    _calculateBottomPanelHeight();
              });
              return true;
            },
            child: SizeChangedLayoutNotifier(
              child: SizeTransition(
                key: _bottomPanelKey,
                axisAlignment: -1,
                sizeFactor: _sizeAnimation,
                child: bottomPanel,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ValueListenableBuilder<FolderInfo>(
        valueListenable: _folderNotifier,
        builder: (context, folderInfo, _) {
          return Stack(
            children: [
              Column(
                children: [
                  // Audio Item List
                  Expanded(
                    child: ListView(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics()),
                      children: folderInfo.subObjects.isEmpty ||
                              (widget.folderOnly &&
                                  folderInfo.subfoldersMap == null)
                          ? [
                              Container(
                                  alignment: Alignment.center,
                                  child: const Text(
                                    "Here is nothing...",
                                    style: TextStyle(fontSize: 40),
                                  ))
                            ]
                          : _listItemWidgets(folderInfo),
                    ),
                  ),
                ],
              ),

              // Bottom Panels
              Align(
                alignment: Alignment.bottomCenter,
                child: ValueListenableBuilder<BrowserViewMode>(
                    valueListenable: modeNotifier,
                    builder: (context, mode, _) {
                      final panel = _buildBottomPanel(context, mode);
                      return panel;
                    }),
              ),
            ],
          );
        });
  }
}
