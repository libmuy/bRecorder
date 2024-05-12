package cyou.libmuy.brecorder

import android.media.*
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.RequiresApi
import java.io.File
import java.util.*
import kotlin.math.ln
import kotlin.math.max


@RequiresApi(Build.VERSION_CODES.O)
class Player constructor(
    channelsHandler: PlatformChannelsHandler,
    onCompleteCallback: () -> Unit,
    onErrorCallback: () -> Unit,
    onCleanupCallback: (() -> Unit)? = null,
) {
    private val mChannelsHandler = channelsHandler
    private var mPlayer: MediaPlayer? = null
    private val mOnCompleteCallback = onCompleteCallback
    private val mOnErrorCallback = onErrorCallback
    private val mOnCleanupCallback = onCleanupCallback
    private var mPlayStartPosition = 0
    private var mPositionNotifyTimer: Timer? = null
    private var mOnSeekCompleteCallback: (() -> Unit)? = null

    private fun cleanup(): Boolean {
        try {
            mPlayStartPosition = 0
            mPositionNotifyTimer?.cancel()
            mPositionNotifyTimer = null

            if (mPlayer != null) {
                mPlayer?.stop()
                mPlayer?.release()
                mPlayer = null
            }
            mOnCleanupCallback?.invoke()
        } catch (e: Exception) {
            Log.e(LOG_TAG, "Cleanup Player Got Exception:$e")
            return false
        }
        return true
    }

    private fun sendPositionUpdateEvent() {
        mChannelsHandler.sendEvent(
            hashMapOf(
                "playEvent" to hashMapOf(
                    "event" to "PositionUpdate",
                    "position" to mPlayer?.currentPosition
                )
            )
        )
    }

    private fun startPositionUpdateNotification() {
        mPositionNotifyTimer = Timer()
        mPositionNotifyTimer?.scheduleAtFixedRate(object: TimerTask(){
            override fun run() {
                Handler(Looper.getMainLooper()).post {
                    sendPositionUpdateEvent()
                }
            }
        },0, PLAYBACK_POSITION_NOTIFY_INTERVAL_MS)
    }
    
    fun startPlay(path: String, positionNotifyIntervalMs: Int): AudioResult<NoValue> {
        if (!File(path).exists()) {
            return AudioResult(AudioErrorInfo.FileNotFound)
        }

        try {
            mPlayer = MediaPlayer()
            mPlayer?.setDataSource(path)
            mPlayer?.setOnCompletionListener {
                Log.d(LOG_TAG, "Playback complete")
                mChannelsHandler.sendEvent(
                    hashMapOf(
                        "playEvent" to hashMapOf(
                            "event" to "PlayComplete",
                            "data" to null
                        )
                    )
                )
                mOnCompleteCallback()
                cleanup()
            }
            mPlayer?.setOnErrorListener { _, _, _ ->
                Log.d(LOG_TAG, "Playback error")
                mOnErrorCallback()
                cleanup()
                true
            }
            mPlayer?.setOnSeekCompleteListener {
                if (mOnSeekCompleteCallback != null)
                    mOnSeekCompleteCallback?.invoke()
            }

            mPlayer?.prepare()

            if (mPlayStartPosition > 0) {
                mOnSeekCompleteCallback = {
                    mPlayer?.start()
                    startPositionUpdateNotification()
                    mOnSeekCompleteCallback = null
                }
                mPlayer?.seekTo(mPlayStartPosition)
            } else {
                mPlayer?.start()
                startPositionUpdateNotification()
            }

        } catch (e: Exception) {
            Log.e(LOG_TAG, "Start Playback Got Exception:$e")
            cleanup()
            return AudioResult(AudioErrorInfo.NG)
        }
        return AudioResult(AudioErrorInfo.OK)
    }

    fun stopPlay(): AudioResult<NoValue> {

        if (!cleanup()) {
            return AudioResult(AudioErrorInfo.NG)
        }

        return AudioResult(AudioErrorInfo.OK)
    }

    fun pausePlay(): AudioResult<NoValue> {
        try {
            mPlayer?.pause()
            mPositionNotifyTimer?.cancel()
            mPositionNotifyTimer = null
        } catch (e: Exception) {
            Log.e(LOG_TAG, "Stop Playback Got Exception:$e")
            cleanup()
            return AudioResult(AudioErrorInfo.NG)
        }

        return AudioResult(AudioErrorInfo.OK)
    }

    fun resumePlay(): AudioResult<NoValue> {

        try {
            mPlayer?.start()
            startPositionUpdateNotification()

        } catch (e: Exception) {
            Log.e(LOG_TAG, "Stop Playback Got Exception:$e")
            cleanup()
            return AudioResult(AudioErrorInfo.NG)
        }

        return AudioResult(AudioErrorInfo.OK)
    }

    fun seekTo(position: Int): AudioResult<NoValue> {
        if (mPlayer == null) {
            mPlayStartPosition = position
            return AudioResult(AudioErrorInfo.OK)
        }

        try {
            mPlayer?.seekTo(position)
            Log.d(LOG_TAG, "Seek to $position, result:${mPlayer?.currentPosition}")
            return AudioResult(AudioErrorInfo.OK)

        } catch (e: Exception) {
            Log.e(LOG_TAG, "Stop Playback Got Exception:$e")
            cleanup()
            return AudioResult(AudioErrorInfo.NG)
        }
    }

    fun setPitch(pitch: Double): AudioResult<NoValue> {
        try {
            val param = mPlayer?.playbackParams
            param!!.pitch = pitch.toFloat()
            mPlayer?.playbackParams = param

        } catch (e: Exception) {
            Log.e(LOG_TAG, "Set pitch Got Exception:$e")
            cleanup()
            return AudioResult(AudioErrorInfo.NG)
        }

        return AudioResult(AudioErrorInfo.OK)
    }


    fun setSpeed(speed: Double): AudioResult<NoValue> {
        try {
            val param = mPlayer?.playbackParams
            param!!.speed = speed.toFloat()
            mPlayer?.playbackParams = param

        } catch (e: Exception) {
            Log.e(LOG_TAG, "Set Speed Got Exception:$e")
            cleanup()
            return AudioResult(AudioErrorInfo.NG)
        }

        return AudioResult(AudioErrorInfo.OK)
    }
    fun setVolume(volume: Double): AudioResult<NoValue> {
        val maxVolume = 100.0;
        val currVolume = maxVolume * volume
        val log1 = 1 - (ln(maxVolume - currVolume) / ln(maxVolume)).toFloat()

        try {
            Log.d(LOG_TAG, "Set volume to $log1")
            mPlayer?.setVolume(log1, log1)
        } catch (e: Exception) {
            Log.e(LOG_TAG, "Set Speed Got Exception:$e")
            cleanup()
            return AudioResult(AudioErrorInfo.NG)
        }

        return AudioResult(AudioErrorInfo.OK)
    }
}
