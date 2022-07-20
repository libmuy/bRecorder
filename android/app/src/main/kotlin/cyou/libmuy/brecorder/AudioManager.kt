package cyou.libmuy.brecorder

import android.Manifest
import android.content.pm.PackageManager
import android.media.MediaMetadataRetriever
import android.media.MediaRecorder
import android.media.MediaPlayer
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import java.io.File

private const val PERMISSIONS_REQ = 1

class AudioManager constructor(act: FlutterActivity){
    private var activity: FlutterActivity
    private var mediaRecorder: MediaRecorder? = null
    private var mediaPlayer: MediaPlayer? = null
    private var state: AudioState = AudioState.Idle

    init {
        activity = act
    }


    private fun requestPermissions(): Boolean{
        val permissionsRequired = mutableListOf<String>()


        var hasRecordPermission = ContextCompat.checkSelfPermission(activity.context, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        if (!hasRecordPermission){
            permissionsRequired.add(Manifest.permission.RECORD_AUDIO)
        }

        var hasStoragePermission = ContextCompat.checkSelfPermission(activity.context,Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
        if (!hasStoragePermission){
            permissionsRequired.add(Manifest.permission.WRITE_EXTERNAL_STORAGE)
        }

        if (permissionsRequired.isNotEmpty()){
            ActivityCompat.requestPermissions(activity, permissionsRequired.toTypedArray(),PERMISSIONS_REQ)
        }

        hasRecordPermission = ContextCompat.checkSelfPermission(activity.context, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        hasStoragePermission = ContextCompat.checkSelfPermission(activity.context,Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED

        return hasRecordPermission && hasStoragePermission
    }



    fun getDuration(path: String): AudioResult<Int> {
        var duration = 0

        //check state
        if (state != AudioState.Idle) {
            return AudioResult(AudioErrorInfo.StateErrNotIdle, extraString = "current state:${state.name}")
        }

        if (!File(path).exists()) {
            return AudioResult(AudioErrorInfo.FileNotFound)
        }

        try {
            val mmr = MediaMetadataRetriever()
            mmr.setDataSource(path)
            val durationStr = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
            duration = durationStr!!.toInt()
        } catch (e: Exception) {
            Log.e("Audio-Mgr", "Got Exception:$e")
            return AudioResult(AudioErrorInfo.NG)
        }
        return AudioResult(AudioErrorInfo.OK, duration)
    }

    fun startRecord(path : String): AudioResult<NoValue> {
        //check state
        if (state != AudioState.Idle) {
            return AudioResult(AudioErrorInfo.StateErrNotIdle, extraString = "current state:${state.name}")
        }

        //check the device has a microphone
        if (!activity.packageManager.hasSystemFeature(PackageManager.FEATURE_MICROPHONE)) {
            return AudioResult(AudioErrorInfo.NoMic)
        }

        // Request Permissions
        if (!requestPermissions()) {
            return AudioResult(AudioErrorInfo.NoPermission)
        }

        try {

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

            state = AudioState.Recording
        } catch (e: Exception) {
            Log.e("Audio-Mgr", "Got Exception:$e")
            return AudioResult(AudioErrorInfo.NG)
        }

        return AudioResult(AudioErrorInfo.OK)
    }

    fun stopRecord(): AudioResult<NoValue>{
        //check state
        if (state != AudioState.Recording) {
            return AudioResult(AudioErrorInfo.StateErrNotRecording, extraString = "current state:${state.name}")
        }

        try {
            mediaRecorder?.stop()
            mediaRecorder?.release()
            mediaRecorder = null
            state = AudioState.Idle
        } catch (e: Exception) {
            Log.e("Audio-Mgr", "Got Exception:$e")
            return AudioResult(AudioErrorInfo.NG)
        }

        return AudioResult(AudioErrorInfo.OK)
    }

    fun startPlay(path: String): AudioResult<NoValue>{
        //check state
        if (state != AudioState.Idle) {
            return AudioResult(AudioErrorInfo.StateErrNotIdle, extraString = "current state:${state.name}")
        }

        if (!File(path).exists()) {
            return AudioResult(AudioErrorInfo.FileNotFound)
        }

        try {
            mediaPlayer = MediaPlayer()
            mediaPlayer?.setDataSource(path)
            mediaPlayer?.setOnCompletionListener {
                Log.d("Audio-Mgr", "Playback complete")
                state = AudioState.Idle
            }
            mediaPlayer?.setOnErrorListener { _, _, _ ->
                Log.d("Audio-Mgr", "Playback error")
                state = AudioState.Idle
                true
            }

            mediaPlayer?.prepare()
            mediaPlayer?.start()

            state = AudioState.Playing
        } catch (e: Exception) {
            Log.e("Audio-Mgr", "Got Exception:$e")
            return AudioResult(AudioErrorInfo.NG)
        }


        return AudioResult(AudioErrorInfo.OK)
    }

    fun stopPlay(): AudioResult<NoValue>{
        //check state
        if (state != AudioState.Playing) {
            return AudioResult(AudioErrorInfo.StateErrNotPlaying, extraString = "current state:${state.name}")
        }

        try {
            mediaPlayer?.stop()
            mediaPlayer?.release()
            mediaPlayer = null

            state = AudioState.Idle
        } catch (e: Exception) {
            Log.e("Audio-Mgr", "Got Exception:$e")
            return AudioResult(AudioErrorInfo.NG)
        }

        return AudioResult(AudioErrorInfo.OK)
    }

    @RequiresApi(Build.VERSION_CODES.M)
    fun setPitch(pitch: Double): AudioResult<NoValue>{
        //check state
        if (state != AudioState.Playing) {
            return AudioResult(AudioErrorInfo.StateErrNotPlaying, extraString = "current state:${state.name}")
        }

        try {
            var param = mediaPlayer?.playbackParams
            param!!.pitch = pitch.toFloat()
            mediaPlayer?.playbackParams = param

        } catch (e: Exception) {
            Log.e("Audio-Mgr", "Got Exception:$e")
            return AudioResult(AudioErrorInfo.NG)
        }

        return AudioResult(AudioErrorInfo.OK)
    }

    @RequiresApi(Build.VERSION_CODES.M)
    fun setSpeed(speed: Double): AudioResult<NoValue>{
        //check state
        if (state != AudioState.Playing) {
            return AudioResult(AudioErrorInfo.StateErrNotPlaying, extraString = "current state:${state.name}")
        }

        try {
            var param = mediaPlayer?.playbackParams
            param!!.speed = speed.toFloat()
            mediaPlayer?.playbackParams = param

        } catch (e: Exception) {
            Log.e("Audio-Mgr", "Got Exception:$e")
            return AudioResult(AudioErrorInfo.NG)
        }

        return AudioResult(AudioErrorInfo.OK)
    }



}

enum class AudioState {
    Playing,
    Recording,
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
}

class AudioResult <Result>(error: AudioErrorInfo, result: Result? = null, extraString: String = "") {
    private val errorInfo = error
    private val extraString = extraString
    public val errorCode = error.code.toString()
    public val errorMessage = error.msg
    get() {
        if (extraString == "") return field

        return "$field: $extraString"
    }
    public var result = result


    fun isOK(): Boolean {
        return errorInfo == AudioErrorInfo.OK
    }
}
class NoValue
