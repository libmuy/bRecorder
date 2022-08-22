//
//  Recorder.swift
//  Runner
//
//  Created by Jinaing Bi on R 4/08/15.
//

import Foundation
import AVFoundation

private let log = Logger(name: "Recorder")

class Recorder {
    private let mAudioEngine = AVAudioEngine()
    private let mInputNode: AVAudioInputNode
    private let mInputFormat: AVAudioFormat
    private let mConverter: AVAudioConverter
    private let mWaveformGenerator: WaveformGenerator
    private var mOutputFile: AVAudioFile? = nil
    private let mPcmFormat: AVAudioFormat
    private var samples = 0
    
    init(channelHandler: PlatformChannelsHandler) {
        let session = AVAudioSession.sharedInstance()
        try! session.setCategory(.playAndRecord, options: .defaultToSpeaker)
        try! session.overrideOutputAudioPort(AVAudioSession.PortOverride.none)

        mInputNode = mAudioEngine.inputNode
        mInputFormat = mInputNode.outputFormat(forBus: 0)
        mWaveformGenerator = WaveformGenerator(sendWaveform: {
            data in
            channelHandler.sendEvent(data: ["waveform": data])
        })
        mPcmFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                   sampleRate: Double(RECORD_SAMPLE_RATE),
                                   channels: AVAudioChannelCount(RECORD_CHANNEL_COUNT), interleaved: false)!
        mConverter = AVAudioConverter(from:mInputFormat, to: mPcmFormat)!
        setupPermission()
    }
    
    
    /*======================================================================================================*\
     Public Methods
    \*======================================================================================================*/
    func startRecord(path : String)-> AudioResult<NoValue> {
        //Create Output File
        guard let url: URL = URL(string: path) else {
            return errorResult("Path parse Error")
        }
        do {
            self.mOutputFile = try AVAudioFile(forWriting: url, settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: RECORD_SAMPLE_RATE,
                AVNumberOfChannelsKey: RECORD_CHANNEL_COUNT
            ])
        } catch let error {
            return errorResult("Create File Failed:\(error)")
        }
        
        // Setup Audio Session
        do {
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        } catch let error {
            return errorResult("Start Record: Setup Session: \(error)")
        }
        
        self.mWaveformGenerator.start(sampleRate: Int(mPcmFormat.sampleRate))
        mAudioEngine.prepare()
        samples = 0
        //            log.debug("Read frame count:\(RECORDER_READ_FRAME_COUNT)")
        let bufferSize =  AVAudioFrameCount(mInputFormat.sampleRate / Double(RECORD_FRAME_READ_PER_SECOND))
        let samplerate2 = mInputNode.outputFormat(forBus: 0).sampleRate
        log.debug("inputformat samplerate: \(mInputFormat.sampleRate), sample rate2: \(samplerate2)")
        mInputNode.installTap(onBus: 0,
                             bufferSize: bufferSize,
                             format: mInputFormat,
                             block: { (buffer, time) in
            
            guard let pcmBuffer = self.convertPcm(inputBuffer: buffer) else {
                return
            }
            
            self.samples += Int(pcmBuffer.frameLength)
//                log.debug("new buffer, samples\(self.samples), len:\(pcmBuffer.frameLength), origin len:\(buffer.frameLength)")
            try! self.mOutputFile?.write(from: pcmBuffer)
            let floatPtr = pcmBuffer.floatChannelData!.pointee
            self.mWaveformGenerator.feedPCMFloat(floatBuffer: floatPtr, sampleSize: Int(pcmBuffer.frameLength))
        })

        do {
            try mAudioEngine.start()
        } catch let error {
            return errorResult("Start Record: Got Exception \(error)")
        }
        return AudioResult(type: .OK)
    }
    
    func stopRecord()-> AudioResult<NoValue>{
        do {
            mInputNode.removeTap(onBus: 0)
            log.debug("file len: \(mOutputFile!.length), buffer len:\(samples)")
            self.mOutputFile = nil
            mAudioEngine.stop()
            mWaveformGenerator.stop()
            try AVAudioSession.sharedInstance().setActive(false)
        } catch let error {
            return errorResult("Stop Record: Got Exception \(error)")
        }
        return AudioResult(type: .OK)
    }
    
    func pauseRecord()-> AudioResult<NoValue>{
        mAudioEngine.pause()
        return AudioResult(type: .OK)
    }
    
    func resumeRecord()-> AudioResult<NoValue>{
        do {
            try mAudioEngine.start()
        } catch let error {
            return errorResult("Resume Record: Got Exception \(error)")
        }
        return AudioResult(type: .OK)
    }
    
    /*======================================================================================================*\
     Private Methods
    \*======================================================================================================*/
    /// Rusult value helper
    private func errorResult(result: AudioResultType = .NG, _ message: String) -> AudioResult<NoValue> {
        return AudioResult(type: result, extraString: message)
    }
    
    /// Convert PCM Buffer format to [mPcmFormat]
    private func convertPcm(inputBuffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        var error: NSError? = nil
        
        let pcmBuffer = AVAudioPCMBuffer(
            pcmFormat: mPcmFormat,
            frameCapacity: AVAudioFrameCount(mPcmFormat.sampleRate) *
            inputBuffer.frameLength / AVAudioFrameCount(inputBuffer.format.sampleRate))
        
        mConverter.convert(to: pcmBuffer!,
                           error: &error,
                           withInputFrom: {inNumPackets, outStatus in
            outStatus.pointee = AVAudioConverterInputStatus.haveData
            return inputBuffer
        })
        
        if error != nil {
            print(error!.localizedDescription)
            return nil
        }

        return pcmBuffer
    }
    
    /// Setup permission
    private func setupPermission() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            print("Permission granted")
        case .denied:
            print("Permission denied")
        case .undetermined:
            print("Request permission here")
            AVAudioSession.sharedInstance().requestRecordPermission({ granted in
                // Handle granted
            })
        @unknown default:
            print("Unknown case")
        }
    }
    
}
