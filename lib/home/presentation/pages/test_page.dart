import 'dart:io';

import 'package:brecorder/core/audio_agent.dart';
import 'package:brecorder/core/utils.dart';
import 'package:brecorder/home/data/filesystem_repository.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart';

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

  @override
  void initState() {
    super.initState();
    GetIt.instance.get<FilesystemRepository>().rootPath.then((value) {
      setState(() {
        audioPath = join(value, "test.aac");
      });
    });
  }

  void listDir(Directory dir, int lv) {
    dir.listSync(recursive: true).forEach((element) {
      if (element is Directory) {
        listDir(element, lv + 1);
      } else {
        log.info("${' '.padLeft(lv * 4)}${basename(element.path)}");
      }
    });
  }

  void listAllFiles() {
    GetIt.instance.get<FilesystemRepository>().rootPath.then((value) {
      listDir(Directory(value), 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: <Widget>[
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
            Card(
              child: InkWell(
                onTap: () {
                  log.info("Start recording");
                  agent.startRecord(audioPath);
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
                },
                splashColor: Colors.pink,
                child: const ListTile(title: Text("Rec Stop")),
              ),
            ),
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
