import 'dart:io';

import 'package:brecorder/core/audio_agent.dart';
import 'package:brecorder/core/global_info.dart';
import 'package:brecorder/core/logging.dart';
import 'package:brecorder/presentation/widgets/state_button.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../widgets/editable_text.dart' as brecord;
import '../widgets/waveform/waveform.dart';

final log = Logger('TestPage');

class RecordPage extends StatefulWidget {
  const RecordPage({Key? key}) : super(key: key);

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  final getIt = GetIt.instance;
  final agent = GetIt.instance.get<AudioServiceAgent>();

  // @override
  // void initState() {
  //   super.initState();
  // }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          appBar: AppBar(
            title: const Text("Recording"),
          ),
          body: Column(children: <Widget>[
            const brecord.EditableText(
              "2022-08-27",
              height: 30,
              padding: EdgeInsets.all(10),
              textAlign: TextAlign.center,
            ),
            const Card(
              child: Text("data"),
            ),
            Container(
              padding: EdgeInsets.all(10),
              child: Row(children: [
                MaterialButton(
                  onPressed: () {},
                  child: Icon(Icons.flag),
                ),
                StateButton(
                  state1Widget: const Icon(Icons.mic),
                  state2Widget: const Icon(Icons.pause),
                  onPressed: () {},
                ),
                MaterialButton(
                  onPressed: () {},
                  child: Icon(Icons.stop),
                ),
              ]),
            )
          ]),
        ));
  }
}
