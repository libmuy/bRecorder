import 'dart:io';

import 'package:brecorder/core/audio_agent.dart';
import 'package:brecorder/core/global_info.dart';
import 'package:brecorder/core/logging.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../widgets/waveform/waveform.dart';

final log = Logger('TestPage');

class MyTestPage extends StatefulWidget {
  const MyTestPage({Key? key, required this.title}) : super(key: key);

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

  final waveformMetricsNotifier = ValueNotifier(const WaveformMetrics(0, 0));

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

  bool _startRecording() {
    log.info("Start recording");
    final f = File(audioPath);
    if (f.existsSync()) {
      f.deleteSync();
    }
    _recording = true;
    agent.startRecord(audioPath, onWaveformData: (waveformData) {
      // log.debug("waveform date upddate:$waveformData");
      waveformNotifier.value += waveformData.map((e) => e.toDouble()).toList();
    });

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

    agent.startPlay(audioPath, positionNotifyIntervalMs: 10,
        onPlayEvent: (data) {
      switch (data["event"]) {
        case "PlayComplete":
          if (_playing == true) {
            setState(() {
              _playing = false;
            });
          }
          break;
        case "PositionUpdate":
          int? positionMs = data["data"];
          if (positionMs == null) {
            positionMs = 0;
            log.error("position updated with null");
          }
          // log.debug("position update notification: $positionMs ms");
          double positionSec = positionMs / 1000;
          waveformDelegate.setPosition(positionSec, dispatchNotification: true);
          break;
        default:
      }
    });
    return true;
  }

  bool _stopPlay() {
    log.info("Stop Play");
    agent.stopPlay();
    return true;
  }

  void _waveformPositionListener(WaveformMetrics metrics) {
    // log.debug("metrics updated: pos:${metrics.position.toStringAsFixed(2)}");
    waveformMetricsNotifier.value = metrics;
    // if (_playing) {
    //   agent.seekTo((metrics.position * 1000).toInt());
    // }
  }

  void _waveformStartSeek(WaveformMetrics metrics) {
    log.debug("start seek");
    if (_playing) agent.pausePlay();
  }

  void _waveformEndSeek(WaveformMetrics metrics) async {
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
                key: const Key("test_page_painted_wave_form"),
                positionListener: _waveformPositionListener,
                startSeek: _waveformStartSeek,
                endSeek: _waveformEndSeek,
                delegate: waveformDelegate,
              );
            }),
        ValueListenableBuilder<WaveformMetrics>(
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
                d.then((result) => {
                      result.fold((duration) {
                        log.info("Duration: $duration");
                      }, (err) {
                        log.info("got error:$err");
                      })
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
                  value.fold((p0) {
                    log.debug("test return:$p0");
                  }, (p0) {
                    log.debug("exception");
                  });
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
