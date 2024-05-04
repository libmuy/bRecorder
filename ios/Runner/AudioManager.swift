//
//  AudioManager.swift
//  Runner
//
//  Created by Jinaing Bi on R 4/08/14.
//

import Foundation
import AVFoundation

fileprivate let log = Logger(name: "Audio-Mgr")

class AudioManager {
    var mState = AudioState.Idle
    let mRecorder: Recorder
    let mPlayer: Player
    
    init (eventChannel: PlatformChannelsHandler) {
        mRecorder = Recorder(channelHandler: eventChannel)
        mPlayer = Player(channelHandler: eventChannel)
        eventChannel.sendEvent(
            data: [
                "platformPametersEvent":[
                    "PLATFORM_PITCH_MAX_VALUE": 2400.0,
                    "PLATFORM_PITCH_MIN_VALUE": -2400.0,
                    "PLATFORM_PITCH_DEFAULT_VALUE": 0.0
                ]
            ]
        )
    }

    
    func getDuration(path: String) async -> AudioResult<Int>{
        var duration: Int = 0
        let url: URL = URL(fileURLWithPath: path)
        
        //check state
        guard mState == AudioState.Idle else {
            return AudioResult(type: .StateErrNotIdle, extraString: "current state:\(self.mState)")
        }

        let start = Date()

        //重い処理を書く

        let audioAsset = AVURLAsset.init(url: url, options: nil)

        log.debug("get duration of: \(url)")
        do {
            let durationTime = try await audioAsset.load(.duration)
            let durationInSeconds = CMTimeGetSeconds(durationTime)
            duration = Int(durationInSeconds * 1000)

            let elapsed = Date().timeIntervalSince(start)
            log.debug("GET DURATION: \(duration), COST TIME:\(elapsed)")
        } catch {
            log.debug("load audio asset error:\(error)!")
            return AudioResult(type: .FileNotFound, extraString: "load audio asset failed!")
        }
        return AudioResult(type: .OK, value:duration)
    }
    
    
    func startRecord(path : String)-> AudioResult<NoValue> {
        log.debug("Record Start")
        //check state
        if (mState != AudioState.Idle) {
            return AudioResult(type: .StateErrNotIdle, extraString: "current state:\(mState)")
        }
        
        let result = mRecorder.startRecord(path: path)
        mState = (result.isOK()) ? AudioState.Recording : AudioState.Idle
        return result
    }
    
    func stopRecord()-> AudioResult<NoValue>{
        log.debug("Record Stop")
        //check state
        if (mState != AudioState.Recording) {
            return AudioResult(type: .StateErrNotRecording, extraString: "current state:\(mState)")
        }
        
        mState = AudioState.Idle
        return mRecorder.stopRecord()
    }
    
    func pauseRecord()-> AudioResult<NoValue>{
        log.debug("Record Pause")
        //check state
        if (mState != AudioState.Recording) {
            return AudioResult(type: .StateErrNotRecording, extraString: "current state:\(mState)")
        }
        
        let result = mRecorder.pauseRecord()
        mState = (result.isOK()) ? AudioState.RecordPaused : AudioState.Idle
        return result
    }
    
    func resumeRecord()-> AudioResult<NoValue>{
        log.debug("Record Resume")
        //check state
        if (mState != AudioState.RecordPaused) {
            return AudioResult(type: .StateErrNotRecording, extraString: "current state:\(mState)")
        }
        
        let result = mRecorder.resumeRecord()
        mState = (result.isOK()) ? AudioState.Recording : AudioState.Idle
        return result
    }
    
    func startPlay(path: String)-> AudioResult<NoValue>{
        log.debug("Play Start")
        //check state
        if (mState != AudioState.Idle) {
            return AudioResult(type: .StateErrNotIdle, extraString: "current state:\(mState)")
        }
        
        let result = mPlayer.startPlay(path: path, onComplete: {
            log.debug("playback complete")
            self.mState = AudioState.Idle
        })
        mState = (result.isOK()) ? AudioState.Playing : AudioState.Idle
        return result
    }
    
    func stopPlay()-> AudioResult<NoValue>{
        log.debug("Play Stop")
        //check state
        if (mState != AudioState.Playing && mState != AudioState.PlayPaused) {
            return AudioResult(type: .StateErrNotPlaying, extraString: "current state:\(mState)")
        }
        
        mState = AudioState.Idle
        return mPlayer.stopPlay()
    }
    
    func pausePlay()-> AudioResult<NoValue>{
        log.debug("Play Pause")
        //check state
        if (mState != AudioState.Playing) {
            return AudioResult(type: .StateErrNotPlaying, extraString: "current state:\(mState)")
        }
        
        let result = mPlayer.pausePlay()
        mState = (result.isOK()) ? AudioState.PlayPaused : AudioState.Idle
        return result
    }
    
    func resumePlay()-> AudioResult<NoValue>{
        log.debug("Play Resume")
        //check state
        if (mState != AudioState.PlayPaused) {
            return AudioResult(type: .StateErrNotPlaying, extraString: "current state:\(mState)")
        }
        
        let result = mPlayer.resumePlay()
        mState = (result.isOK()) ? AudioState.Playing : AudioState.Idle
        return result
    }
    
    func seekTo(timeMs: Int)-> AudioResult<NoValue>{
        log.debug("Play Seek")
        //No state check, set the next play position when not playing
        let result = mPlayer.seekTo(timeMs: timeMs)
        if (!result.isOK()) {mState = AudioState.Idle}
        return result
    }
    
    func setPitch(pitch: Double)-> AudioResult<NoValue>{
        log.debug("Play Set Pitch")
        //check state
//        if (mState != AudioState.Playing && mState != AudioState.PlayPaused) {
//            return AudioResult(type: .StateErrNotPlaying, extraString: "current state:\(mState)")
//        }
        
        let result = mPlayer.setPitch(pitch: pitch)
        if (!result.isOK()) {mState = AudioState.Idle}
        return result
    }
    
    
    func setSpeed(speed: Double)-> AudioResult<NoValue>{
        log.debug("Play Set Speed")
        //check state
//        if (mState != AudioState.Playing && mState != AudioState.PlayPaused) {
//            return AudioResult(type: .StateErrNotPlaying, extraString: "current state:\(mState)")
//        }
        
        let result = mPlayer.setSpeed(speed: speed)
        if (!result.isOK()) {mState = AudioState.Idle}
        return result
    }
    
    func setVolume(volume: Double)-> AudioResult<NoValue>{
        log.debug("Play Set Volume")
        //check state
//        if (mState != AudioState.Playing && mState != AudioState.PlayPaused) {
//            return AudioResult(type: .StateErrNotPlaying, extraString: "current state:\(mState)")
//        }
        
        let result = mPlayer.setVolume(volume: volume)
        if (!result.isOK()) {mState = AudioState.Idle}
        return result
    }
    
}


