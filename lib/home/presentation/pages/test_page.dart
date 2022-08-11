import 'dart:io';
import 'dart:math';

import 'package:brecorder/core/audio_agent.dart';
import 'package:brecorder/core/logging.dart';
import 'package:brecorder/recording/presentation/widgets/waveform.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

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
  String audioPath = "";
  List<bool> audioButtonsState = [false, false];
  ValueNotifier<List<double>> waveformNotifier =
      ValueNotifier(List<double>.empty());
  bool _recording = false;
  bool get _playing {
    return audioButtonsState[1];
  }

  WaveformDelegate waveformDelegate = WaveformDelegate();

  final waveformMetricsNotifier = ValueNotifier(WaveformMetrics(0, 0));

  @override
  void initState() {
    super.initState();
    getApplicationDocumentsDirectory().then((value) {
      setState(() {
        audioPath = join(value.path, "test.mp4");
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

  void _startRecording() {
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
  }

  void _stopRecording() {
    log.info("Stop recording");
    _recording = false;
    agent.stopRecord();
  }

  void _startPlay() async {
    log.info("Start Play");
    final ms = (waveformMetricsNotifier.value.position * 1000).toInt();
    if (ms != 0) {
      await agent.seekTo(ms);
      // await Future.delayed(const Duration(seconds: 1));
    }
    agent.startPlay(audioPath, positionNotifyIntervalMs: 10,
        onPlayEvent: (data) {
      switch (data["event"]) {
        case "PlayComplete":
          if (audioButtonsState[1] == true) {
            setState(() {
              audioButtonsState[1] = false;
            });
          }
          break;
        case "PositionUpdate":
          int? positionMs = data["position"];
          if (positionMs == null) {
            positionMs = 0;
            log.error("position updated with null");
          }
          double positionSec = positionMs / 1000;
          waveformDelegate.setPosition(positionSec, dispatchNotification: true);
          break;
        default:
      }
    });
  }

  void _stopPlay() {
    log.info("Stop Play");
    agent.stopPlay();
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
    log.debug("end seek");
    if (_playing) {
      final ms = (metrics.position * 1000).toInt();
      if (ms != 0) {
        agent.seekTo(ms);
        // await Future.delayed(const Duration(seconds: 1));
      }
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
        Row(children: [
          Text("Pitch:${_pitchValue.toStringAsFixed(1)}"),
          Expanded(
            child: Slider(
              value: _pitchValue,
              min: 0,
              max: 5,
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
        ]),
        Row(children: [
          Text("Speed:${_speedValue.toStringAsFixed(1)}"),
          Expanded(
            child: Slider(
              value: _speedValue,
              min: 0,
              max: 5,
              divisions: 50,
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
        ToggleButtons(
          borderRadius: BorderRadius.all(Radius.circular(5)),
          borderWidth: 2,
          onPressed: (int index) {
            if (index == 0) {
              if (audioButtonsState[index] == false) {
                _startRecording();
              } else {
                _stopRecording();
              }
            } else if (index == 1) {
              if (audioButtonsState[index] == false) {
                _startPlay();
              } else {
                _stopPlay();
              }
            }

            setState(() {
              audioButtonsState[index] = !audioButtonsState[index];
            });
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
          ],
        ),
      ]),
    );
  }
}
