package cyou.libmuy.brecorder

import android.annotation.SuppressLint
import android.media.*
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import java.io.File


@RequiresApi(Build.VERSION_CODES.O)
class AudioManager constructor(act: FlutterActivity, channelsHandler: PlatformChannelsHandler){
    private var mRecorder = Recorder(
        act, channelsHandler,
//        onCleanupCallback = { resetState() },
    )
    private var mPlayer = Player(
        channelsHandler,
        onCompleteCallback = { onPlaybackComplete() },
        onErrorCallback =  {onPlayError()},
//        onCleanupCallback = { resetState() },
    )

    private var mState: AudioState = AudioState.Idle

    private fun onPlayError() {
        resetState()
    }

    private fun onPlaybackComplete() {
        resetState()
    }

    private fun resetState() {
        mState = AudioState.Idle
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
    fun startRecord(path : String, waveSampleRate: Int, waveSendRate: Int): AudioResult<NoValue> {
        //check state
        if (mState != AudioState.Idle) {
            return AudioResult(AudioErrorInfo.StateErrNotIdle, extraString = "current state:${mState.name}")
        }

        val result = mRecorder.startRecord(path, waveSampleRate, waveSendRate)
        mState = if (result.isOK())
            AudioState.Recording
        else
            AudioState.Idle
        return result
    }

    fun stopRecord(): AudioResult<NoValue>{
        //check state
        if (mState != AudioState.Recording) {
            return AudioResult(AudioErrorInfo.StateErrNotRecording, extraString = "current state:${mState.name}")
        }

        mState = AudioState.Idle
        return mRecorder.stopRecord()
    }

    fun pauseRecord(): AudioResult<NoValue>{
        //check state
        if (mState != AudioState.Recording) {
            return AudioResult(AudioErrorInfo.StateErrNotRecording, extraString = "current state:${mState.name}")
        }

        val result = mRecorder.pauseRecord()
        mState = if (result.isOK())
            AudioState.RecordPaused
        else
            AudioState.Idle
        return result
    }

    fun resumeRecord(): AudioResult<NoValue>{
        //check state
        if (mState != AudioState.RecordPaused) {
            return AudioResult(AudioErrorInfo.StateErrNotRecording, extraString = "current state:${mState.name}")
        }

        val result = mRecorder.resumeRecord()
        mState = if (result.isOK())
            AudioState.Recording
        else
            AudioState.Idle
        return result
    }

    fun startPlay(path: String, positionNotifyIntervalMs: Int): AudioResult<NoValue>{
        //check state
        if (mState != AudioState.Idle) {
            return AudioResult(AudioErrorInfo.StateErrNotIdle, extraString = "current state:${mState.name}")
        }

        val result = mPlayer.startPlay(path, positionNotifyIntervalMs)
        mState = if (result.isOK())
            AudioState.Playing
        else
            AudioState.Idle
        return result
    }

    fun stopPlay(): AudioResult<NoValue>{
        //check state
        if (mState != AudioState.Playing && mState != AudioState.PlayPaused) {
            return AudioResult(AudioErrorInfo.StateErrNotPlaying, extraString = "current state:${mState.name}")
        }

        mState = AudioState.Idle
        return mPlayer.stopPlay()
    }

    fun pausePlay(): AudioResult<NoValue>{
        //check state
        if (mState != AudioState.Playing) {
            return AudioResult(AudioErrorInfo.StateErrNotPlaying, extraString = "current state:${mState.name}")
        }

        val result = mPlayer.pausePlay()
        mState = if (result.isOK())
            AudioState.PlayPaused
        else
            AudioState.Idle
        return result
    }

    fun resumePlay(): AudioResult<NoValue>{
        //check state
        if (mState != AudioState.PlayPaused) {
            return AudioResult(AudioErrorInfo.StateErrNotPlaying, extraString = "current state:${mState.name}")
        }

        val result = mPlayer.resumePlay()
        mState = if (result.isOK())
            AudioState.Playing
        else
            AudioState.Idle
        return result
    }

    fun seekTo(position: Int, onComplete: (() -> Unit)?): AudioResult<NoValue>{
        //No state check, set the next play position when not playing
        val result = mPlayer.seekTo(position, onComplete)
        if (!result.isOK()) mState = AudioState.Idle
        return result
    }

    fun setPitch(pitch: Double): AudioResult<NoValue>{
        //check state
        if (mState != AudioState.Playing && mState != AudioState.PlayPaused) {
            return AudioResult(AudioErrorInfo.StateErrNotPlaying, extraString = "current state:${mState.name}")
        }

        val result = mPlayer.setPitch(pitch)
        if (!result.isOK()) mState = AudioState.Idle
        return result
    }


    fun setSpeed(speed: Double): AudioResult<NoValue>{
        //check state
        if (mState != AudioState.Playing && mState != AudioState.PlayPaused) {
            return AudioResult(AudioErrorInfo.StateErrNotPlaying, extraString = "current state:${mState.name}")
        }

        val result = mPlayer.setSpeed(speed)
        if (!result.isOK()) mState = AudioState.Idle
        return result
    }

    //FOR DEBUG

    fun recordWav(path: String): AudioResult<NoValue>{
        return mRecorder.recordWav(path)
    }
    fun stopRecordWav(): AudioResult<NoValue>{
        return mRecorder.stopRecordWav()
    }
}
