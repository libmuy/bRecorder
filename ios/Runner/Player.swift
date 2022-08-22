//
//  Player.swift
//  Runner
//
//  Created by Jinaing Bi on R 4/08/15.
//

import Foundation
import AVFoundation

private let log = Logger(name: "Player")

private enum PlayerState {
    case playing
    case stopped
    case paused
}

class Player {
    private let mEngine = AVAudioEngine()
    private let mSpeedControl = AVAudioUnitVarispeed()
    private let mPitchControl = AVAudioUnitTimePitch()
    private let mAudioPlayer = AVAudioPlayerNode()
    private let mEventChannel: PlatformChannelsHandler
    private var mStartFrame: Int64 = 0
    private var mTotalFrame: Int64 = 0
    private var mSampleRate: Double = 0
    private var mFile: AVAudioFile?
    private var mDuration: Double = 0.0
    private var onPlaybackComplete: (() -> Void)?
    private var mPositionNotifyTimer: Timer?
    private var mPendingSeek = false
    private var mState = PlayerState.stopped
    private var mNotFinalize = false
    
    init(channelHandler: PlatformChannelsHandler) {
        mEventChannel = channelHandler
        
        mEngine.attach(mAudioPlayer)
        mEngine.attach(mPitchControl)
        mEngine.attach(mSpeedControl)
        
        // 4: arrange the parts so that output from one is input to another
        mEngine.connect(mAudioPlayer, to: mSpeedControl, format: nil)
        mEngine.connect(mSpeedControl, to: mPitchControl, format: nil)
        mEngine.connect(mPitchControl, to: mEngine.mainMixerNode, format: nil)
    }
    
    private func sendEvent(event: Dictionary<String, Any?>) {
        mEventChannel.sendEvent(data: [
            "playEvent": event
        ])
    }
    
    private func errorResult(result: AudioResultType = .NG, _ message: String) -> AudioResult<NoValue> {
        mState = .stopped
        return AudioResult(type: result, extraString: message)
    }
    
    private func startPositionNotifyTimer() {
        mPositionNotifyTimer = Timer.scheduledTimer(
            withTimeInterval: Double(PLAYBACK_POSITION_NOTIFY_INTERVAL_MS) / 1000,
            repeats: true) { _ in
                if (self.mState != .playing) {
                    return
                }
                let time = self.currentTimeMs
                if (time <= 0 || time > Int(self.mDuration * 1000)) {
                    return
                }
                DispatchQueue.main.async {
                    self.sendEvent(event: [
                        "event": "PositionUpdate",
                        "data": time,
                    ])
                }
            }
    }
    
    func startPlay(path: String, fromTimeMs: Int = 0, onComplete: @escaping () -> Void)-> AudioResult<NoValue> {
        log.debug("startPlay")
        try? AVAudioSession.sharedInstance().overrideOutputAudioPort(AVAudioSession.PortOverride.speaker)

        guard let url: URL = URL(string: path) else {
            return errorResult("Path parse Error")
        }
        
        do {
            mFile = try AVAudioFile(forReading: url)
        } catch let error {
            return errorResult("Start Play: Create File Failed:\(error)")
        }
        
        mTotalFrame = mFile!.length
        mSampleRate = mFile!.processingFormat.sampleRate
        mDuration = Double(mTotalFrame) / mSampleRate
        log.debug("Audio File: frames:\(mFile!.length), samplerate:\(mFile!.processingFormat.sampleRate), duration:\(mDuration)")
        onPlaybackComplete = onComplete
        startPositionNotifyTimer()
        if (fromTimeMs > 0) {
            mStartFrame = timeMsToFrame(fromTimeMs)
        }

        do {
            try play(fromFrame: mStartFrame)
        } catch let error {
            return errorResult("Start Play: Got Exception \(error)")
        }
        
        return AudioResult(type: .OK)
    }
    
    func stopPlay()-> AudioResult<NoValue> {
        stop()
        return AudioResult(type: .OK)
    }
    
