package cyou.libmuy.brecorder

import android.Manifest
import android.annotation.SuppressLint
import android.content.pm.PackageManager
import android.media.*
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import java.io.BufferedOutputStream
import java.io.File
import java.io.FileOutputStream
import java.lang.Integer.max
import java.nio.ByteBuffer


const val PERMISSIONS_REQ = 1
const val SAMPLE_RATE = 44100                   // サンプリングレート (Hz)、// 全デバイスサポート保障は44100のみ
const val RECORDER_READ_INTERVAL = 50          // 1秒間に何回音声データを処理したいか
const val RECORDER_READ_FRAME_COUNT = SAMPLE_RATE / RECORDER_READ_INTERVAL  //1回処理するフレーム数
const val CHANNEL_COUNT = 1
const val RECORDER_READ_BYTES = RECORDER_READ_FRAME_COUNT * 2 * CHANNEL_COUNT  //1回処理するバイト数
const val BIT_RATE = 64000
const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
private const val SKIP_INITIAL_PCM_MS = 0
const val LOG_TAG = "Audio-Mgr"


@RequiresApi(Build.VERSION_CODES.M)
class AudioManager constructor(act: FlutterActivity, channelsHandler: PlatformChannelsHandler){
    private val mActivity: FlutterActivity
    private val mChannelsHandler = channelsHandler

    private var mRecorder: AudioRecord? = null
    private var mPlayer: MediaPlayer? = null
    private var mPcmToMp4: PcmToMp4? = null
    private var initialPCM = true
    private val mWaveformGenerator = WaveformGenerator {data ->
        if (mWaveSampleRate > 0)
            mChannelsHandler.sendEvent(data)
    }

//    private var mDecoder: MediaCodec? = null

    private var mState: AudioState = AudioState.Idle
    private var mWaveSampleRate = 0         //WAVEFORM サンプリングレート（Hz）、1秒間何回をサンプリングする
    private var mWaveSendRate = 0           //WAVEFORM 1秒間何回をFlutterへ送信する


    // FOR DEBUG
    private var mRecordWavThread: RecordWavThread? = null



    init {
        mActivity = act

    }

    fun eventListenStart(sampleRate: Int, sendRate: Int) {
        mWaveSampleRate = sampleRate
        mWaveSendRate = sendRate
        Log.d(LOG_TAG, "Set waveform sample rate to $sampleRate")
    }

    fun eventListenStop() {
        mWaveSampleRate = 0
        mWaveSendRate = 0
    }

//    private fun short2ByteArray(sa: ShortArray): ByteArray {
//        val ba = ByteArray(sa.size * 2)
//        var i = 0;
//        sa.forEachIndexed { i, s ->
//            val intVal = s.toInt()
//            ba[(i * 2) + 0] = (intVal and 0xFF).toByte()
//            ba[(i * 2) + 1] = ((intVal ushr 8) and 0xFF).toByte()
//        }
//
//        return ba
//    }

