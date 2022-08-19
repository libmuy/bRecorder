package cyou.libmuy.brecorder

import android.annotation.SuppressLint
import android.media.*
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import java.io.File


const val PERMISSIONS_REQ = 1
const val SAMPLE_RATE = 44100                   // サンプリングレート (Hz)、// 全デバイスサポート保障は44100のみ
const val RECORDER_READ_INTERVAL = 50          // 1秒間に何回音声データを処理したいか
const val RECORDER_READ_FRAME_COUNT = SAMPLE_RATE / RECORDER_READ_INTERVAL  //1回処理するフレーム数
const val CHANNEL_COUNT = 1
const val RECORDER_READ_BYTES = RECORDER_READ_FRAME_COUNT * 2 * CHANNEL_COUNT  //1回処理するバイト数
const val BIT_RATE = 64000
const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
const val LOG_TAG = "Audio-Mgr"



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