    func pausePlay()-> AudioResult<NoValue> {
        mAudioPlayer.pause()
        mEngine.pause()
        mState = .paused
        return AudioResult(type: .OK)
    }
    
    func resumePlay()-> AudioResult<NoValue> {
        do{
            if (mPendingSeek) {
                stop(temporarily: true)
                try play(fromFrame: mStartFrame)
            } else {
                try mEngine.start()
                mAudioPlayer.play()
            }
        } catch let error {
            return errorResult("Resume Play: Got Exception \(error)")
        }
        mState = .playing
        return AudioResult(type: .OK)
    }
    
    private func playbackComplete() {
        if (mNotFinalize) {
            log.debug("playback completed but not finalize")
            mNotFinalize = false
            return
        }
        log.debug("playback completed")
        mPositionNotifyTimer!.invalidate()
        onPlaybackComplete?()
        mAudioPlayer.stop()
        mEngine.stop()
        mEngine.reset()
        onPlaybackComplete = nil
        mFile = nil
        mPositionNotifyTimer = nil
        mPendingSeek = false
        mState = .stopped
        sendEvent(event: [
            "event": "PlayComplete",
            "data": nil
        ])
    }
    
    private func timeMsToFrame(_ timeMs: Int) -> Int64 {
        let seconds = Double(timeMs) / 1000
        let frame = Int64(mSampleRate * seconds)
        return frame
    }
    private func play(fromFrame: Int64) throws{
        let framesToPlay = mTotalFrame - fromFrame
        log.debug("play startFrame:\(fromFrame), frameCount:\(framesToPlay)")
        if (framesToPlay < 100) {
            log.debug("remain:\(framesToPlay) too few, return")
        }
        mAudioPlayer.scheduleSegment(
            mFile!,
            startingFrame: fromFrame,
            frameCount: AVAudioFrameCount(framesToPlay),
            at: nil,
            completionCallbackType: .dataPlayedBack,
            completionHandler: {_ in
                DispatchQueue.main.async {
                    self.playbackComplete()
                }
            }
        )
        try mEngine.start()
        mAudioPlayer.play()
        mPendingSeek = false
        mState = .playing
    }
    
    private func stop(temporarily: Bool = false) {
        //playbackComplete() will be called after this
        if (temporarily) {
            mNotFinalize = true
            mAudioPlayer.stop()
        } else {
            mAudioPlayer.stop()
            mEngine.stop()
            mState = .stopped
        }
    }
    
    private var currentTimeMs: Int {
        get {
            guard let nodeTime = mAudioPlayer.lastRenderTime else {
                return 0
            }
            guard let playerTime = mAudioPlayer.playerTime(forNodeTime: nodeTime) else {
                return 0
            }
            let second = Double(playerTime.sampleTime + mStartFrame) / playerTime.sampleRate
            return Int(second * 1000)
        }
    }

    
    func seekTo(timeMs: Int)-> AudioResult<NoValue> {
        mStartFrame = timeMsToFrame(timeMs)
        if (mState == .playing) {
            log.debug("seek to \(timeMs) ms")
            stop(temporarily: true)
            do {
                try play(fromFrame: mStartFrame)
            } catch let error {
                return errorResult("Seek: Got Exception \(error)")
            }
        } else {
            mPendingSeek = true
        }
        
        return AudioResult(type: .OK)
    }
    
    func setPitch(pitch: Double)-> AudioResult<NoValue> {
        log.debug("set pitch to:\(pitch)")
        mPitchControl.pitch = Float(pitch)
        return AudioResult(type: .OK)
    }
    
    
    func setSpeed(speed: Double)-> AudioResult<NoValue> {
        log.debug("set speed to:\(speed)")
//        mSpeedControl.rate = Float(speed)
        mPitchControl.rate = Float(speed)
        return AudioResult(type: .OK)
    }
    
    func setVolume(volume: Double)-> AudioResult<NoValue> {
        log.debug("set speed to:\(volume)")
        mAudioPlayer.volume = Float(volume)
        return AudioResult(type: .OK)
    }
}

