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
                    val sampleRate: Int? = call.argument("samplesPerSecond")
                    val sendRate: Int? = call.argument("sendPerSecond")
                    val path: String? = call.argument("path")
                    if (sampleRate == null || sendRate == null || path == null) {
                        endCallWithParamError(result, "params is NULL")
                    }
                    val ret = audioManager!!.startRecord(path!!, sampleRate!!, sendRate!!)
                    endCallWithResult(result, ret)
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
                    }
                    val ret = audioManager!!.startPlay(path!!, positionNotifyIntervalMs!!)
                    endCallWithResult(result, ret)
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
                    }
                    val ret = audioManager!!.setPitch(pitch)
                    endCallWithResult(result, ret)
                }
                "setSpeed" -> {
                    val speed: Double? = call.argument("speed")
                    if (speed == null) {
                        endCallWithParamError(result, "params is NULL")
                    }
                    val ret = audioManager!!.setSpeed(speed)
                    endCallWithResult(result, ret)
                }

                /*=======================================================================*\
                  Other
                \*=======================================================================*/
                "getDuration" -> {
                    val path: String? = call.argument("path")
                    if (path == null) {
                        endCallWithParamError(result, "params is NULL")
                    }
                    val ret = audioManager!!.getDuration(path)
                    endCallWithResult(result, ret)
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