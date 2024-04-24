import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/audio_agent.dart';
import '../../core/global_info.dart';
import '../../core/logging.dart';
import '../../core/utils/utils.dart';
import '../../domain/entities.dart';
import '../widgets/waveform/waveform.dart';

final log = Logger('TestPage');

class MyTestPage extends StatefulWidget {
  const MyTestPage({super.key, required this.title});

  final String title;

  @override
  State<MyTestPage> createState() => _MyTestPageState();
}

class _MyTestPageState extends State<MyTestPage> {
  final getIt = GetIt.instance;
  final agent = GetIt.instance.get<AudioServiceAgent>();
  var _pitchValue = 1.0;
  var _speedValue = 1.0;
  var _volumeValue = 1.0;
  String audioPath = "";
  List<bool> audioButtonsState = [false, false, false];
  ValueNotifier<List<double>> waveformNotifier =
      ValueNotifier(List<double>.empty());
  bool _recording = false;
  bool get _playing {
    return audioButtonsState[2];
  }

  set _playing(bool value) {
    audioButtonsState[2] = value;
  }

  WaveformDelegate waveformDelegate = WaveformDelegate();

  final waveformMetricsNotifier = ValueNotifier(const AudioPositionInfo(0, 0));

  @override
  void initState() {
    super.initState();
    getApplicationDocumentsDirectory().then((value) {
      setState(() {
        audioPath = join(value.path, "test.m4a");
      });
    });
  }

  void listDir(Directory dir, int lv) {
    dir.listSync(recursive: true).forEach((element) {
      if (element is Directory) {
        listDir(element, lv + 1);
      } else {
        log.info(
            "${' '.padLeft(lv * 4)}${basename(element.path)} size:${(element as File).lengthSync()}");
      }
    });
  }

  void listAllFiles() {
    listDir(Directory(dirname(audioPath)), 0);
  }

  void onWaveformDataUpdate(_, dynamic data) {
    waveformNotifier.value += data.map((e) => e.toDouble()).toList();
  }

  bool _startRecording() {
    log.info("Start recording");
    final f = File(audioPath);
    if (f.existsSync()) {
      f.deleteSync();
    }
    _recording = true;
    agent.addAudioEventListener(AudioEventType.waveform, onWaveformDataUpdate);
    agent.startRecord(audioPath);

    return true;
  }

  bool _stopRecording() {
    log.info("Stop recording");
    _recording = false;
    agent.stopRecord();
    return true;
  }

  bool _pauseRecording() {
    log.info("Pause recording");
    agent.pauseRecord();
    return true;
  }

  bool _resumeRecording() {
    log.info("Resume recording");
    agent.resumeRecord();
    return true;
  }

  bool _startPlay() {
    log.info("Start Play");
    try {
      final ms = (waveformMetricsNotifier.value.position * 1000).toInt();
      if (ms != 0) {
        agent.seekTo(ms);
        // await Future.delayed(const Duration(seconds: 1));
      }
    } catch (e) {
      //do nothing
    }

    void onPlaybackComplete(_, __) {
      if (_playing == true) {
        setState(() {
          _playing = false;
        });
      }
    }

    void onPositionUpdate(_, data) {
      int positionMs = data;
      // log.debug("position update notification: $positionMs ms");
      double positionSec = positionMs / 1000;
      waveformDelegate.setPosition(positionSec, dispatchNotification: true);
    }

    agent.addAudioEventListener(AudioEventType.stopped, onPlaybackComplete);
    agent.addAudioEventListener(
        AudioEventType.positionUpdate, onPositionUpdate);

    agent.startPlay(AudioInfo(audioPath), positionNotifyIntervalMs: 10);
    return true;
  }

  bool _stopPlay() {
    log.info("Stop Play");
    agent.stopPlay();
    return true;
  }

  void _waveformPositionListener(AudioPositionInfo metrics) {
    // log.debug("metrics updated: pos:${metrics.position.toStringAsFixed(2)}");
    waveformMetricsNotifier.value = metrics;
    // if (_playing) {
    //   agent.seekTo((metrics.position * 1000).toInt());
    // }
  }

  void _waveformStartSeek(AudioPositionInfo metrics) {
    log.debug("start seek");
    if (_playing) agent.pausePlay();
  }

