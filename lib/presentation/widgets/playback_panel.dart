import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/audio_agent.dart';
import '../../core/global_info.dart';
import '../../core/logging.dart';
import '../../core/service_locator.dart';
import '../../core/utils/utils.dart';
import '../../domain/entities.dart';
import 'animated_sized_panel.dart';
import 'bubble_dialog.dart';
import 'on_off_icon_button.dart';
import 'rect_slider.dart';
import 'square_icon_button.dart';
import 'waveform/waveform.dart';

final log = Logger('PlaybackPanel',
//  level: LogLevel.debug
 );

class PlaybackPanel extends StatefulWidget {
  final EdgeInsets padding;
  final void Function()? onPlayPrevious;
  final void Function()? onPlayNext;
  final void Function()? onClose;
  final ValueNotifier<PlayLoopType> loopNotifier;
  const PlaybackPanel({
    super.key,
    this.onPlayNext,
    this.onPlayPrevious,
    this.onClose,
    this.padding =
        const EdgeInsets.only(top: 10, bottom: 15, left: 5, right: 5),
    required this.loopNotifier,
  });

  @override
  State<PlaybackPanel> createState() => _PlaybackPanelState();
}

class _PlaybackPanelState extends State<PlaybackPanel>
    with TickerProviderStateMixin {
  AudioInfo? currentAudio;
  final agent = sl.get<AudioServiceAgent>();
  final _playingNotifier = ValueNotifier(false);
  final _positionNotifier = ValueNotifier(0.0);
  final _durationNotifier = ValueNotifier(0.0);
  final _titleNotifier = ValueNotifier("");
  bool needResume = false;
  Timer? _timer;
  final _waveformDataNotifier = ValueNotifier(Float32List(0));
  final WaveformDelegate _waveformDelegate = WaveformDelegate();

  //Options Animation controll
  static final _pitchDefaultValue = GlobalInfo.PLATFORM_PITCH_DEFAULT_VALUE;
  static const _volumeDefaultValue = 1.0;
  static const _speedDefaultValue = 1.0;
  static const _timerDefaultValue = 0.0;
  static const _repeatDefaultValue = 0.0;
  final _pitchValueNotifier = ValueNotifier(_pitchDefaultValue);
  final _volumeValueNotifier = ValueNotifier(_volumeDefaultValue);
  final _speedValueNotifier = ValueNotifier(_speedDefaultValue);
  final _timerValueNotifier = ValueNotifier(0.0);
  final _repeatValueNotifier = ValueNotifier(_repeatDefaultValue);
  late final _expandNotifier = sl.playbackPanelExpandNotifier;
  double? _panelBodyHeight;
  final _pitchButtonKey = GlobalKey();
  final _volumeButtonKey = GlobalKey();
  final _speedButtonKey = GlobalKey();
  final _timerButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    agent.addAudioEventListener(
        AudioEventType.positionUpdate, _positionListener);
    agent.addAudioEventListener(AudioEventType.started, _playingListener);
    agent.addAudioEventListener(AudioEventType.paused, _playingListener);
    agent.addAudioEventListener(AudioEventType.stopped, _playingListener);
    agent.addAudioEventListener(AudioEventType.complete, _playingListener);
  }

  @override
  void dispose() {
    super.dispose();
    agent.removeAudioEventListener(
        AudioEventType.positionUpdate, _positionListener);
    agent.removeAudioEventListener(AudioEventType.started, _playingListener);
    agent.removeAudioEventListener(AudioEventType.paused, _playingListener);
    agent.removeAudioEventListener(AudioEventType.stopped, _playingListener);
    agent.removeAudioEventListener(AudioEventType.complete, _playingListener);
  }

  String _timerLabelFormatter(double value) {
    int sec = value.toInt();
    int s = sec % 60;
    int m = sec ~/ 60 % 60;
    int h = sec ~/ 3600;
    var ret = h > 0 ? "${h.toString().padLeft(2, "0")}:" : "";
    ret += "${m.toString().padLeft(2, "0")}:${s.toString().padLeft(2, "0")}";
    return ret;
  }

  String _speedLabelFormatter(double value) => "${value.toStringAsFixed(1)}x";

  String _repeatLabelFormatter(double value) {
    for (final loop in PlayLoopType.values) {
      if (loop.doubleValue == value) return loop.label;
    }

    return "";
  }

  IconData _repeatIconGenerator(double value) {
    for (final loop in PlayLoopType.values) {
      if (loop.doubleValue == value) return loop.icon;
    }

    return Icons.repeat;
  }

  void _positionListener(_, data) {
    final seconds = data / 1000;
    // log.debug("update position:$seconds");
    if (seconds > _durationNotifier.value) return;
    _positionNotifier.value = seconds;
    _waveformDelegate.setPosition(seconds, dispatchNotification: false);
  }

  void _playingListener(event, audio) async {
    if (event == AudioEventType.started) {
      _playingNotifier.value = true;
      currentAudio = audio;
      currentAudio!.waveformData.then((data) {
        log.debug("audio($currentAudio)'s waveform length:${data?.length}");
        _waveformDataNotifier.value = data ?? Float32List(0);
      });
      final seconds = currentAudio!.durationMS! / 1000.0;
      if (seconds < _positionNotifier.value) {
        _positionNotifier.value = seconds;
      }
      _durationNotifier.value = seconds;
      _titleNotifier.value = currentAudio!.name;

      if (await currentAudio!.hasPerf) {
        currentAudio!.pref.then((audioPref) async {
          await agent.setPitch(audioPref.pitch);
          _pitchValueNotifier.value = audioPref.pitch;

          await agent.setVolume(audioPref.volume);
          _volumeValueNotifier.value = audioPref.volume;

          await agent.setSpeed(audioPref.speed);
          _speedValueNotifier.value = audioPref.speed;
        });
      } else {
        _pitchValueNotifier.value = _pitchDefaultValue;
        _volumeValueNotifier.value = _volumeDefaultValue;
        _speedValueNotifier.value = _speedDefaultValue;
      }
    } else {
      _playingNotifier.value = false;
    }
  }

  // void _showOptionPanel(_OptionPanelType panel, bool show) {
  //   if (!show) {
  //     _optionPanelShowNotifiers[panel]!.value = false;
  //     return;
  //   } else {
  //     _optionPanelShowNotifiers[panel]!.value = true;
  //     return;
  //   }

  //   // for (var type in _OptionPanelType.values) {
  //   //   if (type == panel) {
  //   //     _optionPanelShowNotifiers[type]!.value = true;
  //   //   } else {
  //   //     _optionPanelShowNotifiers[type]!.value = false;
  //   //   }
  //   // }
  // }

  void _waveformPositionListener(AudioPositionInfo metrics) {
    // log.debug("metrics updated: pos:${metrics.position.toStringAsFixed(2)}");
    // waveformMetricsNotifier.value = metrics;
    // if (_playing) {
    //   agent.seekTo((metrics.position * 1000).toInt());
    // }
    _positionNotifier.value = metrics.position;
  }

  void _pauseForSeek() {
    if (agent.state == AudioState.playing) {
      log.debug("playing, pause it");
      needResume = true;
      agent.pausePlay();
    }
  }

  void _seekWhilePlaying(int positionMs) {
    agent.seekTo(positionMs);
    if (needResume) {
      log.debug("paused playing, resume it");
      agent.resumePlay();
      needResume = false;
    }
  }

  Widget _buildWaveform(BuildContext context) {
    return ValueListenableBuilder<bool>(
        valueListenable: _expandNotifier,
        builder: (context, show, _) {
          log.debug("build waveform");
          if (_panelBodyHeight == null) {
            return Container();
          }
          final screenHeight = MediaQuery.of(context).size.height;
          final statusBarHeight = MediaQuery.of(context).viewPadding.top;
          final height = screenHeight - statusBarHeight - _panelBodyHeight!;
          log.debug("screen height:$screenHeight");
          log.debug("statusbar height:$statusBarHeight");
          log.debug("playback panel body height:$_panelBodyHeight");
          // log.debug("playback panel body height:$_panelHeaderHeight");
          log.debug("waveform height:$height");
          return AnimatedSizedPanel(
              debugLabel: "WaveForm",
              relayNotification: true,
              dragListenerPriority: 0,
              dragNotifier: sl.playbackPanelDragNotifier,
              show: show,
              onAnimationStatusChanged: (from, to) {
                if (to == AnimationStatus.completed) {
                  _expandNotifier.update(newValue: true, forceNotNotify: true);
                } else if (to == AnimationStatus.dismissed) {
                  _expandNotifier.update(newValue: false, forceNotNotify: true);
                }
              },
              child: SizedBox(
                height: height,
                child: ValueListenableBuilder<Float32List>(
                    valueListenable: _waveformDataNotifier,
                    builder: (context, data, _) {
                      return Waveform(
                        data.toList(),
                        positionListener: _waveformPositionListener,
                        startSeek: (_) => _pauseForSeek(),
                        endSeek: (positionInfo) {
                          final positionMs =
                              (positionInfo.position * 1000).toInt();
                          _seekWhilePlaying(positionMs);
                        },
                        delegate: _waveformDelegate,
                      );
                    }),
              ));
        });
  }

  Future<void> _showOptionPanel(
      BuildContext context, GlobalKey key, Widget dialog) async {
    final box = key.currentContext!.findRenderObject() as RenderBox;
    var pos = box.localToGlobal(Offset.zero);
    pos = Offset((pos.dx + box.size.width / 2), pos.dy);

    await showBubbleDialog(context, dialog: dialog, position: pos);
  }

  @override
  Widget build(context) {
    if (_panelBodyHeight == null) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        log.debug("playback panel post frame callback, size:${context.size}");
        if (context.size != null) {
          _panelBodyHeight = context.size!.height;
          _expandNotifier.notify();
        }
      });
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        /*============================================================*\ 
          Header
        \*============================================================*/
        // const Divider(
        //   height: 1,
        // ),
        GestureDetector(
          onVerticalDragStart: (details) => sl.playbackPanelDragNotifier.value =
              AnimatedSizedPanelDragEvent.fromDragStartEvent(details),
          onVerticalDragEnd: (details) => sl.playbackPanelDragNotifier.value =
              AnimatedSizedPanelDragEvent.fromDragEndEvent(details),
          onVerticalDragUpdate: (details) => sl.playbackPanelDragNotifier
              .value = AnimatedSizedPanelDragEvent.fromDragUpdateEvent(details),
          onTap: () {
            _expandNotifier.value = !_expandNotifier.value;
          },
          child: Container(
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 47, 47, 47),
              // border: Border.all(
              //   width: 0.5,
              //   color: Color.fromARGB(255, 53, 53, 53),
              // ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            // color: Colors.transparent,
            child: IntrinsicHeight(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 50,
                  ),
                  // const Icon(
                  //   Icons.drag_handle,
                  //   size: 30,
                  // ),
                  ValueListenableBuilder<String>(
                    valueListenable: _titleNotifier,
                    builder: (context, value, _) {
                      return Text(_titleNotifier.value);
                    })
                              ,
                  SizedBox(
                    width: 50,
                    child: IconButton(
                        constraints: const BoxConstraints(minHeight: 30),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        splashRadius: 15,
                        tooltip: "close",
                        iconSize: 15,
                        onPressed: () {
                          widget.onClose?.call();
                          // _showWaveformNotifier.value =
                          //     !_showWaveformNotifier.value;
                        },
                        icon: const Icon(Icons.close)),
                  ),
                ],
              ),
            ),
          ),
        ),
        // const Divider(
        //   height: 1,
        // ),
        _buildWaveform(context),
        const SizedBox(
          height: 20,
        ),
        /*============================================================*\ 
          Option Panels
        \*============================================================*/
        Padding(
          padding: widget.padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // ================ PTICH Option Button =====================
                  OnOffIconButton(
                    key: _pitchButtonKey,
                    icon: Icons.graphic_eq,
                    defaultValue: _pitchDefaultValue,
                    valueNotifier: _pitchValueNotifier,
                    onTap: () async {
                      await _showOptionPanel(
                          context,
                          _pitchButtonKey,
                          RectThumbSlider(
                            icon: Icons.graphic_eq,
                            initValue: _pitchDefaultValue,
                            divisions: 20,
                            min: GlobalInfo.PLATFORM_PITCH_MIN_VALUE,
                            max: GlobalInfo.PLATFORM_PITCH_MAX_VALUE,
                            valueNotifier: _pitchValueNotifier,
                            onChanged: ((value) =>
                                _pitchValueNotifier.value = value),
                            onChangeEnd: (value) {
                              agent.setPitch(value);
                              currentAudio!.pref.then((audioPerf) {
                                audioPerf.pitch = value;
                                currentAudio!.savePref();
                              });
                            },
                          ));
                    },
                  ),
                  // ================ VOLUME Option Button =====================
                  OnOffIconButton(
                    key: _volumeButtonKey,
                    icon: Icons.volume_up_outlined,
                    defaultValue: _volumeDefaultValue,
                    valueNotifier: _volumeValueNotifier,
                    onTap: () async {
                      await _showOptionPanel(
                          context,
                          _volumeButtonKey,
                          RectThumbSlider(
                            initValue: _volumeDefaultValue,
                            min: 0,
                            max: 1,
                            divisions: 20,
                            icon: Icons.volume_up_outlined,
                            valueNotifier: _volumeValueNotifier,
                            onChanged: ((value) =>
                                _volumeValueNotifier.value = value),
                            onChangeEnd: (value) {
                              agent.setVolume(value);
                              currentAudio!.pref.then((audioPerf) {
                                audioPerf.volume = value;
                                currentAudio!.savePref();
                              });
                            },
                          ));
                    },
                  ),
                  // ================ SPEED Option Button =====================
                  OnOffIconButton(
                    key: _speedButtonKey,
                    icon: Icons.fast_forward,
                    defaultValue: _speedDefaultValue,
                    valueNotifier: _speedValueNotifier,
                    labelFormater: _speedLabelFormatter,
                    onTap: () async {
                      await _showOptionPanel(
                          context,
                          _speedButtonKey,
                          RectThumbSlider(
                            initValue: _speedDefaultValue,
                            min: 0.2,
                            max: 3.0,
                            divisions: 28,
                            icon: Icons.fast_forward_outlined,
                            valueNotifier: _speedValueNotifier,
                            labelFormater: _speedLabelFormatter,
                            onChanged: ((value) =>
                                _speedValueNotifier.value = value),
                            onChangeEnd: (value) {
                              agent.setSpeed(value);
                              currentAudio!.pref.then((audioPerf) {
                                audioPerf.speed = value;
                                currentAudio!.savePref();
                              });
                            },
                          ));
                    },
                  ),
                  // ================ TIMER Option Button =====================
                  OnOffIconButton(
                    key: _timerButtonKey,
                    icon: Icons.timer,
                    defaultValue: _timerDefaultValue,
                    valueNotifier: _timerValueNotifier,
                    labelFormater: _timerLabelFormatter,
                    labelAnimation: false,
                    onTap: () async {
                      await _showOptionPanel(
                          context,
                          _timerButtonKey,
                          RectThumbSlider(
                            initValue: _timerDefaultValue,
                            min: 0,
                            max: 7200,
                            divisions: 48,
                            icon: Icons.timer,
                            valueNotifier: _timerValueNotifier,
                            labelFormater: _timerLabelFormatter,
                            onChanged: ((value) =>
                                _timerValueNotifier.value = value),
                            onChangeEnd: (value) {
                              log.debug("timer change:$value");
                              if (_timerValueNotifier.value <= 0) {
                                _timer?.cancel();
                                _timer = null;
                                return;
                              }
                              _timer ??= Timer.periodic(
                                  const Duration(seconds: 1), (timer) {
                                var value = _timerValueNotifier.value.toInt();
                                if (value > 0) {
                                  _timerValueNotifier.value = value - 1;
                                } else {
                                  agent.stopPlay();
                                  _timer!.cancel();
                                  _timer = null;
                                }
                              });
                            },
                          ));
                    },
                  ),
                  // ================ REPEAT Option Button =====================
                  OnOffIconButton(
                    duration: const Duration(milliseconds: 50),
                    defaultValue: _repeatDefaultValue,
                    valueNotifier: _repeatValueNotifier,
                    labelFormater: _repeatLabelFormatter,
                    iconGenerator: _repeatIconGenerator,
                    onTap: () {
                      const loopTypeList = [
                        PlayLoopType.noLoop,
                        PlayLoopType.list,
                        PlayLoopType.loopOne,
                        PlayLoopType.loopAll,
                        PlayLoopType.shuffle,
                      ];
                      var value = _repeatValueNotifier.value.toInt();
                      value = (value + 1) % 5;
                      widget.loopNotifier.value = loopTypeList[value];
                      _repeatValueNotifier.value = value.toDouble();
                    },
                  ),
                ],
              ),
              const SizedBox(
                height: 10,
              ),
              /*============================================================*\ 
                Playback Progress bar
              \*============================================================*/
              RectThumbSlider(
                thumbSize: 10,
                valueNotifier: _positionNotifier,
                maxNotifier: _durationNotifier,
                onChanged: (val) {
                  _positionNotifier.value = val;
                  _waveformDelegate.setPosition(val,
                      dispatchNotification: false);
                },
                onChangeStart: (val) {
                  log.debug("start drag slider, state:${agent.state}");
                  _pauseForSeek();
                },
                onChangeEnd: (val) {
                  log.debug("end drag slider, state:${agent.state}");
                  final targetPos = (val * 1000).toInt();
                  _seekWhilePlaying(targetPos);
                },
              ),
              const SizedBox(
                height: 15,
              ),
              /*============================================================*\ 
                Playback Control Buttons
              \*============================================================*/
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SquareIconButton(
                      padding: const EdgeInsets.all(10),
                      onPressed: () {
                        widget.onPlayPrevious?.call();
                      },
                      child: const Icon(Icons.skip_previous)),
                  SquareIconButton(
                      padding: const EdgeInsets.all(10),
                      onPressed: () {
                        agent.seekToRelative(-5000);
                      },
                      child: const Icon(Icons.replay_5)),
                  OnOffIconButton(
                    noLabel: true,
                    padding: const EdgeInsets.all(10),
                    stateNotifier: _playingNotifier,
                    icon: Icons.play_arrow,
                    onStateIcon: Icons.pause,
                    onStateChanged: (state) {
                      if (state) {
                        if (agent.state == AudioState.playPaused) {
                          agent.resumePlay();
                        } else {
                          agent.startPlay(currentAudio!);
                        }
                      } else {
                        agent.pausePlay();
                      }
                    },
                  ),
                  SquareIconButton(
                      padding: const EdgeInsets.all(10),
                      onPressed: () {
                        agent.seekToRelative(5000);
                      },
                      child: const Icon(Icons.forward_5)),
                  SquareIconButton(
                      padding: const EdgeInsets.all(10),
                      onPressed: () {
                        widget.onPlayNext?.call();
                      },
                      child: const Icon(Icons.skip_next)),
                ],
              )
            ],
          ),
        ),
      ],
    );
  }
}
