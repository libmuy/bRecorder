// ignore_for_file: non_constant_identifier_names, constant_identifier_names

import 'package:flutter/cupertino.dart';

class GlobalInfo {
  static const int WAVEFORM_SAMPLES_PER_SECOND = 40;
  static const int WAVEFORM_SEND_PER_SECOND = 10;
  static const int PLAYBACK_POSITION_NOTIFY_INTERVAL_MS = 10;
  static const String RECORD_FORMAT = "M4A_ACC";
  static const int RECORD_CHANNEL_COUNT = 1;
  static const int RECORD_SAMPLE_RATE = 44100;
  static const int RECORD_BIT_RATE = 64000;
  static const int RECORD_FRAME_READ_PER_SECOND = 50;

  /*=======================================================================*\ 
    Platform specific parameters
  \*=======================================================================*/
  static double PLATFORM_PITCH_MAX_VALUE = 5.0;
  static double PLATFORM_PITCH_MIN_VALUE = 0.0;
  static double PLATFORM_PITCH_DEFAULT_VALUE = 1.0;

  /*=======================================================================*\ 
    UI parameters
  \*=======================================================================*/
  static const kDialogBorderRadius = 15.0;
  static const kSettingPagePadding = EdgeInsets.fromLTRB(10, 10, 10, 10);
}