  void _waveformEndSeek(AudioPositionInfo metrics) async {
    final ms = (metrics.position * 1000).toInt();
    // if (ms != 0) {
    //   agent.seekTo(ms);
    //   log.debug("end seek, seek to: $ms");
    //   // await Future.delayed(const Duration(seconds: 1));
    // } else {
    //   log.debug("end seek, seek to: $ms");
    // }
    agent.seekTo(ms);
    log.debug("end seek, seek to: $ms");
    if (_playing) {
      agent.resumePlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(children: [
            const Text("Path: "),
            Expanded(
              child: Text(
                audioPath,
                // maxLines: 2,
                // overflow: TextOverflow.fade,
              ),
            ),
          ]),
        ),
        ValueListenableBuilder<List<double>>(
            valueListenable: waveformNotifier,
            builder: (context, waveformData, _) {
              // log.debug("build waveform from test page");
              return Waveform(
                waveformData,
                scrollable: _recording ? false : true,
                // key: const Key("test_page_painted_wave_form"),
                positionListener: _waveformPositionListener,
                startSeek: _waveformStartSeek,
                endSeek: _waveformEndSeek,
                delegate: waveformDelegate,
              );
            }),
        ValueListenableBuilder<AudioPositionInfo>(
            valueListenable: waveformMetricsNotifier,
            builder: (context, metrics, _) {
              return Column(
                children: [
                  Slider(
                      value: metrics.duration == 0
                          ? 0
                          : metrics.position / metrics.duration,
                      onChanged: (val) {
                        log.debug("change to $val");
                        waveformDelegate.setPositionByPercent(val,
                            dispatchNotification: true);
                      }),
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
                      Text((metrics.position).toStringAsFixed(2)),
                      Text((metrics.duration).toStringAsFixed(2)),
                    ],
                  ),
                ],
              );
            }),
        FutureBuilder(
          future: agent.waitPlatformParams(),
          builder: (_, AsyncSnapshot<dynamic> snapshot) {
            if (snapshot.hasData) {
              _pitchValue = GlobalInfo.PLATFORM_PITCH_DEFAULT_VALUE;
            }
            return Row(children: [
              Text("Pitch:${_pitchValue.toStringAsFixed(1)}"),
              Expanded(
                child: Slider(
                  value: _pitchValue,
                  min: GlobalInfo.PLATFORM_PITCH_MIN_VALUE,
                  max: GlobalInfo.PLATFORM_PITCH_MAX_VALUE,
                  divisions: 50,
                  onChanged: (v) {
                    setState(() {
                      _pitchValue = v;
                    });
                  },
                  onChangeEnd: (v) {
                    log.debug("Pitch changed to:$v");
                    agent.setPitch(_pitchValue);
                  },
                ),
              ),
            ]);
          },
        ),
        Row(children: [
          Text("Speed:${_speedValue.toStringAsFixed(1)}"),
          Expanded(
            child: Slider(
              value: _speedValue,
              min: 0.25,
              max: 3.0,
              divisions: 100,
              onChanged: (v) {
                setState(() {
                  _speedValue = v;
                });
              },
              onChangeEnd: (v) {
                log.debug("Speed changed to:$v");
                agent.setSpeed(_speedValue);
              },
            ),
          ),
        ]),
        Row(children: [
          Text("Volume:${_volumeValue.toStringAsFixed(1)}"),
          Expanded(
            child: Slider(
              value: _volumeValue,
              min: 0.0,
              max: 10.0,
              divisions: 100,
              onChanged: (v) {
                setState(() {
                  _volumeValue = v;
                });
              },
              onChangeEnd: (v) {
                log.debug("Volume changed to:$v");
                agent.setVolume(_volumeValue);
              },
            ),
          ),
        ]),
        ToggleButtons(
          borderRadius: const BorderRadius.all(Radius.circular(5)),
          borderWidth: 2,
          onPressed: (int index) {
            bool toggle = false;
            if (index == 0) {
              toggle = audioButtonsState[index]
                  ? _stopRecording()
                  : _startRecording();
            } else if (index == 1) {
              toggle = audioButtonsState[index]
                  ? _resumeRecording()
                  : _pauseRecording();
            } else if (index == 2) {
              toggle = audioButtonsState[index] ? _stopPlay() : _startPlay();
            }

            if (toggle) {
              setState(() {
                audioButtonsState[index] = !audioButtonsState[index];
              });
            }
          },
          isSelected: audioButtonsState,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: audioButtonsState[0]
                  ? const Text("Rec Stop")
                  : const Text("Rec Start"),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: audioButtonsState[1]
                  ? const Text("Rec Resume")
                  : const Text("Rec Pause"),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: audioButtonsState[2]
                  ? const Text("Play Stop")
                  : const Text("Play Start"),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: () {
                log.info("Get Duration");
                final d = agent.getDuration(audioPath);
                d.then((result) {
                  if (result.succeed) {
                    log.info("Duration: ${result.value}");
                  } else {
                    log.info("got error:${result.error}");
                  }
                });
              },
              child: const Text("Get Duration"),
            ),
            ElevatedButton(
              onPressed: () {
                listAllFiles();
              },
              child: const Text("ls rootDir"),
            ),
            ElevatedButton(
              onPressed: () {
                agent.test("path").then((value) {
                  if (value.succeed) {
                    log.debug("test return:${value.value}");
                  } else {
                    log.debug("exception");
                  }
                });
              },
              child: const Text("Test"),
            ),
          ],
        ),
      ]),
    );
  }
}
