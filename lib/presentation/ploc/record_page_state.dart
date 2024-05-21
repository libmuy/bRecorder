import 'dart:io';
import 'dart:typed_data';

import 'package:brecorder/domain/entities.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';

import '../../core/audio_agent.dart';
import '../../core/logging.dart';
import '../../core/service_locator.dart';
import '../../core/utils/utils.dart';
import '../../data/repository.dart';
import '../widgets/waveform/waveform.dart';
import 'home_page_state.dart';

final _log = Logger('RecordPageState');

class RecordPageState {
  final agent = sl.get<AudioServiceAgent>();
  late final String recordingFileName;
  late String audioTitle;
  late Repository repo;
  late String dirPath;
  String audioPath = "";
  String waveformPath = "";

  final ValueNotifier<List<double>> waveformNotifier =
      ValueNotifier(List<double>.empty());
  final WaveformDelegate waveformDelegate = WaveformDelegate();
  final waveformMetricsNotifier = ValueNotifier(const AudioPositionInfo(0, 0));
  final recordStateNotifier = ValueNotifier(RecordState.stopped);

  void init(String dirPath, RepoType repoType) {
    this.dirPath = dirPath;
    DateFormat dateFormat = DateFormat('yyyy-MM-dd_HH-mm-ss');
    audioTitle = dateFormat.format(DateTime.now());
    recordingFileName = audioTitle;
    repo = sl.getRepository(repoType);
    _log.info("record path:$dirPath");
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

  void _saveWaveformData(AudioInfo audio) {
    final data = Float32List.fromList(waveformNotifier.value);
    audio.setWaveformData(data);
  }

  void stopButtonOnPressed(BuildContext context, bool mounted) async {
    final ret = await _stopRecording();
    if (!ret) return;
    recordStateNotifier.value = RecordState.stopped;

    if (!mounted) return;
    Navigator.of(context).pop();
    final audioResult = await repo.notifyNewAudio(audioPath);
    if (audioResult.succeed) {
      _saveWaveformData(audioResult.value);
    }

    sl.get<HomePageState>().recordDone();
  }

  void waveformPositionListener(AudioPositionInfo metrics) {
    waveformMetricsNotifier.value = metrics;
  }

  void onWaveformDataUpdate(_, dynamic data) {
    Float32List list = data;
    waveformNotifier.value += list.map((e) => e.toDouble()).toList();
  }

  Future<bool> _startRecording() async {
    final base = join(dirPath, recordingFileName);
    audioPath = "$base.m4a";
    final absPath = await repo.absolutePath(audioPath);
    _log.info("Start recording: $audioPath");
    final f = File(absPath);
    if (f.existsSync()) {
      f.deleteSync();
    }
    agent.addAudioEventListener(AudioEventType.waveform, onWaveformDataUpdate);
    final agentRet = await agent.startRecord(absPath);

    if (agentRet.succeed) {
      _log.info("record start ok");
      return true;
    } else {
      _log.error("record start failed");
      return false;
    }
  }

  Future<bool> _stopRecording() async {
    _log.info("Stop recording");
    final agentRet = await agent.stopRecord();
    if (agentRet.succeed) {
      _log.info("record stop ok");
      return true;
    } else {
      _log.error("record stop failed");
      return false;
    }
  }

  Future<bool> _pauseRecording() async {
    _log.info("Pause recording");
    final agentRet = await agent.pauseRecord();
    if (agentRet.succeed) {
      _log.info("record pause ok");
      return true;
    } else {
      _log.error("record pause failed");
      return false;
    }
  }

  Future<bool> _resumeRecording() async {
    _log.info("Resume recording");
    final agentRet = await agent.resumeRecord();
    if (agentRet.succeed) {
      _log.info("record resume ok");
      return true;
    } else {
      _log.error("record resume failed");
      return false;
    }
  }
}
