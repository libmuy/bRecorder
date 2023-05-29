import 'package:flutter/material.dart';

import '../../core/logging.dart';
import '../../core/service_locator.dart';
import '../../core/utils/utils.dart';
import '../../data/repository.dart';
import '../ploc/record_page_state.dart';
import '../widgets/editable_text.dart' as brecord;
import '../widgets/waveform/waveform.dart';

final log = Logger('TestPage');

class RecordPage extends StatefulWidget {
  final String dirPath;
  final RepoType repoType;
  const RecordPage({Key? key, required this.dirPath, required this.repoType})
      : super(key: key);

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  final state = sl.get<RecordPageState>();

  @override
  void initState() {
    super.initState();
    state.init(widget.dirPath, widget.repoType);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          body: Column(children: <Widget>[
            // Status Bar space holder
            SizedBox(
              height: MediaQuery.of(context).viewPadding.top,
            ),

            // Record Page Title
            Container(
                height: 50,
                alignment: Alignment.center,
                child: Text(
                  "Recording",
                  style: Theme.of(context).textTheme.titleLarge,
                )),
            const Divider(),

            // Audio File Title
            brecord.EditableText(
              state.audioTitle,
              height: 28,
              padding: const EdgeInsets.all(20),
              textAlign: TextAlign.center,
              onTextChanged: (text) {
                state.audioTitle = text;
              },
            ),

            // Waveform widget
            ValueListenableBuilder<List<double>>(
                valueListenable: state.waveformNotifier,
                builder: (context, waveformData, _) {
                  return Expanded(
                    child: Waveform(
                      waveformData,
                      scrollable: false,
                      // key: const Key("record_page_waveform"),
                      positionListener: state.waveformPositionListener,
                      // startSeek: _waveformStartSeek,
                      // endSeek: _waveformEndSeek,
                      delegate: state.waveformDelegate,
                    ),
                  );
                }),

            // Duration Text Lable
            ValueListenableBuilder<AudioPositionInfo>(
                valueListenable: state.waveformMetricsNotifier,
                builder: (context, metrics, _) {
                  return Container(
                    alignment: Alignment.center,
                    height: 50,
                    child: Text(
                      metrics.duration.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 30,
                      ),
                    ),
                  );
                }),

            // Controll Buttons
            Container(
              padding: const EdgeInsets.all(10),
              child: ValueListenableBuilder<RecordState>(
                  valueListenable: state.recordStateNotifier,
                  builder: (context, recordState, _) {
                    return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          //Flag Button
                          MaterialButton(
                            onPressed: () {},
                            child: const Icon(Icons.flag),
                          ),
                          //Start/Pause Button
                          MaterialButton(
                            onPressed: state.startPauseButtonOnPressed,
                            child: recordState == RecordState.recording
                                ? const Icon(Icons.pause)
                                : const Icon(Icons.mic),
                          ),
                          //Stop Button
                          MaterialButton(
                            onPressed: recordState == RecordState.stopped
                                ? null
                                : () {
                                    state.stopButtonOnPressed(context, mounted);
                                  },
                            child: const Icon(Icons.stop),
                          ),
                        ]);
                  }),
            )
          ]),
        ));
  }
}
