package cyou.libmuy.brecorder

import android.media.*
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.RequiresApi
import java.io.BufferedOutputStream
import java.io.FileOutputStream
import java.nio.ByteBuffer


private const val WRITE_WAV_TO_FILE = false

@RequiresApi(Build.VERSION_CODES.M)
class PcmToMp4 (mp4Path: String, feedPcmCallback: (buffer: ByteBuffer) -> Int): MediaCodec.Callback() {
    private val mOutputFileWav = BufferedOutputStream(FileOutputStream("$mp4Path.wav"))
    private var mStartTimeNs: Long = 0
    private var mPausedStartTimeNs: Long = 0
    private var mPausedTotalTimeNs: Long = 0
    private var mStopped = false
    private var mPaused = false
    private var mOutputByteArray: ByteArray? = null
    private var mEncoder: MediaCodec? = null
    private var mMuxer: MediaMuxer? = null
    private var mMuxerTrackIdx = -1
    private val mReadPcmFun: (buffer: ByteBuffer) -> Int = feedPcmCallback
    private var mFormat = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, SAMPLE_RATE, CHANNEL_COUNT)

    private var mExtractor = MediaExtractor()

    init {
        mFormat.setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
        mFormat.setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, RECORDER_READ_BYTES)
        mFormat.setInteger(MediaFormat.KEY_CHANNEL_MASK, CHANNEL_CONFIG)
        mFormat.setInteger(MediaFormat.KEY_BIT_RATE, BIT_RATE)
//        mFormat.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 0);


        mEncoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
        mEncoder!!.configure(mFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        mEncoder!!.setCallback(this)

        mMuxer = MediaMuxer(mp4Path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        mEncoder!!.start()

    }

    fun stop() {
        mStopped = true
        Log.i(LOG_TAG, "Stopping PCM2MP4")
    }

    fun pause() {
        mPaused = true
        Log.i(LOG_TAG, "Pausing PCM2MP4")
    }

    private fun release() {
        if (WRITE_WAV_TO_FILE) {
            mOutputFileWav.flush()
            mOutputFileWav.close()
        }

        mEncoder!!.stop()
        mEncoder!!.release()
        mEncoder = null

        mMuxer!!.stop()
        mMuxer!!.release()
        mMuxer = null
    }

    override fun onInputBufferAvailable(encoder: MediaCodec, bufId: Int) {
        //Stopped feed a END_OF_STREAM flag
        if (mStopped) {
            Log.i(LOG_TAG, "Write EOS to Encoder")
            encoder!!.queueInputBuffer(bufId, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
            return
        }

        val inputBuffer = encoder.getInputBuffer(bufId) ?: return
        var sampleSize = mReadPcmFun(inputBuffer)

        if (mStartTimeNs == 0L) mStartTimeNs = System.nanoTime();
        val timeStamp = (System.nanoTime() - mStartTimeNs - mPausedTotalTimeNs) / 1000;

        //write wav to file
        if (WRITE_WAV_TO_FILE) {
            mOutputFileWav.write(inputBuffer.array(), 0, sampleSize)
        }

//        val b = Bundle()
//        b.putInt(MediaCodec.PARAMETER_KEY_REQUEST_SYNC_FRAME, 0)
//        encoder.setParameters(b)
        //Return buffer back to Encoder
        encoder!!.queueInputBuffer(bufId, 0, sampleSize, timeStamp, MediaCodec.BUFFER_FLAG_KEY_FRAME)
    }

    override fun onOutputBufferAvailable(encoder: MediaCodec, bufId: Int, bufInfo: MediaCodec.BufferInfo) {
        val outputBuffer = encoder.getOutputBuffer(bufId) ?: return
        if (mOutputByteArray == null || mOutputByteArray!!.size < (bufInfo.size + 7))
            mOutputByteArray = ByteArray(bufInfo.size + 7)

        when (bufInfo.flags) {
            MediaCodec.BUFFER_FLAG_CODEC_CONFIG -> {
                Log.d(LOG_TAG, "BUFFER_FLAG_CODEC_CONFIG: $bufInfo")
            }
            MediaCodec.BUFFER_FLAG_PARTIAL_FRAME ->
                Log.d(LOG_TAG, "BUFFER_FLAG_PARTIAL_FRAME: $bufInfo")

            // No flags, write data to Muxer
            else -> {
                outputBuffer.position(bufInfo.offset)
                outputBuffer.limit(bufInfo.offset + bufInfo.size)
                outputBuffer.get(mOutputByteArray, 7, bufInfo.size)
                mMuxer!!.writeSampleData(mMuxerTrackIdx,outputBuffer, bufInfo)

                if (bufInfo.flags == MediaCodec.BUFFER_FLAG_KEY_FRAME)
                    Log.d(LOG_TAG, "Write KEY FRAME to Muxer")

                if (bufInfo.flags == MediaCodec.BUFFER_FLAG_END_OF_STREAM) {
                    Log.d(LOG_TAG, "Write EOS to Muxer")
                    Handler(Looper.getMainLooper()).post {
                        release()
                    }
                }
            }
        }

        encoder.releaseOutputBuffer(bufId, false)
    }

    override fun onOutputFormatChanged(c: MediaCodec, format: MediaFormat) {
        mMuxerTrackIdx = mMuxer!!.addTrack(format)
        mMuxer!!.start()
        Log.d(LOG_TAG, "encoder output format changed, start muxer. format: $format")
    }

    override fun onError(c: MediaCodec, e: MediaCodec.CodecException) {
        Log.d(LOG_TAG, "Got decoder exception: $e")
    }
}