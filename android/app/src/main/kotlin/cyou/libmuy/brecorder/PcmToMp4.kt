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
class PcmToMp4 (mp4Path: String): Thread() {
    private val mOutputFileWav = BufferedOutputStream(FileOutputStream("$mp4Path.wav"))
    private var mActive = true
    private var mEncoder: MediaCodec? = null
    private var mMuxer: MediaMuxer? = null
    private var mMuxerTrackIdx = -1
    private var mReceivedBytes = 0L
    private var mFormat = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, SAMPLE_RATE, CHANNEL_COUNT)

    init {
        mFormat.setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
        mFormat.setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, RECORDER_READ_BYTES)
        mFormat.setInteger(MediaFormat.KEY_CHANNEL_MASK, CHANNEL_CONFIG)
        mFormat.setInteger(MediaFormat.KEY_BIT_RATE, BIT_RATE)
        mEncoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
        mEncoder!!.configure(mFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        mMuxer = MediaMuxer(mp4Path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        mEncoder!!.start()
        start()
    }

    fun endEncode() {
        if (!mActive) return
        // timeout -1: wait indefinitely
        val bufId = mEncoder!!.dequeueInputBuffer(-1)
        mEncoder!!.queueInputBuffer(bufId, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
        Log.i(LOG_TAG, "Write EOS to Encoder")
        join()
        mActive = false
    }

    private fun cleanup() {
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

    private fun bytes2TimeUs(bytes: Long):Long {
        val bytesPerSec = SAMPLE_RATE * CHANNEL_COUNT * 2
        val timeUs = bytes * 1000000 / bytesPerSec;
        return timeUs
    }
    fun feedPCM(readPCM: (buffer: ByteBuffer) -> Int) {
        // timeout -1: wait indefinitely
        val inputBufferId = mEncoder!!.dequeueInputBuffer(-1)

        val inputBuffer = mEncoder!!.getInputBuffer(inputBufferId)
        val sampleSize = readPCM(inputBuffer!!)
        val timestamp = bytes2TimeUs(mReceivedBytes)
        mReceivedBytes += sampleSize
//        Log.d(LOG_TAG, "Got $sampleSize bytes PCM, timestamp:$timestamp")

        //write wav to file
        if (WRITE_WAV_TO_FILE) {
            mOutputFileWav.write(inputBuffer.array(), 0, sampleSize)
        }

        //Return buffer back to Encoder
//        Log.d(LOG_TAG, "Return input buffer to Encoder")
        mEncoder!!.queueInputBuffer(inputBufferId, 0, sampleSize, timestamp, MediaCodec.BUFFER_FLAG_KEY_FRAME)

    }

    override fun run() {
        var outputBufferInfo = MediaCodec.BufferInfo()
        var alive = true

        while (alive) {
//            Log.d(LOG_TAG, "request output buffer...")
            val outputBufferId = mEncoder!!.dequeueOutputBuffer(outputBufferInfo,-1);
//            Log.d(LOG_TAG, "Got output Buffer, flag:${outputBufferInfo.flags}")
            if (outputBufferId >= 0) {
                val outputBuffer = mEncoder!!.getOutputBuffer(outputBufferId);
                when (outputBufferInfo.flags) {
                    MediaCodec.BUFFER_FLAG_CODEC_CONFIG -> {
                        Log.d(LOG_TAG, "BUFFER_FLAG_CODEC_CONFIG: $outputBufferInfo")
                    }
                    MediaCodec.BUFFER_FLAG_PARTIAL_FRAME ->
                        Log.d(LOG_TAG, "BUFFER_FLAG_PARTIAL_FRAME: $outputBufferInfo")

                    // No flags, write data to Muxer
                    else -> {
                        outputBuffer!!.position(outputBufferInfo.offset)
                        outputBuffer.limit(outputBufferInfo.offset + outputBufferInfo.size)
//                        Log.d(LOG_TAG, "Write ${outputBufferInfo.size - outputBufferInfo.offset} bytes Data to Muxer")
                        mMuxer!!.writeSampleData(mMuxerTrackIdx,outputBuffer, outputBufferInfo)

                        if (outputBufferInfo.flags == MediaCodec.BUFFER_FLAG_KEY_FRAME)
                            Log.d(LOG_TAG, "Write KEY FRAME to Muxer")

                        if (outputBufferInfo.flags == MediaCodec.BUFFER_FLAG_END_OF_STREAM) {
                            Log.d(LOG_TAG, "Write EOS to Muxer")
                            Handler(Looper.getMainLooper()).post {
                                cleanup()
                            }
                            alive = false
                        }
                    }
                }
//                Log.d(LOG_TAG, "Release Output Buffer")
                mEncoder!!.releaseOutputBuffer(outputBufferId, false);
            } else if (outputBufferId == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                val format = mEncoder!!.outputFormat; // option B
                mMuxerTrackIdx = mMuxer!!.addTrack(format)
                mMuxer!!.start()
                Log.d(LOG_TAG, "encoder output format changed, start muxer. format: $format")
            }

        }
        Log.i(LOG_TAG, "Pcm2Mp4 Thread exited")
    }

}