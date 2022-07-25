package cyou.libmuy.brecorder

import android.media.*
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import java.io.BufferedOutputStream
import java.io.FileOutputStream


@RequiresApi(Build.VERSION_CODES.M)
class AudioEncoderProcessor (waveformSampleRate: Int, recorder: AudioRecord,
                             channelsHandler: PlatformChannelsHandler,
                             path: String): MediaCodec.Callback() {
    private val mChannelsHandler = channelsHandler
    private val mOutputFile = BufferedOutputStream(FileOutputStream(path))
    private val mOutputFileWav = BufferedOutputStream(FileOutputStream("$path.wav"))
    private var samplePerPixel = 0
    private val mRecord = recorder
    private var count = 0
    private var max = Short.MIN_VALUE
    private var min = Short.MAX_VALUE
    private var mStartTimeNs: Long = 0
    private var stoped = false
    private var mOutputByteArray: ByteArray? = null
    private var mAudioTrack: AudioTrack? = null

    init {
        if (waveformSampleRate > 0) samplePerPixel = SAMPLE_RATE / waveformSampleRate
        startPlayer()

    }

    fun stop() {
        if (stoped) return
        stoped = true
        mAudioTrack!!.stop()
        mAudioTrack!!.release()
        mAudioTrack = null
        mOutputFile.flush()
        mOutputFile.close()
        mOutputFileWav.flush()
        mOutputFileWav.close()
    }

    private fun startPlayer() {

        try {
            mAudioTrack = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build())
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(SAMPLE_RATE)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build())
                .setBufferSizeInBytes(AudioTrack.getMinBufferSize(
                    SAMPLE_RATE,
                    AudioFormat.CHANNEL_OUT_MONO,
                    AudioFormat.ENCODING_PCM_16BIT
                ) * 2)
                .build()
        } catch (e : Exception) {
            Log.e("Audio-Mgr", "create audio track exception:$e")
        }

        mAudioTrack!!.play()
    }

    private fun addADTStoPacket(packet: ByteArray, packetLen: Int) {
        //0: Null
        //1: AAC Main
        //2: AAC LC (Low Complexity)
        //3: AAC SSR (Scalable Sample Rate)
        //4: AAC LTP (Long Term Prediction)
        //5: SBR (Spectral Band Replication)
        //6: AAC Scalable
        val profile = 2 // AAC LC

        //0: 96000 Hz
        //1: 88200 Hz
        //2: 64000 Hz
        //3: 48000 Hz
        //4: 44100 Hz
        //5: 32000 Hz
        //6: 24000 Hz
        //7: 22050 Hz
        //8: 16000 Hz
        //9: 12000 Hz
        //10: 11025 Hz
        //11: 8000 Hz
        //12: 7350 Hz
        val freqIdx = 4 // 44100Hz

        //0: Defined in AOT Specifc Config
        //1: 1 channel: front-center
        //2: 2 channels: front-left, front-right
        //3: 3 channels: front-center, front-left, front-right
        //4: 4 channels: front-center, front-left, front-right, back-center
        //5: 5 channels: front-center, front-left, front-right, back-left, back-right
        //6: 6 channels: front-center, front-left, front-right, back-left, back-right, LFE-channel
        //7: 8 channels: front-center, front-left, front-right, side-left, side-right, back-left, back-right, LFE-channel
        val channelCfg = 1 // 1 channel

        // fill in ADTS data
        packet[0] = 0xFF.toByte()
        packet[1] = 0xF9.toByte()
        packet[2] = (((profile - 1) shl 6) + (freqIdx shl 2) + (channelCfg shr 2)).toByte()
        packet[3] = (((channelCfg and 3) shl 6) + (packetLen shr 11)).toByte()
        packet[4] = ((packetLen and 0x7FF) shr 3).toByte()
        packet[5] = (((packetLen and 7) shl 5) + 0x1F).toByte()
        packet[6] = 0xFC.toByte()
    }

    override fun onInputBufferAvailable(encoder: MediaCodec, bufId: Int) {
        if (stoped) return

        var dataIndex = 0
        var tmp = 0
        val inputBuffer = encoder.getInputBuffer(bufId) ?: return
        if (mStartTimeNs == 0L) mStartTimeNs = System.nanoTime();
        val timeStamp = System.nanoTime() - mStartTimeNs;

        inputBuffer.clear()
        val sampleSize: Int = mRecord.read(inputBuffer, RECORDER_READ_BYTES,
            AudioRecord.READ_BLOCKING
        )

        //write wav to file
//        inputBuffer.flip()
        var buf = ByteArray(sampleSize)
        inputBuffer.get(buf, 0, sampleSize)
        mOutputFileWav.write(buf)

//        mAudioTrack!!.write(inputBuffer,sampleSize,AudioTrack.WRITE_BLOCKING)

        //check allzero
        var allzero = true
        for (element in buf) {
            if (element.toInt() != 0) {
                allzero = false
                break;
            }
        }
        if (allzero) Log.d("Audio-Mgr", "All zero PCM: $sampleSize bytes")

//        Log.d("Audio-Mgr", "Input Buffer Available, prepared $sampleSize bytes data")




        //Sample the waveform data
        if (samplePerPixel > 0) {
            val shorBuffer = inputBuffer.asShortBuffer()
            var eventData = IntArray((sampleSize / 2 / samplePerPixel) + 2)
            (0 until (sampleSize / 2)).forEach { i ->
                val sample = shorBuffer.get(i)
                if (sample > max) max = sample
                if (sample < min) min = sample

                if (++count == samplePerPixel) {
                    tmp = max.toInt() shl 16
                    tmp = tmp or min.toInt()
                    eventData[dataIndex++] = tmp

                    //reset
                    max = Short.MIN_VALUE
                    min = Short.MAX_VALUE
                    count = 0
                }
            }
            //Flag of End
            eventData[dataIndex++] = 0
            mChannelsHandler.sendEvent(eventData)
        }

        //Return buffer back to Encoder
        encoder!!.queueInputBuffer(bufId, 0, sampleSize, timeStamp, 0)
    }

    override fun onOutputBufferAvailable(encoder: MediaCodec, bufId: Int, bufInfo: MediaCodec.BufferInfo) {
        if (stoped) return
        val outputBuffer = encoder.getOutputBuffer(bufId) ?: return
        var isCSD = false
        if (mOutputByteArray == null || mOutputByteArray!!.size < (bufInfo.size + 7))
            mOutputByteArray = ByteArray(bufInfo.size + 7)

        when (bufInfo.flags) {
            MediaCodec.BUFFER_FLAG_KEY_FRAME ->
                Log.d("Audio-Mgr", "BUFFER_FLAG_KEY_FRAME")
            MediaCodec.BUFFER_FLAG_CODEC_CONFIG -> {
                Log.d("Audio-Mgr", "BUFFER_FLAG_CODEC_CONFIG")
                isCSD = true
            }
            MediaCodec.BUFFER_FLAG_END_OF_STREAM ->
                Log.d("Audio-Mgr", "BUFFER_FLAG_END_OF_STREAM")
            MediaCodec.BUFFER_FLAG_PARTIAL_FRAME ->
                Log.d("Audio-Mgr", "BUFFER_FLAG_PARTIAL_FRAME")

        }

        addADTStoPacket(mOutputByteArray!!, bufInfo.size)
        outputBuffer.position(bufInfo.offset)
        outputBuffer.limit(bufInfo.offset + bufInfo.size)
        outputBuffer.get(mOutputByteArray, 7, bufInfo.size)

        if (!isCSD) {
            mOutputFile.write(mOutputByteArray)
            Log.d("Audio-Mgr", "Write buffer to file: size:${bufInfo.size}, offset:${bufInfo.offset} flag:${bufInfo.flags}")
        }
//        val bufferFormat = encoder.getOutputFormat(bufId) // option A
//        var hdrStr = ""
//        (0 until 7).forEach { i ->
//            hdrStr += " " + String.format("%02x", mOutputByteArray!![i])
//        }
//        Log.v("Audio-Mgr", "ADTS Header: $hdrStr")

        outputBuffer.clear()
        encoder.releaseOutputBuffer(bufId, false)
    }

    override fun onOutputFormatChanged(c: MediaCodec, format: MediaFormat) {
        Log.d("Audio-Mgr", "output format changed: $format")
    }

    override fun onError(c: MediaCodec, e: MediaCodec.CodecException) {
        Log.d("Audio-Mgr", "Got decoder exception: $e")
    }
}