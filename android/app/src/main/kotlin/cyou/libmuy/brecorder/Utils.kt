package cyou.libmuy.brecorder

import android.media.*


const val PERMISSIONS_REQ = 1
var SAMPLE_RATE = 44100                   // サンプリングレート (Hz)、// 全デバイスサポート保障は44100のみ
var RECORD_FRAME_READ_PER_SECOND = 50          // 1秒間に何回音声データを処理したいか
var RECORD_CHANNEL_COUNT = 1
var RECORDER_READ_BYTES = SAMPLE_RATE / RECORD_FRAME_READ_PER_SECOND * 2 * RECORD_CHANNEL_COUNT  //1回処理するバイト数
var BIT_RATE = 64000
var CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
const val LOG_TAG = "Audio-Mgr"
var WAVEFORM_SAMPLES_PER_SECOND = 40;
var WAVEFORM_SEND_PER_SECOND = 10;
var RECORD_FORMAT = "M4A_ACC"
var PLAYBACK_POSITION_NOTIFY_INTERVAL_MS = 10


enum class AudioState {
    Playing,
    PlayPaused,
    Recording,
    RecordPaused,
    Idle
}
enum class AudioErrorInfo(val code: Int, val msg: String) {
    OK(0, "OK"),
    NG(-1, "NG"),
    NoMic(-2, "No Microphone exists"),
    StateErrNotRecording(-3, "State Error: Not recording"),
    StateErrNotPlaying(-4, "State Error: Not playing"),
    StateErrNotIdle(-5, "State Error: Not idle"),
    NoPermission(-6, "No Permission"),
    FileNotFound(-7, "File Not Found"),
    ParamError(-8, "Parameter Error"),
}

class AudioResult <Result>(error: AudioErrorInfo, var result: Result? = null,
                           private val extraString: String = ""
) {
    private val errorInfo = error
    val errorCode = error.code.toString()
    val errorMessage = error.msg
    get() {
        if (extraString == "") return field

        return "$field: $extraString"
    }


    fun isOK(): Boolean {
        return errorInfo == AudioErrorInfo.OK
    }
}
class NoValue
