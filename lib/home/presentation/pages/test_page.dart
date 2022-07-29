import 'dart:io';
import 'dart:math';

import 'package:brecorder/core/audio_agent.dart';
import 'package:brecorder/core/logging.dart';
import 'package:brecorder/recording/presentation/widgets/painted_waveform.dart';
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
  ValueNotifier<List<double>> waveformNotifier =
      ValueNotifier(List<double>.empty());

  @override
  void initState() {
    super.initState();
    getApplicationDocumentsDirectory().then((value) {
      setState(() {
        audioPath = join(value.path, "test.aac");
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: ListView(children: <Widget>[
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
        ValueListenableBuilder<List<double>>(
            valueListenable: waveformNotifier,
            builder: (context, waveformData, _) {
              return PaintedWaveform(
                waveformData,
                // scrollable: false,
                key: const Key("test_page_painted_wave_form"),
              );
            }),
        Card(
          child: InkWell(
            onTap: () {
              log.info("Start recording");
              final f = File(audioPath);
              if (f.existsSync()) {
                f.deleteSync();
              }
              var ret = agent.startListenWaveformSample((eventData) {
                // final sampleList = eventData;
                // debugPrint(
                //     "======================== Got waveform sample data =====================");
                // for (int i = 0; i < sampleList.length; i += 2) {
                //   double max = eventData[i];
                //   double min = eventData[i + 1];

                //   debugPrint(
                //       "MAX:${"$max".padRight(5)}, MIN:${"$min".padRight(5)}");
                // }
                // log.debug("Flutter received:$eventData");
                waveformNotifier.value +=
                    eventData.map((e) => e.toDouble()).toList();
                // log.debug(
                //     "waveform data length:${waveformNotifier.value.length}");
              }, (error) {
                log.error("Got error: $error");
              });
              if (ret) {
                agent.startRecord(audioPath);
              }
            },
            splashColor: Colors.pink,
            child: const ListTile(title: Text("Rec Start")),
          ),
        ),
        Card(
          child: InkWell(
            onTap: () {
              log.info("Stop recording");
              agent.stopRecord();
              agent.stopListenWaveformSample();
            },
            splashColor: Colors.pink,
            child: const ListTile(title: Text("Rec Stop")),
          ),
        ),
        // Card(
        //   child: InkWell(
        //     onTap: () {
        //       log.info("Start recording WAV");
        //       final f = File("$audioPath.wav");
        //       if (f.existsSync()) {
        //         f.deleteSync();
        //       }
        //       agent.startRecordWav("$audioPath.wav");
        //     },
        //     splashColor: Colors.pink,
        //     child: const ListTile(title: Text("Rec Start WAV")),
        //   ),
        // ),
        // Card(
        //   child: InkWell(
        //     onTap: () {
        //       log.info("Stop recording WAV");
        //       agent.stopRecordWav();
        //     },
        //     splashColor: Colors.pink,
        //     child: const ListTile(title: Text("Rec Stop WAV")),
        //   ),
        // ),
        Card(
          child: InkWell(
            onTap: () {
              log.info("Start Play");
              agent.startPlay(audioPath);
            },
            splashColor: Colors.pink,
            child: const ListTile(title: Text("Play Start")),
          ),
        ),
        Card(
          child: InkWell(
            onTap: () {
              log.info("Stop Play");
              agent.stopPlay();
            },
            splashColor: Colors.pink,
            child: const ListTile(title: Text("Play Stop")),
          ),
        ),
        Card(
          child: InkWell(
            onTap: () {
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
            splashColor: Colors.pink,
            child: const ListTile(title: Text("Get Duration")),
          ),
        ),
        Card(
          child: InkWell(
            onTap: () {
              listAllFiles();
            },
            splashColor: Colors.pink,
            child: const ListTile(title: Text("List Root Directory")),
          ),
        ),
      ]),
    );
  }
}
