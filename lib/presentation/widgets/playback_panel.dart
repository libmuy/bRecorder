import 'package:brecorder/core/audio_agent.dart';
import 'package:brecorder/core/logging.dart';
import 'package:brecorder/domain/entities.dart';
import 'package:brecorder/presentation/ploc/browser_view_state.dart';
import 'package:brecorder/presentation/widgets/icons/audio_icons.dart';
import 'package:brecorder/presentation/widgets/rect_slider.dart';
import 'package:brecorder/presentation/widgets/sized_animated.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../core/service_locator.dart';
import '../../core/utils.dart';
import 'on_off_icon_button.dart';

final log = Logger('PlaybackPanel');

class PlaybackPanel extends StatefulWidget {
  final EdgeInsets padding;
  final void Function()? onPlayPrevious;
  final void Function()? onPlayNext;
  final void Function()? onClose;
  final ValueNotifier<PlayLoopType> loopNotifier;
  const PlaybackPanel({
    Key? key,
    this.onPlayNext,
    this.onPlayPrevious,
    this.onClose,
    this.padding =
        const EdgeInsets.only(top: 5, bottom: 15, left: 10, right: 10),
    required this.loopNotifier,
  }) : super(key: key);

  @override
  State<PlaybackPanel> createState() => _PlaybackPanelState();
}

