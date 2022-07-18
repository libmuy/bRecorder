package cyou.libmuy.brecorder

import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.content.IntentFilter
import android.media.MediaMetadataRetriever
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import android.content.pm.PackageManager
import android.media.MediaRecorder


class MainActivity: FlutterActivity() {
    private var mediaRecorder: MediaRecorder? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
//        GeneratedPluginRegistrant.registerWith(this)

        MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, "libmuy.com/brecorder").setMethodCallHandler { call, result ->
            if (call.method == "getDuration") {
                val path: String = call.arguments as String;
//                val mmr = MediaMetadataRetriever()
//                mmr.setDataSource(path)
//                val durationStr = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
//                val millSecond = durationStr!!.toInt()
//                result.success(millSecond)
                result.success(101)
            } else if (call.method == "test") {
                result.success(0)
            } else {
//                result.notImplemented()
                result.success(102)
            }
        }
    }

    fun startRecording(path : String): Boolean {

        //check the device has a microphone
        if (context.packageManager.hasSystemFeature(PackageManager.FEATURE_MICROPHONE)) {

            //create new instance of MediaRecorder
            mediaRecorder = MediaRecorder()

            //specify source of audio (Microphone)
            mediaRecorder?.setAudioSource(MediaRecorder.AudioSource.MIC)

            //specify file type and compression format
            mediaRecorder?.setOutputFormat(MediaRecorder.OutputFormat.AAC_ADTS)
            mediaRecorder?.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)

            //specify audio sampling rate and encoding bit rate (48kHz and 128kHz respectively)
            mediaRecorder?.setAudioSamplingRate(48000)
            mediaRecorder?.setAudioEncodingBitRate(128000)

            //specify where to save
            mediaRecorder?.setOutputFile(path)

            //record
            mediaRecorder?.prepare()
            mediaRecorder?.start()

            return true
        } else {
            return false
        }
    }

    fun stopRecording() {
        mediaRecorder?.stop()
        mediaRecorder?.release()
        mediaRecorder = null
    }


}
