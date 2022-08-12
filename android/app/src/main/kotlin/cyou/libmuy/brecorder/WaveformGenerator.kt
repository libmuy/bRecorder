package cyou.libmuy.brecorder

import android.os.Handler
import android.os.Looper
import android.util.Log
import java.nio.ByteBuffer
import kotlin.math.abs
import kotlin.math.max
import java.math.RoundingMode
import java.text.DecimalFormat
class WaveformGenerator(waveformOutputCallback: (waveformData: FloatArray) -> Unit) {
    private val sendWaveform = waveformOutputCallback
    private var count = 0
    private var max = Short.MIN_VALUE
    private var min = Short.MAX_VALUE
    private var dataIndex = 0
    private val maxShortFloat = Short.MAX_VALUE.toFloat()
    private var eventData: FloatArray? = null
    private var bigDebugStr: String = ""
    private var smallDebugStr: String = ""
    private var sampleDebugStr: String = ""
    private var allZeroFlag: Boolean = true

    fun feedPCM(inputBuffer: ByteBuffer, sampleSize: Int, waveSampleRate: Int, waveSendRate: Int) {
        val samplePerPixel = SAMPLE_RATE / waveSampleRate
        val sendSize = SAMPLE_RATE / waveSampleRate / samplePerPixel

        var big: Float
        var small: Float

        if (samplePerPixel <= 0) return
        if (sampleSize <= 0) return

        if (eventData == null) {
            eventData = FloatArray(sendSize)
        }

        inputBuffer.position(0)
        inputBuffer.limit(sampleSize)

//        val df = DecimalFormat("##.####")
//        df.roundingMode = RoundingMode.DOWN

        val shorBuffer = inputBuffer.asShortBuffer()
        (0 until (sampleSize / 2)).forEach { i ->
            val sample = shorBuffer.get(i)
            if (sample > max) max = sample
            if (sample < min) min = sample

//            sampleDebugStr = "$sampleDebugStr, ${df.format(sample)}"
//            if (sample.toInt() != 0) allZeroFlag = false

            if (++count == samplePerPixel) {
                big = max.toFloat() / maxShortFloat
                small = min.toFloat() / maxShortFloat
//
//                bigDebugStr = "$bigDebugStr, ${df.format(big)}"
//                smallDebugStr = "$smallDebugStr, ${df.format(small)}"

//                val center = abs((big - small) / 2)
//                val amplitude = max(abs(big), abs(small))
//                if (center / amplitude < 0.5) {
//                    big = center * 2
//                    small = big * -1
//                }
//                //big and small are same side
//                if (big * small > 0) {
//                    big = (big - small)
//                    small = big
//
//                    if (small > 0) small *= -1
//                    if (big < 0) big *= -1
//                }
//                eventData!![dataIndex++] = big
                eventData!![dataIndex++] = (big - small) / 2

                //reset
                max = Short.MIN_VALUE
                min = Short.MAX_VALUE
                count = 0

//        Log.d("Audio-Mgr", "Android send: $eventData")
                if (dataIndex >= sendSize) {
//            Log.d("WAVEFORM", "bigs: $bigDebugStr")
//            Log.d("WAVEFORM", "smalls: $smallDebugStr")
//            if (allZeroFlag)
//                Log.d("WAVEFORM", "samples: ALL ZERRO")
//            else
//                Log.d("WAVEFORM", "samples: $sampleDebugStr")
//            allZeroFlag = true
//            bigDebugStr = ""
//            smallDebugStr = ""
                    Handler(Looper.getMainLooper()).post {
                        sendWaveform(eventData!!)
                    }
                    dataIndex = 0
                }
            }
        }
    }
}