class _PlaybackPanelState extends State<PlaybackPanel>
    with TickerProviderStateMixin {
  final agent = sl.get<AudioServiceAgent>();
  final playingNotifier = ValueNotifier(false);
  AudioInfo? currentAudio;
  final _positionNotifier = ValueNotifier(0.0);
  final _durationNotifier = ValueNotifier(0.0);
  bool needResume = false;

  //Options Animation controll
  final _pitchShowNotifier = ValueNotifier(false);
  final _pitchValueNotifier = ValueNotifier(0.0);
  final _volumeShowNotifier = ValueNotifier(false);
  final _volumeValueNotifier = ValueNotifier(0.0);
  final _speedShowNotifier = ValueNotifier(false);
  final _speedValueNotifier = ValueNotifier(0.0);
  final _timerShowNotifier = ValueNotifier(false);
  final _timerValueNotifier = ValueNotifier(0.0);
  final _waveformOnNotifier = ValueNotifier(false);
  late final _optionPanelShowNotifiers = {
    _OptionPanelType.pitch: _pitchShowNotifier,
    _OptionPanelType.volume: _volumeShowNotifier,
    _OptionPanelType.speed: _speedShowNotifier,
    _OptionPanelType.timer: _timerShowNotifier,
  };

  @override
  void initState() {
    super.initState();
    agent.addAudioEventListener(
        AudioEventType.positionUpdate, _positionListener);
    agent.addAudioEventListener(AudioEventType.started, _playingListener);
    agent.addAudioEventListener(AudioEventType.paused, _playingListener);
    agent.addAudioEventListener(AudioEventType.stopped, _playingListener);
  }

  @override
  void dispose() {
    super.dispose();
    agent.removeAudioEventListener(
        AudioEventType.positionUpdate, _positionListener);
    agent.removeAudioEventListener(AudioEventType.started, _playingListener);
    agent.removeAudioEventListener(AudioEventType.paused, _playingListener);
    agent.removeAudioEventListener(AudioEventType.stopped, _playingListener);
  }

  void _positionListener(_, data) {
    final seconds = data / 1000;

    _positionNotifier.value = seconds;
  }

  void _playingListener(event, audio) {
    if (event == AudioEventType.started) {
      playingNotifier.value = true;
      currentAudio = audio;
      _durationNotifier.value = currentAudio!.durationMS / 1000.0;
    } else {
      playingNotifier.value = false;
    }
  }

  void _showOptionPanel(_OptionPanelType panel, bool show) {
    if (!show) {
      _optionPanelShowNotifiers[panel]!.value = false;
      return;
    } else {
      _optionPanelShowNotifiers[panel]!.value = true;
      return;
    }

    // for (var type in _OptionPanelType.values) {
    //   if (type == panel) {
    //     _optionPanelShowNotifiers[type]!.value = true;
    //   } else {
    //     _optionPanelShowNotifiers[type]!.value = false;
    //   }
    // }
  }

  @override
  Widget build(context) {
    return Container(
      // decoration: BoxDecoration(
      //   color: Colors.black,
      //   borderRadius: const BorderRadius.only(
      //     topLeft: Radius.circular(10),
      //     topRight: Radius.circular(10),
      //     // bottomLeft: Radius.circular(10),
      //     // bottomRight: Radius.circular(10)
      //   ),
      //   boxShadow: [
      //     BoxShadow(
      //       color: Colors.black.withOpacity(0.4),
      //       spreadRadius: 5,
      //       blurRadius: 5,
      //       // offset: Offset(0, 2), // changes position of shadow
      //     ),
      //   ],
      // ),
      padding: widget.padding,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IntrinsicHeight(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 50,
                  ),
                  Container(
                      height: double.infinity,
                      alignment: Alignment.topCenter,
                      child: Container(
                        height: 4,
                        width: MediaQuery.of(context).size.width / 5,
                        decoration: BoxDecoration(
                          color: Theme.of(context).selectedRowColor,
                          borderRadius:
                              const BorderRadius.all(Radius.circular(3)),
                        ),
                      )),
                  SizedBox(
                    width: 50,
                    child: IconButton(
                        visualDensity: VisualDensity.compact,
                        splashRadius: 20,
                        tooltip: "close",
                        iconSize: 15,
                        onPressed: () {
                          widget.onClose?.call();
                        },
                        icon: const Icon(Icons.close)),
                  ),
                ],
              ),
            ),
            Container(
                margin: const EdgeInsets.only(
                  left: 10,
                  right: 10,
                ),
                padding: const EdgeInsets.only(
                  left: 10,
                  right: 10,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(10),
                      topRight: Radius.circular(10),
                      bottomLeft: Radius.circular(10),
                      bottomRight: Radius.circular(10)),
                  // boxShadow: [
                  //   BoxShadow(
                  //     color: Theme.of(context)
                  //         .primaryColor
                  //         .withOpacity(0.4),
                  //     spreadRadius: 8,
                  //     blurRadius: 8,
                  //     // offset: Offset(0, 2), // changes position of shadow
                  //   ),
                  // ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedAnimated(
                      showNotifier: _pitchShowNotifier,
                      child: Row(children: [
                        OverlayIcon.pitchRemoveIcon(),
                        Expanded(
                          child: RectThumbSlider(
                            valueNotifier: _pitchValueNotifier,
                            onChanged: ((value) =>
                                _pitchValueNotifier.value = value),
                          ),
                        ),
                        OverlayIcon.pitchAddIcon(),
                      ]),
                    ),
                    SizedAnimated(
                      showNotifier: _volumeShowNotifier,
                      child: Row(children: [
                        OverlayIcon.volumeRemoveIcon(),
                        Expanded(
                          child: RectThumbSlider(
                            valueNotifier: _volumeValueNotifier,
                            onChanged: ((value) =>
                                _volumeValueNotifier.value = value),
                          ),
                        ),
                        OverlayIcon.volumeAddIcon(),
                      ]),
                    ),
                    SizedAnimated(
                      showNotifier: _speedShowNotifier,
                      child: Row(children: [
                        OverlayIcon.speedRemoveIcon(),
                        Expanded(
                          child: RectThumbSlider(
                            valueNotifier: _speedValueNotifier,
                            onChanged: ((value) =>
                                _speedValueNotifier.value = value),
                          ),
                        ),
                        OverlayIcon.speedAddIcon(),
                      ]),
                    ),
                    SizedAnimated(
                      showNotifier: _timerShowNotifier,
                      child: Row(children: [
                        OverlayIcon.timerRemoveIcon(),
                        Expanded(
                          child: RectThumbSlider(
                            valueNotifier: _timerValueNotifier,
                            onChanged: ((value) =>
                                _timerValueNotifier.value = value),
                          ),
                        ),
                        OverlayIcon.timerAddIcon(),
                      ]),
                    ),
                  ],
                )),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OnOffIconButton(
                  icon: Icons.graphic_eq,
                  stateNotifier: _pitchShowNotifier,
                  onStateChanged: (state) {
                    _showOptionPanel(_OptionPanelType.pitch, state);
                  },
                ),
                OnOffIconButton(
                  icon: Icons.volume_up_outlined,
                  stateNotifier: _volumeShowNotifier,
                  onStateChanged: (state) {
                    _showOptionPanel(_OptionPanelType.volume, state);
                  },
                ),
                OnOffIconButton(
                  icon: Icons.fast_forward,
                  stateNotifier: _speedShowNotifier,
                  onStateChanged: (state) {
                    _showOptionPanel(_OptionPanelType.speed, state);
                  },
                ),
                OnOffIconButton(
                  icon: Icons.timer,
                  stateNotifier: _timerShowNotifier,
                  onStateChanged: (state) {
                    _showOptionPanel(_OptionPanelType.timer, state);
                  },
                ),
                IconButton(
                    onPressed: () {
                      final loopTypeList = [
                        PlayLoopType.noLoop,
                        PlayLoopType.list,
                        PlayLoopType.loopOne,
                        PlayLoopType.loopAll,
                        PlayLoopType.random,
                      ];
                      final current =
                          loopTypeList.indexOf(widget.loopNotifier.value);
                      widget.loopNotifier.value =
                          loopTypeList[(current + 1) % loopTypeList.length];
                    },
                    icon: ValueListenableBuilder<PlayLoopType>(
                        valueListenable: widget.loopNotifier,
                        builder: (context, loopType, _) {
                          switch (loopType) {
                            case PlayLoopType.loopAll:
                              return const Icon(Icons.repeat_on_outlined);
                            case PlayLoopType.loopOne:
                              return const Icon(Icons.repeat_one_on_outlined);
                            case PlayLoopType.random:
                              return const Icon(Icons.shuffle_on_outlined);
                            case PlayLoopType.noLoop:
                              return const Icon(Icons.repeat);
                            case PlayLoopType.list:
                              // return Stack(
                              //   children: const [
                              //     Align(
                              //         child: Icon(
                              //             size: 20, Icons.playlist_play)),
                              //     Icon(Icons.redo),
                              //   ],
                              // );
                              return const Icon(Icons.low_priority);
                          }
                        })),
                IconButton(
                    onPressed: () {}, icon: const Icon(Icons.delete_outline)),
              ],
            ),
            RectThumbSlider(
              thumbSize: 10,
              valueNotifier: _positionNotifier,
              maxNotifier: _durationNotifier,
              onChanged: (val) {
                _positionNotifier.value = val;
              },
              onChangeStart: (val) {
                log.debug("start drag slider, state:${agent.state}");
                if (agent.state == AudioState.playing) {
                  log.debug("playing, pause it");
                  needResume = true;
                  agent.pausePlay();
                }
              },
              onChangeEnd: (val) {
                log.debug("end drag slider, state:${agent.state}");
                final targetPos = (val * 1000).toInt();
                agent.seekTo(targetPos);
                if (needResume) {
                  log.debug("paused playing, resume it");
                  agent.resumePlay();
                  needResume = false;
                }
              },
            ),
            ValueListenableBuilder<bool>(
                valueListenable: playingNotifier,
                builder: (context, playing, _) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                          onPressed: () {
                            widget.onPlayPrevious?.call();
                          },
                          icon: const Icon(Icons.skip_previous)),
                      IconButton(
                          onPressed: playing
                              ? () {
                                  agent.seekToRelative(-5000);
                                }
                              : null,
                          icon: const Icon(Icons.replay_5)),
                      playing
                          ? IconButton(
                              onPressed: () {
                                agent.pausePlay();
                              },
                              icon: const Icon(Icons.pause))
                          : IconButton(
                              onPressed: () {
                                if (agent.state == AudioState.playPaused) {
                                  agent.resumePlay();
                                } else {
                                  agent.startPlay(currentAudio!);
                                }
                              },
                              icon: const Icon(Icons.play_arrow)),
                      IconButton(
                          onPressed: playing
                              ? () {
                                  agent.seekToRelative(5000);
                                }
                              : null,
                          icon: const Icon(Icons.forward_5)),
                      IconButton(
                          onPressed: () {
                            widget.onPlayNext?.call();
                          },
                          icon: const Icon(Icons.skip_next)),
                    ],
                  );
                })
          ],
        ),
      ),
    );
  }
}

enum _OptionPanelType {
  pitch,
  volume,
  speed,
  timer,
}
