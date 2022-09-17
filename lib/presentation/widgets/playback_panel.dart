import 'dart:async';

import 'package:brecorder/core/audio_agent.dart';
import 'package:brecorder/core/global_info.dart';
import 'package:brecorder/core/logging.dart';
import 'package:brecorder/domain/entities.dart';
import 'package:brecorder/presentation/ploc/browser_view_state.dart';
import 'package:brecorder/presentation/widgets/rect_slider.dart';
import 'package:brecorder/presentation/widgets/sized_animated.dart';
import 'package:flutter/material.dart';

import '../../core/service_locator.dart';
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
  AudioInfo? currentAudio;
  final agent = sl.get<AudioServiceAgent>();
  final playingNotifier = ValueNotifier(false);
  final _positionNotifier = ValueNotifier(0.0);
  final _durationNotifier = ValueNotifier(0.0);
  bool needResume = false;
  Timer? _timer;

  //Options Animation controll
  static final _pitchDefaultValue = GlobalInfo.PLATFORM_PITCH_DEFAULT_VALUE;
  static const _volumeDefaultValue = 1.0;
  static const _speedDefaultValue = 1.0;
  static const _timerDefaultValue = 0.0;
  static const _repeatDefaultValue = 0.0;
  final _pitchShowNotifier = ValueNotifier(false);
  final _pitchValueNotifier = ValueNotifier(_pitchDefaultValue);
  final _volumeShowNotifier = ValueNotifier(false);
  final _volumeValueNotifier = ValueNotifier(_volumeDefaultValue);
  final _speedShowNotifier = ValueNotifier(false);
  final _speedValueNotifier = ValueNotifier(_speedDefaultValue);
  final _timerShowNotifier = ValueNotifier(false);
  final _timerValueNotifier = ValueNotifier(0.0);
  final _repeatValueNotifier = ValueNotifier(_repeatDefaultValue);
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
    switch (value.toInt()) {
      case 0:
        return "";
      case 1:
        return "List";
      case 2:
        return "One";
      case 3:
        return "Loop";
      case 4:
        return "Shuffle";
    }

    return "";
  }

  IconData _repeatIconGenerator(double value) {
    switch (value.toInt()) {
      case 0:
        return Icons.repeat;
      case 1:
        return Icons.low_priority;
      case 2:
        return Icons.repeat_one;
      case 3:
        return Icons.repeat;
      case 4:
        return Icons.shuffle;
    }

    return Icons.repeat;
  }

  void _positionListener(_, data) {
    final seconds = data / 1000;

    if (seconds > _durationNotifier.value) return;
    _positionNotifier.value = seconds;
  }

  void _playingListener(event, audio) async {
    if (event == AudioEventType.started) {
      playingNotifier.value = true;
      currentAudio = audio;
      final seconds = currentAudio!.durationMS / 1000.0;
      if (seconds >= _positionNotifier.value) {
        _durationNotifier.value = seconds;
      }

      if (await currentAudio!.hasPerf) {
        currentAudio!.pref.then((audioPref) async {
          if (audioPref.pitch != _pitchDefaultValue) {
            await agent.setPitch(audioPref.pitch);
            _pitchValueNotifier.value = audioPref.pitch;
          }
          if (audioPref.volume != _volumeDefaultValue) {
            await agent.setVolume(audioPref.volume);
            _volumeValueNotifier.value = audioPref.volume;
          }

          if (audioPref.speed != _speedDefaultValue) {
            await agent.setSpeed(audioPref.speed);
            _speedValueNotifier.value = audioPref.speed;
          }
        });
      } else {
        _pitchValueNotifier.value = _pitchDefaultValue;
        _volumeValueNotifier.value = _volumeDefaultValue;
        _speedValueNotifier.value = _speedDefaultValue;
      }
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
    log.debug("playback panel build()");
    return Container(
      padding: widget.padding,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /*============================================================*\ 
              Header
            \*============================================================*/
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
            /*============================================================*\ 
              Option Panels
            \*============================================================*/
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
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ================ PITCH Option Panel =====================
                    SizedAnimated(
                      showNotifier: _pitchShowNotifier,
                      child: RectThumbSlider(
                        icon: Icons.graphic_eq,
                        initValue: _pitchDefaultValue,
                        divisions: 26,
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
                      ),
                    ),
                    // ================ VOLUME Option Panel =====================
                    SizedAnimated(
                      showNotifier: _volumeShowNotifier,
                      child: RectThumbSlider(
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
                      ),
                    ),
                    // ================ SPEED Option Panel =====================
                    SizedAnimated(
                      showNotifier: _speedShowNotifier,
                      child: RectThumbSlider(
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
                      ),
                    ),
                    // ================ TIMER Option Panel =====================
                    SizedAnimated(
                      showNotifier: _timerShowNotifier,
                      child: RectThumbSlider(
                        initValue: _timerDefaultValue,
                        min: 0,
                        max: 7200,
                        divisions: 24,
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
                          _timer ??= Timer.periodic(const Duration(seconds: 1),
                              (timer) {
                            var value = _timerValueNotifier.value.toInt();
                            if (value > 0) {
                              _timerValueNotifier.value = value - 1;
                            } else {
                              agent.stopPlayIfPlaying();
                              _timer!.cancel();
                              _timer = null;
                            }
                          });
                        },
                      ),
                    ),
                  ],
                )),
            /*============================================================*\ 
              Option Buttons
            \*============================================================*/
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // ================ PTICH Option Button =====================
                OnOffIconButton(
                  icon: Icons.graphic_eq,
                  stateNotifier: _pitchShowNotifier,
                  defaultValue: _pitchDefaultValue,
                  valueNotifier: _pitchValueNotifier,
                  onStateChanged: (state) {
                    _showOptionPanel(_OptionPanelType.pitch, state);
                  },
                ),
                // ================ VOLUME Option Button =====================
                OnOffIconButton(
                  icon: Icons.volume_up_outlined,
                  stateNotifier: _volumeShowNotifier,
                  defaultValue: _volumeDefaultValue,
                  valueNotifier: _volumeValueNotifier,
                  onStateChanged: (state) {
                    _showOptionPanel(_OptionPanelType.volume, state);
                  },
                ),
                // ================ SPEED Option Button =====================
                OnOffIconButton(
                  icon: Icons.fast_forward,
                  stateNotifier: _speedShowNotifier,
                  defaultValue: _speedDefaultValue,
                  valueNotifier: _speedValueNotifier,
                  labelFormater: _speedLabelFormatter,
                  onStateChanged: (state) {
                    _showOptionPanel(_OptionPanelType.speed, state);
                  },
                ),
                // ================ TIMER Option Button =====================
                OnOffIconButton(
                  icon: Icons.timer,
                  stateNotifier: _timerShowNotifier,
                  defaultValue: _timerDefaultValue,
                  valueNotifier: _timerValueNotifier,
                  labelFormater: _timerLabelFormatter,
                  labelAnimation: false,
                  onStateChanged: (state) {
                    _showOptionPanel(_OptionPanelType.timer, state);
                  },
                ),
                // ================ REPEAT Option Button =====================
                OnOffIconButton(
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
                      PlayLoopType.random,
                    ];
                    var value = _repeatValueNotifier.value.toInt();
                    value = (value + 1) % 5;
                    widget.loopNotifier.value = loopTypeList[value];
                    _repeatValueNotifier.value = value.toDouble();
                  },
                ),
              ],
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
            /*============================================================*\ 
              Playback Control Buttons
            \*============================================================*/
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
                          onPressed: () {
                            agent.seekToRelative(-5000);
                          },
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
                          onPressed: () {
                            agent.seekToRelative(5000);
                          },
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