    private fun requestPermissions(): Boolean{
        val permissionsRequired = mutableListOf<String>()


        var hasRecordPermission = ContextCompat.checkSelfPermission(mActivity.context, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        if (!hasRecordPermission){
            permissionsRequired.add(Manifest.permission.RECORD_AUDIO)
        }

        var hasStoragePermission = ContextCompat.checkSelfPermission(mActivity.context,Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
        if (!hasStoragePermission){
            permissionsRequired.add(Manifest.permission.WRITE_EXTERNAL_STORAGE)
        }

        if (permissionsRequired.isNotEmpty()){
            ActivityCompat.requestPermissions(mActivity, permissionsRequired.toTypedArray(),PERMISSIONS_REQ)
        }

        hasRecordPermission = ContextCompat.checkSelfPermission(mActivity.context, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        hasStoragePermission = ContextCompat.checkSelfPermission(mActivity.context,Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED

        return hasRecordPermission && hasStoragePermission
    }



    fun getDuration(path: String): AudioResult<Int> {
        val duration: Int

        //check state
        if (mState != AudioState.Idle) {
            return AudioResult(AudioErrorInfo.StateErrNotIdle, extraString = "current state:${mState.name}")
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
            Log.e(LOG_TAG, "GetDuration Got Exception:$e")
            return AudioResult(AudioErrorInfo.NG)
        }
        return AudioResult(AudioErrorInfo.OK, duration)
    }


    @SuppressLint("MissingPermission")
    fun startRecord(path : String): AudioResult<NoValue> {
        //check state
        if (mState != AudioState.Idle) {
            return AudioResult(AudioErrorInfo.StateErrNotIdle, extraString = "current state:${mState.name}")
        }

        //check the device has a microphone
        if (!mActivity.packageManager.hasSystemFeature(PackageManager.FEATURE_MICROPHONE)) {
            return AudioResult(AudioErrorInfo.NoMic)
        }

        // Request Permissions
        if (!requestPermissions()) {
            return AudioResult(AudioErrorInfo.NoPermission)
        }

        try {
            //Recorder setup
            val audioBufferSizeInByte = max(RECORDER_READ_BYTES * 10, // 適当に10フレーム分のバッファを持たせた
                    AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AudioFormat.ENCODING_PCM_16BIT))
            mRecorder = AudioRecord(MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE, CHANNEL_CONFIG, AudioFormat.ENCODING_PCM_16BIT, audioBufferSizeInByte)

            //Encoder Setup
            initialPCM = true
            mPcmToMp4 = PcmToMp4(path) { pcmBuffer ->
                // skip first pcm data
                if (initialPCM) {
                    val timesToSkip = SKIP_INITIAL_PCM_MS * SAMPLE_RATE * 2 / RECORDER_READ_BYTES / 1000
                    Log.w(LOG_TAG, "Skip $timesToSkip times read of PCM")
                    (0 until timesToSkip).forEach() { _ ->
                        val size = mRecorder!!.read(pcmBuffer, RECORDER_READ_BYTES)
                        if (size != RECORDER_READ_BYTES) {
                            Log.w(LOG_TAG, "Read $size Bytes from AudioRecorder, wanted:$RECORDER_READ_BYTES")
                        }
                    }
                    initialPCM = false
                }
                val size = mRecorder!!.read(pcmBuffer, RECORDER_READ_BYTES)
                if (size != RECORDER_READ_BYTES) {
                    Log.w(LOG_TAG, "Read $size Bytes from AudioRecorder, wanted:$RECORDER_READ_BYTES")
                }
                if (mWaveSampleRate > 0) mWaveformGenerator.feedPCM(pcmBuffer, size, mWaveSampleRate, mWaveSendRate)
                size
            }

            mRecorder!!.startRecording()
            mState = AudioState.Recording
        } catch (e: Exception) {
            Log.e(LOG_TAG, "Recording Got Exception:$e")
            return AudioResult(AudioErrorInfo.NG)
        }

        return AudioResult(AudioErrorInfo.OK)
    }

    fun stopRecord(): AudioResult<NoValue>{
        //check state
        if (mState != AudioState.Recording) {
            return AudioResult(AudioErrorInfo.StateErrNotRecording, extraString = "current state:${mState.name}")
        }

        try {
            mPcmToMp4!!.stop()
            mPcmToMp4 = null

            mRecorder!!.stop()
            mRecorder!!.release()
            mRecorder = null

            mState = AudioState.Idle
        } catch (e: Exception) {
            Log.e(LOG_TAG, "Stop Recording Got Exception:$e")
            return AudioResult(AudioErrorInfo.NG)
        }

        return AudioResult(AudioErrorInfo.OK)
    }

    fun startPlay(path: String): AudioResult<NoValue>{
        //check state
        if (mState != AudioState.Idle) {
            return AudioResult(AudioErrorInfo.StateErrNotIdle, extraString = "current state:${mState.name}")
        }

        if (!File(path).exists()) {
            return AudioResult(AudioErrorInfo.FileNotFound)
        }

        try {
            mPlayer = MediaPlayer()
            mPlayer?.setDataSource(path)
            mPlayer?.setOnCompletionListener {
                Log.d(LOG_TAG, "Playback complete")
                mState = AudioState.Idle
            }
            mPlayer?.setOnErrorListener { _, _, _ ->
                Log.d(LOG_TAG, "Playback error")
                mState = AudioState.Idle
                true
            }

            mPlayer?.prepare()
            mPlayer?.start()

            mState = AudioState.Playing
        } catch (e: Exception) {
            Log.e(LOG_TAG, "Start Playback Got Exception:$e")
            return AudioResult(AudioErrorInfo.NG)
        }


        return AudioResult(AudioErrorInfo.OK)
    }

    fun stopPlay(): AudioResult<NoValue>{
        //check state
        if (mState != AudioState.Playing) {
            return AudioResult(AudioErrorInfo.StateErrNotPlaying, extraString = "current state:${mState.name}")
        }

        try {
            mPlayer?.stop()
            mPlayer?.release()
            mPlayer = null

            mState = AudioState.Idle
        } catch (e: Exception) {
            Log.e(LOG_TAG, "Stop Playback Got Exception:$e")
            return AudioResult(AudioErrorInfo.NG)
        }

        return AudioResult(AudioErrorInfo.OK)
    }

    fun seekTo(position: Int): AudioResult<NoValue>{
        //check state
        if (mState != AudioState.Playing) {
            return AudioResult(AudioErrorInfo.StateErrNotPlaying, extraString = "current state:${mState.name}")
        }

        try {
            mPlayer?.seekTo(position)
        } catch (e: Exception) {
            Log.e(LOG_TAG, "Stop Playback Got Exception:$e")
            return AudioResult(AudioErrorInfo.NG)
        }

        return AudioResult(AudioErrorInfo.OK)
    }

    fun setPitch(pitch: Double): AudioResult<NoValue>{
        //check state
        if (mState != AudioState.Playing) {
            return AudioResult(AudioErrorInfo.StateErrNotPlaying, extraString = "current state:${mState.name}")
        }

        try {
            val param = mPlayer?.playbackParams
            param!!.pitch = pitch.toFloat()
            mPlayer?.playbackParams = param

        } catch (e: Exception) {
            Log.e(LOG_TAG, "Set pitch Got Exception:$e")
            return AudioResult(AudioErrorInfo.NG)
        }

        return AudioResult(AudioErrorInfo.OK)
    }


    fun setSpeed(speed: Double): AudioResult<NoValue>{
        //check state
        if (mState != AudioState.Playing) {
            return AudioResult(AudioErrorInfo.StateErrNotPlaying, extraString = "current state:${mState.name}")
        }

        try {
            val param = mPlayer?.playbackParams
            param!!.speed = speed.toFloat()
            mPlayer?.playbackParams = param

        } catch (e: Exception) {
            Log.e(LOG_TAG, "Set Speed Got Exception:$e")
            return AudioResult(AudioErrorInfo.NG)
        }

        return AudioResult(AudioErrorInfo.OK)
    }

    fun recordWav(path: String): AudioResult<NoValue>{
        mRecordWavThread = RecordWavThread(path)
        mRecordWavThread!!.start()

        return AudioResult(AudioErrorInfo.OK)
    }
    fun stopRecordWav(): AudioResult<NoValue>{
        mRecordWavThread!!.recording = false
        mRecordWavThread!!.join()

        return AudioResult(AudioErrorInfo.OK)
    }
}

@RequiresApi(Build.VERSION_CODES.M)
class RecordWavThread(path: String): Thread() {
    private var mRecorder: AudioRecord? = null
    private var mOutputFile = BufferedOutputStream(FileOutputStream(path))
    var recording = false

    @SuppressLint("MissingPermission")
    override fun run() {
        //Recorder setup
        val audioBufferSizeInByte = max(RECORDER_READ_BYTES * 10, // 適当に10フレーム分のバッファを持たせた
            AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AudioFormat.ENCODING_PCM_16BIT))
        mRecorder = AudioRecord(MediaRecorder.AudioSource.MIC,
            SAMPLE_RATE, CHANNEL_CONFIG, AudioFormat.ENCODING_PCM_16BIT, audioBufferSizeInByte)

        val buf = ByteBuffer.allocateDirect(4096)

        mRecorder!!.startRecording()
        recording = true
        while (recording) {
            val size = mRecorder!!.read(buf, RECORDER_READ_BYTES)

            if (size <= 0) {
                Log.e(LOG_TAG, "AudioRecorder read: $size bytes")
            } else {
                mOutputFile.write(buf.array(), 0, size)
                Log.d(LOG_TAG, "writing $size bytes wave to file")
            }
        }

        Log.i(LOG_TAG, "Recording stop, save wave to file")
        mOutputFile.flush()
        mOutputFile.close()
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
