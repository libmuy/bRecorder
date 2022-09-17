package cyou.libmuy.brecorder

import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result


@RequiresApi(Build.VERSION_CODES.O)
class PlatformChannelsHandler (act: FlutterActivity, flutterEngine: FlutterEngine?){
    private var audioManager: AudioManager = AudioManager(act, this)
    private var flutterEngine = flutterEngine
    private lateinit var eventChannel: EventChannel
    private var waveformEventSink: EventChannel.EventSink? = null
//    private var downloadFolder: String = act.context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)!!.path
//    private var downloadFolder :  String = "/storage/emulated/0/Download"
//    private var downloadFolder: String = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)!!.path


    private fun <T>endCallWithResult(result: Result, ret: AudioResult<T>) {
        if (ret.isOK()) {
            result.success(ret.result)
        } else {
            result.error(ret.errorCode, ret.errorMessage, null)
        }
    }

    private fun endCallWithParamError(result: Result, message: String) {
        endCallWithResult(result, AudioResult<NoValue>(AudioErrorInfo.ParamError, extraString = message))
    }

    fun <T>sendEvent(data: T) {
        waveformEventSink?.success(data)
    }

    fun initialize() {
        handleMethodCalls()
        handleEventChannel()
    }

    private fun handleEventChannel() {
        eventChannel = EventChannel(flutterEngine!!.dartExecutor.binaryMessenger, "libmuy.com/brecorder/eventchannel")
        eventChannel.setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                        Log.i(LOG_TAG, "EventChannel: waveform")
                        waveformEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    val args = arguments as String
                    waveformEventSink!!.endOfStream()
                    waveformEventSink = null
                    Log.w(LOG_TAG, "EventChannel onCancel called, args:$args")
                }
            })

    }

    private fun handleMethodCalls() {

        MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, "libmuy.com/brecorder/methodchannel").setMethodCallHandler { call, result ->
            when (call.method) {
                /*=======================================================================*\
                  Recording
                \*=======================================================================*/
                "startRecord" -> {
                    val path: String? = call.argument("path")
                    if (path == null) {
                        endCallWithParamError(result, "params is NULL")
                    } else {
                        val ret = audioManager!!.startRecord(path!!)
                        endCallWithResult(result, ret)
                    }
                }
                "stopRecord" -> {
                    val ret = audioManager!!.stopRecord()
                    endCallWithResult(result, ret)
                }
                "pauseRecord" -> {
                    val ret = audioManager!!.pauseRecord()
                    endCallWithResult(result, ret)
                }
                "resumeRecord" -> {
                    val ret = audioManager!!.resumeRecord()
                    endCallWithResult(result, ret)
                }

                /*=======================================================================*\
                  Playing
                \*=======================================================================*/
                "startPlay" -> {
                    val positionNotifyIntervalMs: Int? = call.argument("positionNotifyIntervalMs")
                    val path: String? = call.argument("path")
                    if (path == null || positionNotifyIntervalMs == null) {
                        endCallWithParamError(result, "params is NULL")
                    } else {
                        val ret = audioManager!!.startPlay(path!!, positionNotifyIntervalMs!!)
                        endCallWithResult(result, ret)
                    }
                }
                "stopPlay" -> {
                    val ret = audioManager!!.stopPlay()
                    endCallWithResult(result, ret)
                }
                "pausePlay" -> {
                    val ret = audioManager!!.pausePlay()
                    endCallWithResult(result, ret)
                }
                "resumePlay" -> {
                    val ret = audioManager!!.resumePlay()
                    endCallWithResult(result, ret)
                }
                "seekTo" -> {
                    val position: Int? = call.argument("position")
                    val sync: Boolean? = call.argument("sync")
                    if (position == null || sync == null) {
                        endCallWithParamError(result, "params is NULL")
                    }
                    if (sync!!) {
                        audioManager!!.seekTo(position!!) {
                            endCallWithResult(result, AudioResult<NoValue>(AudioErrorInfo.OK))
                        }
                    } else {
                        val ret = audioManager!!.seekTo(position!!, null)
                        endCallWithResult(result, ret)
                    }
                }
                "setPitch" -> {
                    val pitch: Double? = call.argument("pitch")
                    if (pitch == null) {
                        endCallWithParamError(result, "params is NULL")
                    } else {
                        val ret = audioManager!!.setPitch(pitch!!)
                        endCallWithResult(result, ret)
                    }
                }
                "setSpeed" -> {
                    val speed: Double? = call.argument("speed")
                    if (speed == null) {
                        endCallWithParamError(result, "params is NULL")
                    } else {
                        val ret = audioManager!!.setSpeed(speed!!)
                        endCallWithResult(result, ret)
                    }
                }
                "setVolume" -> {
                    val volume: Double? = call.argument("volume")
                    if (volume == null) {
                        endCallWithParamError(result, "params is NULL")
                    } else {
                        val ret = audioManager!!.setVolume(volume!!)
                        endCallWithResult(result, ret)
                    }
                }

                /*=======================================================================*\
                  Other
                \*=======================================================================*/
                "getDuration" -> {
                    val path: String? = call.argument("path")
                    if (path == null) {
                        endCallWithParamError(result, "params is NULL")
                    } else {
                        val ret = audioManager!!.getDuration(path!!)
                        endCallWithResult(result, ret)
                    }
                }
                "setParams" -> {
                    val samplesPerSecond: Int? = call.argument("samplesPerSecond")
                    val sendPerSecond: Int? = call.argument("sendPerSecond")
                    val recordFormat: String? = call.argument("recordFormat")
                    val recordChannelCount: Int? = call.argument("recordChannelCount")
                    val recordSampleRate: Int? = call.argument("recordSampleRate")
                    val recordBitRate: Int? = call.argument("recordBitRate")
                    val recordFrameReadPerSecond: Int? = call.argument("recordFrameReadPerSecond")
                    if (samplesPerSecond == null ||
                        sendPerSecond == null ||
                        recordChannelCount == null ||
                        recordSampleRate == null ||
                        recordBitRate == null ||
                        recordFrameReadPerSecond == null ||
                        recordFormat == null
                    ) {
                        endCallWithParamError(result, "params is NULL")
                    } else {
                        WAVEFORM_SAMPLES_PER_SECOND = samplesPerSecond!!
                        WAVEFORM_SEND_PER_SECOND = sendPerSecond!!
                        RECORD_FORMAT = recordFormat!!
                        RECORD_CHANNEL_COUNT = recordChannelCount!!
                        SAMPLE_RATE = recordSampleRate!!
                        BIT_RATE = recordBitRate!!
                        RECORD_FRAME_READ_PER_SECOND = recordFrameReadPerSecond!!
                        RECORDER_READ_BYTES = SAMPLE_RATE / RECORD_FRAME_READ_PER_SECOND * 2 * RECORD_CHANNEL_COUNT  //1回処理するバイト数
                        endCallWithResult(result, AudioResult<NoValue>(AudioErrorInfo.OK))

                        val map = HashMap<String, Any>()
                        map["platformPametersEvent"] = mapOf(
                            "PLATFORM_PITCH_MAX_VALUE" to 2.8,
                            "PLATFORM_PITCH_MIN_VALUE" to 0.2,
                            "PLATFORM_PITCH_DEFAULT_VALUE" to 1.0
                        )
                        sendEvent(map)
                    }
                }

                /*=======================================================================*\
                  For Debugging
                \*=======================================================================*/
                "recordWav" -> {
                    val path: String = call.arguments as String;
                    val ret = audioManager!!.recordWav(path)
                    endCallWithResult(result, ret)
                }
                "stopRecordWav" -> {
                    val ret = audioManager!!.stopRecordWav()
                    endCallWithResult(result, ret)
                }
                "test" -> {
                    val t = Test()
                    t.test1()
                    result.success(0)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}