//
//  WaveformGenerator.swift
//  Runner
//
//  Created by Jinaing Bi on R 4/08/16.
//

import Foundation

private let log = Logger(name: "WAVEFORM")

class WaveformGenerator {
    private let sendWaveformCallback: (Any) -> Void
    private var count = 0
    private var dataIndex = 0
    private let sendSize = WAVEFORM_SAMPLES_PER_SECOND / WAVEFORM_SEND_PER_SECOND
    private var eventData: UnsafeMutablePointer<Float32>
    
    private var max: Float32 = -2.0
    private var min: Float32 = 2.0
    private var sampleRate: Int?
    var waveformSampleCount = 0
    var frameCount = 0

    init (sendWaveform: @escaping (Any) -> Void) {
        self.sendWaveformCallback = sendWaveform
        self.eventData = UnsafeMutablePointer<Float32>.allocate(capacity: sendSize)
    }
    
    func start(sampleRate: Int) {
        self.sampleRate = sampleRate
        dataIndex = 0
        waveformSampleCount = 0
        frameCount = 0
        max = -2.0
        min = 2.0
    }
    
    func stop() {
        if (dataIndex > 0) {
            sendWaveform()
        }
        let duration1 = Double(waveformSampleCount) / Double(WAVEFORM_SAMPLES_PER_SECOND)
        let duration2 = Double(frameCount) / Double(sampleRate!)
        log.debug("samplerate:\(sampleRate!)")
        log.debug("sent \(waveformSampleCount) samples, duration:\(duration1)")
        log.debug("sent \(frameCount) frames, duration:\(duration2)")
    }
    private func sendWaveform() {
//        log.debug("send \(dataIndex) samples, total:\(waveformSampleCount)")
        waveformSampleCount += dataIndex
        sendWaveformCallback(
            FlutterStandardTypedData(
                float32: Data(
                    buffer: UnsafeBufferPointer(
                        start: eventData,
                        count: dataIndex
                    )
                )
            )
        )
    }

    func feedPCMFloat(floatBuffer: UnsafePointer<Float32>, sampleSize: Int) {
        let samplePerPixel = sampleRate! / WAVEFORM_SAMPLES_PER_SECOND

        var big: Float32
        var small: Float32
        
        frameCount += sampleSize

        if (samplePerPixel <= 0) {return}
        if (sampleSize <= 0) {return}
//        log.debug("sampleRate:\(sampleRate!), samplePerPixel:\(samplePerPixel), waveSamplePerSecond:\(WAVEFORM_SAMPLES_PER_SECOND)")
        for i in 0..<sampleSize {
            let sample = floatBuffer[i]
            if (sample > max) {max = sample}
            if (sample < min) {min = sample}

//            log.debug("sample: \(sample)")
            count += 1
            if (count == samplePerPixel) {
//                big = Float32(maxFloat) / maxShortFloat
//                small = Float32(minFloat) / maxShortFloat
                big = max
                small = min
                eventData[dataIndex] = (big - small) / 2
                
//                log.debug("big:\(big), small:\(small), send:\(eventData[dataIndex])")
                dataIndex += 1

                //reset
                max = -2.0
                min = 2.0
                count = 0

                if (dataIndex >= sendSize) {
                    sendWaveform()
                    dataIndex = 0
                }
            }
        }
    }
}
