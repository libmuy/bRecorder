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
import java.io.FileOutputStream
import java.lang.Integer.max
import java.nio.ByteBuffer



@RequiresApi(Build.VERSION_CODES.O)
class Recorder constructor(act: FlutterActivity, channelsHandler: PlatformChannelsHandler,
                           onCleanupCallback: (() -> Unit)? = null,
){
    private val mActivity: FlutterActivity = act
    private val mChannelsHandler = channelsHandler
    private val mOnCleanupCallback = onCleanupCallback
    private var mRecorder: AudioRecord? = null
    private var mPcmToMp4: PcmToMp4? = null
    private var mWorkerThread: WorkerThread? = null
    private val mWaveformGenerator = WaveformGenerator(waveformOutputCallback =  {data ->
        if (mWaveSampleRate > 0) {
            val map = HashMap<String, FloatArray>()
            map["waveform"] = data
            mChannelsHandler.sendEvent(map)
        }
    })
    private var mWaveSampleRate = 0         //WAVEFORM サンプリングレート（Hz）、1秒間何回をサンプリングする
    private var mWaveSendRate = 0           //WAVEFORM 1秒間何回をFlutterへ送信する

    // FOR DEBUG
    private var mRecordWavThread: RecordWavThread? = null



    private fun cleanup(): Boolean {
        mWaveSampleRate = 0
        mWaveSendRate = 0
        try {
            if (mPcmToMp4 != null) {
                mPcmToMp4!!.endEncode()
                mPcmToMp4 = null
            }
            if (mRecorder != null) {
                mRecorder?.stop()
                mRecorder?.release()
                mRecorder = null
            }
            mOnCleanupCallback?.invoke()
        } catch (e: Exception) {
            Log.e(LOG_TAG, "Cleanup Player Got Exception:$e")
            return false
        }
        return true
    }


    private fun checkPermissions(): AudioResult<NoValue>{
        val permissionsRequired = mutableListOf<String>()

        //check the device has a microphone
        if (!mActivity.packageManager.hasSystemFeature(PackageManager.FEATURE_MICROPHONE)) {
            return AudioResult(AudioErrorInfo.NoMic)
        }

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

        if(hasRecordPermission && hasStoragePermission) return AudioResult(AudioErrorInfo.OK)

        return AudioResult(AudioErrorInfo.NoPermission)
    }

    @SuppressLint("MissingPermission")
    private fun setupRecorderAndStartWorkerThread() {
        //Recorder setup
        val audioBufferSizeInByte = max(RECORDER_READ_BYTES * 10, // 適当に10フレーム分のバッファを持たせた
            AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AudioFormat.ENCODING_PCM_16BIT))
        mRecorder = AudioRecord(MediaRecorder.AudioSource.MIC,
            SAMPLE_RATE, CHANNEL_CONFIG, AudioFormat.ENCODING_PCM_16BIT, audioBufferSizeInByte)

        mRecorder!!.startRecording()

        mWorkerThread = WorkerThread(
            mRecorder!!,mPcmToMp4!!,mWaveformGenerator,mWaveSampleRate,mWaveSendRate
        ) {
            cleanup()
        }
        mWorkerThread!!.start()
    }

    fun startRecord(path : String): AudioResult<NoValue> {
        // Request Permissions
        val result = checkPermissions()
        if (!result.isOK()) {
            return result
        }

        mWaveSampleRate = WAVEFORM_SAMPLES_PER_SECOND
        mWaveSendRate = WAVEFORM_SEND_PER_SECOND

        try {
            //Encoder Setup
            mPcmToMp4 = PcmToMp4(path)

            //Encoder Recorder and Start work thread
            setupRecorderAndStartWorkerThread()
        } catch (e: Exception) {
            Log.e(LOG_TAG, "Recording Got Exception:$e")
            cleanup()
            return AudioResult(AudioErrorInfo.NG)
        }

        return AudioResult(AudioErrorInfo.OK)
    }

    fun stopRecord(): AudioResult<NoValue>{
        mWorkerThread!!.end()
        mWorkerThread!!.join()
        mPcmToMp4!!.endEncode()

        if (!cleanup()) {
            return AudioResult(AudioErrorInfo.NG)
        }

        return AudioResult(AudioErrorInfo.OK)
    }

    fun pauseRecord(): AudioResult<NoValue>{

        mWorkerThread!!.end()
        mWorkerThread!!.join()
        if (mRecorder != null) {
            mRecorder?.stop()
            mRecorder?.release()
            mRecorder = null
        }

        return AudioResult(AudioErrorInfo.OK)
    }
    fun resumeRecord(): AudioResult<NoValue>{

        try {
            //Encoder Recorder and Start work thread
            setupRecorderAndStartWorkerThread()
        } catch (e: Exception) {
            Log.e(LOG_TAG, "Recording Got Exception:$e")
            cleanup()
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

    class WorkerThread(recorder:AudioRecord,
                       pcmToMp4:PcmToMp4,
                       waveformGenerator: WaveformGenerator,
                       waveSampleRate: Int,
                       waveSendRate: Int,
                       cleanup: () -> Unit
    ): Thread() {
        private var mThreadAlive = true
        private var mRecorder = recorder
        private var mPcmToMp4 = pcmToMp4
        private val mWaveformGenerator = waveformGenerator
        private var mWaveSampleRate = waveSampleRate
        private var mWaveSendRate = waveSendRate
        private var mCleanup = cleanup

        fun end() {
            mThreadAlive = false
        }

        override fun run() {
            Log.i(LOG_TAG, "Start Recording Thread")
            mThreadAlive = true
            while (mThreadAlive) {
                try {
                    mPcmToMp4!!.feedPCM { pcmBuffer ->
                        val size = mRecorder!!.read(pcmBuffer, RECORDER_READ_BYTES)
                        if (size != RECORDER_READ_BYTES) {
                            Log.w(
                                LOG_TAG,
                                "Read $size Bytes from AudioRecorder, wanted:$RECORDER_READ_BYTES"
                            )
                        }
                        if (mWaveSampleRate > 0) mWaveformGenerator.feedPCM(
                            pcmBuffer,
                            size,
                            mWaveSampleRate,
                            mWaveSendRate
                        )

                        size
                    }
                } catch (e: Exception) {
                    Log.e(LOG_TAG, "Recording Thread Got Exception:$e")
                    mCleanup()
                    mThreadAlive = false
                }
            }
            Log.i(LOG_TAG, "Recording stop, save wave to file")
        }
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
