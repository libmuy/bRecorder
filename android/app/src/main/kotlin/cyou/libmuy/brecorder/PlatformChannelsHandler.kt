package cyou.libmuy.brecorder

import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result


@RequiresApi(Build.VERSION_CODES.M)
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

    private fun <T>endCallWithoutResult(result: Result, ret: AudioResult<T>) {
        if (ret.isOK()) {
            result.success(ret.result)
        } else {
            result.error(ret.errorCode, ret.errorMessage, null)
        }
    }

    fun <T>sendEvent(data: T) {
        waveformEventSink?.success(data)
    }

    fun sendEventFail(errorMessage: String) {
        waveformEventSink?.error("", errorMessage, null)
    }

    fun sendEventEnd() {
        waveformEventSink?.endOfStream()
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
                    val args = (arguments as String).split(",")
                    var sampleRate = 0
                    var sendRate = 0
                    if (args[0] == "waveform") {
                        Log.i(LOG_TAG, "EventChannel: waveform")
                        if (args.size < 3) {
                            events.error("-1", "Parameter count error", null)
                            Log.i(LOG_TAG, "EventChannel: waveform: Parameter count error")
                            return
                        }
                        try {
                            sampleRate = args[1].toInt()
                        } catch (e: Exception) {
                            events.error("-1", "Parameter parse error", null)
                            Log.i(LOG_TAG, "EventChannel: waveform: Parameter parse error")
                            return
                        }

                        try {
                            sendRate = args[2].toInt()
                        } catch (e: Exception) {
                            events.error("-1", "Parameter parse error", null)
                            Log.i(LOG_TAG, "EventChannel: waveform: Parameter parse error")
                            return
                        }

                        if (sampleRate <= 0) {
                            events.error("-1", "Parameter error: waveform sample rate too small", null)
                            Log.i(LOG_TAG, "EventChannel: waveform: sample rate too small")
                            return
                        }

                        if (sendRate <= 0) {
                            events.error("-1", "Parameter error: waveform send rate too small", null)
                            Log.i(LOG_TAG, "EventChannel: waveform: send rate too small")
                            return
                        }
                        waveformEventSink = events
                        audioManager.eventListenStart(sampleRate, sendRate)
                    }
                }
                override fun onCancel(arguments: Any?) {
                    val args = arguments as String
                    audioManager.eventListenStop()
                    waveformEventSink!!.endOfStream()
                    waveformEventSink = null
                    Log.w(LOG_TAG, "EventChannel onCancel called, args:$args")
                }
            })

    }

    private fun handleMethodCalls() {

        MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, "libmuy.com/brecorder/methodchannel").setMethodCallHandler { call, result ->
//            val dbgpath = "$downloadFolder/test.aac"
            when (call.method) {
                "getDuration" -> {
                    val path: String = call.arguments as String;
                    val ret = audioManager!!.getDuration(path)
                    endCallWithResult(result, ret)
                }
                "startRecord" -> {
                    val path: String = call.arguments as String;
                    val ret = audioManager!!.startRecord(path)
                    endCallWithoutResult(result, ret)
                }
                "stopRecord" -> {
                    val ret = audioManager!!.stopRecord()
                    endCallWithoutResult(result, ret)
                }
                "startPlay" -> {
                    val path: String = call.arguments as String;
                    val ret = audioManager!!.startPlay(path)
                    endCallWithoutResult(result, ret)
                }
                "stopPlay" -> {
                    val ret = audioManager!!.stopPlay()
                    endCallWithoutResult(result, ret)
                }
                "setPitch" -> {
                    val pitch = call.arguments as Double;
                    val ret = audioManager!!.setPitch(pitch)
                    endCallWithoutResult(result, ret)
                }
                "setSpeed" -> {
                    val speed = call.arguments as Double;
                    val ret = audioManager!!.setSpeed(speed)
                    endCallWithoutResult(result, ret)
                }
                "recordWav" -> {
                    val path: String = call.arguments as String;
                    val ret = audioManager!!.recordWav(path)
                    endCallWithoutResult(result, ret)
                }
                "stopRecordWav" -> {
                    val ret = audioManager!!.stopRecordWav()
                    endCallWithoutResult(result, ret)
                }
                "test" -> {
                    result.success(0)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}