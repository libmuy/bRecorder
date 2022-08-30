import 'dart:io';

import 'package:brecorder/core/logging.dart';
import 'package:brecorder/data/repository_type.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';

import '../../core/audio_agent.dart';
import '../../core/service_locator.dart';
import '../../domain/abstract_repository.dart';
import '../widgets/waveform/waveform.dart';

final log = Logger('RecordPageState');

class RecordPageState {
  final agent = sl.get<AudioServiceAgent>();
  late final String recordingFileName;
  late String audioTitle;
  late Repository repo;
  late String dirPath;

  final ValueNotifier<List<double>> waveformNotifier =
      ValueNotifier(List<double>.empty());
  final WaveformDelegate waveformDelegate = WaveformDelegate();
  final waveformMetricsNotifier = ValueNotifier(const WaveformMetrics(0, 0));
  final recordStateNotifier = ValueNotifier(RecordState.stopped);

  void init(String dirPath, RepoType repoType) {
    this.dirPath = dirPath;
    DateFormat dateFormat = DateFormat('yyyy-MM-dd_HH-mm-ss');
    audioTitle = dateFormat.format(DateTime.now());
    recordingFileName = audioTitle;
    repo = sl.getRepository(repoType);
    log.info("record path:$dirPath");
    startPauseButtonOnPressed();
  }

  void startPauseButtonOnPressed() async {
    bool ret;
    switch (recordStateNotifier.value) {
      case RecordState.paused:
        ret = await _resumeRecording();
        if (!ret) return;
        recordStateNotifier.value = RecordState.recording;
        break;
      case RecordState.stopped:
        ret = await _startRecording();
        if (!ret) return;
        recordStateNotifier.value = RecordState.recording;
        break;
      case RecordState.recording:
        ret = await _pauseRecording();
        if (!ret) return;
        recordStateNotifier.value = RecordState.paused;
        break;
    }
  }

  void stopButtonOnPressed(BuildContext context, bool mounted) async {
    final ret = await _stopRecording();
    if (!ret) return;
    recordStateNotifier.value = RecordState.stopped;

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void waveformPositionListener(WaveformMetrics metrics) {
    waveformMetricsNotifier.value = metrics;
  }

  Future<bool> _startRecording() async {
    bool ret = true;
    String path = join(dirPath, "$recordingFileName.m4a");
    path = await repo.absolutePath(path);
    log.info("Start recording: $path");
    final f = File(path);
    if (f.existsSync()) {
      f.deleteSync();
    }
    final agentRet =
        await agent.startRecord(path, onWaveformData: (waveformData) {
      // log.debug("waveform date upddate:$waveformData");
      waveformNotifier.value += waveformData.map((e) => e.toDouble()).toList();
    });

    agentRet.fold((ok) {
      log.info("record start ok");
    }, (p0) {
      log.error("record start failed");
      ret = false;
    });

    return ret;
  }

  Future<bool> _stopRecording() async {
    log.info("Stop recording");
    bool ret = true;
    final agentRet = await agent.stopRecord();
    agentRet.fold((ok) {
      log.info("record stop ok");
    }, (p0) {
      log.error("record stop failed");
      ret = false;
    });

    return ret;
  }

  Future<bool> _pauseRecording() async {
    log.info("Pause recording");
    bool ret = true;
    final agentRet = await agent.pauseRecord();
    agentRet.fold((ok) {
      log.info("record pause ok");
    }, (p0) {
      log.error("record pause failed");
      ret = false;
    });

    return ret;
  }

  Future<bool> _resumeRecording() async {
    log.info("Resume recording");
    bool ret = true;
    final agentRet = await agent.resumeRecord();
    agentRet.fold((ok) {
      log.info("record resume ok");
    }, (p0) {
      log.error("record resume failed");
      ret = false;
    });

    return ret;
  }
}

enum RecordState {
  stopped,
  recording,
  paused,
}
