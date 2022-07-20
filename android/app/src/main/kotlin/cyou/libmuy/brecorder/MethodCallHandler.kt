package cyou.libmuy.brecorder

import android.os.Build
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result

class MethodCallHandler (act: FlutterActivity, flutterEngine: FlutterEngine?){
    private var audioManager: AudioManager = AudioManager(act)
    private var flutterEngine = flutterEngine

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

    @RequiresApi(Build.VERSION_CODES.M)
    fun handleMethodCalls() {

        MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, "libmuy.com/brecorder").setMethodCallHandler { call, result ->
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