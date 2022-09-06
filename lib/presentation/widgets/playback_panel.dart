import 'package:brecorder/core/audio_agent.dart';
import 'package:brecorder/core/logging.dart';
import 'package:brecorder/domain/entities.dart';
import 'package:brecorder/presentation/ploc/browser_view_state.dart';
import 'package:flutter/material.dart';

import '../../core/service_locator.dart';
import '../../core/utils.dart';

final log = Logger('PlaybackPanel');

class PlaybackPanel extends StatefulWidget {
  final EdgeInsets padding;
  final void Function()? onPlayPrevious;
  final void Function()? onPlayNext;
  final void Function()? onClose;
  final ValueNotifier<AudioPositionInfo>? positionNotifier;
  final ValueNotifier<PlayLoopType> loopNotifier;
  const PlaybackPanel({
    Key? key,
    this.onPlayNext,
    this.onPlayPrevious,
    this.onClose,
    this.padding =
        const EdgeInsets.only(top: 5, bottom: 15, left: 10, right: 10),
    this.positionNotifier,
    required this.loopNotifier,
  }) : super(key: key);

  @override
  State<PlaybackPanel> createState() => _PlaybackPanelState();
}

class _PlaybackPanelState extends State<PlaybackPanel> {
  final agent = sl.get<AudioServiceAgent>();
  final playingNotifier = ValueNotifier(false);
  AudioInfo? currentAudio;
  late final ValueNotifier<AudioPositionInfo>? positionNotifier;
  bool needResume = false;

  @override
  void initState() {
    super.initState();
    if (widget.positionNotifier == null) {
      positionNotifier = ValueNotifier(const AudioPositionInfo(0, 0));
    } else {
      positionNotifier = widget.positionNotifier;
    }
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

  void _updatePostion(double seconds) {
    positionNotifier!.value =
        AudioPositionInfo(positionNotifier!.value.duration, seconds);
  }

  void _positionListener(_, data) {
    final seconds = data / 1000;
    if (seconds == positionNotifier!.value.position) {
      return;
    }

    _updatePostion(seconds);
  }

  void _playingListener(event, audio) {
    if (event == AudioEventType.started) {
      playingNotifier.value = true;
      currentAudio = audio;
      positionNotifier!.value =
          AudioPositionInfo(currentAudio!.durationMS / 1000.0, 0.0);
    } else {
      playingNotifier.value = false;
    }
  }

  @override
  Widget build(context) {
    return
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
        //       spreadRadius: 8,
        //       blurRadius: 8,
        //       // offset: Offset(0, 2), // changes position of shadow
        //     ),
        //   ],
        // ),
        Material(
      type: MaterialType.transparency,
      child: Container(
        padding: widget.padding,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                    visualDensity: VisualDensity.compact,
                    splashRadius: 20,
                    tooltip: "close",
                    iconSize: 15,
                    onPressed: () {
                      widget.onClose?.call();
                    },
                    icon: const Icon(Icons.close)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(onPressed: () {}, icon: const Icon(Icons.tune)),
                IconButton(
                    onPressed: () {}, icon: const Icon(Icons.timer_outlined)),
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
            ValueListenableBuilder<AudioPositionInfo>(
                valueListenable: positionNotifier!,
                builder: (context, pos, _) {
                  return Column(
                    children: [
                      Slider(
                        value:
                            pos.duration == 0 ? 0 : pos.position / pos.duration,
                        onChanged: (val) {
                          final seconds = val * pos.duration;
                          // log.debug("change to $val");
                          _updatePostion(seconds);
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
                          final targetPos = (val * pos.duration * 1000).toInt();
                          agent.seekTo(targetPos);
                          if (needResume) {
                            log.debug("paused playing, resume it");
                            agent.resumePlay();
                            needResume = false;
                          }
                        },
                      ),
                      // LinearProgressIndicator(
                      //   color: Colors.red,
                      //   // backgroundColor: Colors.red,
                      //   value: metrics.duration == 0
                      //       ? 0
                      //       : metrics.position / metrics.duration,
                      // ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("0.00"),
                          Text((pos.position).toStringAsFixed(2)),
                          Text((pos.duration).toStringAsFixed(2)),
                        ],
                      ),
                    ],
                  );
                }),
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
