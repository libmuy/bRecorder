import 'dart:io';
import 'dart:math';

import 'package:brecorder/core/audio_agent.dart';
import 'package:brecorder/core/logging.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

final log = Logger('TestPage');

class RecordingPage extends StatefulWidget {
  const RecordingPage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<RecordingPage> createState() => _RecordingPageState();
}

class _RecordingPageState extends State<RecordingPage> {
  final getIt = GetIt.instance;
  final agent = GetIt.instance.get<AudioServiceAgent>();
  var _pitchValue = 1.0;
  var _speedValue = 1.0;
  String audioPath = "";

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
      ]),
    );
  }
}
