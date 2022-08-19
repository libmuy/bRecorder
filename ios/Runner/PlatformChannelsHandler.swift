//
//  PlatformChannelHandler.swift
//
//  Created by Jinaing Bi on R 4/08/14.
//

import Foundation
import Flutter
import UIKit


class PlatformChannelsHandler {
    var mEventListener: EventChannelListener? = nil
    var mEventSink: FlutterEventSink? = nil
    var mAudioManager: AudioManager? = nil
    
    
    /*======================================================================================================*\
     Initializing
     \*======================================================================================================*/
    func initialize(window: UIWindow?) {
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        let methodChannel = FlutterMethodChannel(name: "libmuy.com/brecorder/methodchannel",
                                                 binaryMessenger: controller.binaryMessenger)
        let eventChannel = FlutterEventChannel(name: "libmuy.com/brecorder/eventchannel",
                                               binaryMessenger: controller.binaryMessenger)
        self.mEventListener = EventChannelListener(platformChannelsHandler:  self)
        eventChannel.setStreamHandler(self.mEventListener)
        
        methodChannel.setMethodCallHandler({
            (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            self.onMethodCall(call: call, result: result)
        })
        
    }
    
    
    /*======================================================================================================*\
     Method Channel Handling
     \*======================================================================================================*/
    private func endCallWithResult<T>(result: @escaping FlutterResult, ret: AudioResult<T>) {
        if (ret.isOK()) {
            result(ret.value)
        } else {
            result(FlutterError(
                code:"",
                message: ret.error,
                details: nil
            ))
        }
    }
    
    private func endCallWithParamError(result: @escaping FlutterResult, message: String) {
        endCallWithResult(result: result, ret: AudioResult<NoValue>(type: AudioResultType.ParamError, extraString: message))
    }
    
    private func unwrapParamNumber(result: @escaping FlutterResult, args: Any?, name: String) -> NSNumber? {
        guard let argsDictionary = args as? Dictionary<String, Any> else {
            endCallWithParamError(result: result, message: "arguments is not Dictionary")
            return nil
        }
        guard let value = argsDictionary[name] as? NSNumber else {
            endCallWithParamError(result: result, message: "param (\(name)) is NULL")
            return nil
        }
        
        return value
    }
    private func unwrapParamInt(result: @escaping FlutterResult, args: Any?, name: String) -> Int? {
        guard let value = unwrapParamNumber(result: result, args: args, name: name) else {
            return nil
        }
        
        return value.intValue
    }
    private func unwrapParamBool(result: @escaping FlutterResult, args: Any?, name: String) -> Bool? {
        guard let value = unwrapParamNumber(result: result, args: args, name: name) else {
            return nil
        }
        
        return value.boolValue
    }
    private func unwrapParamDouble(result: @escaping FlutterResult, args: Any?, name: String) -> Double? {
        guard let value = unwrapParamNumber(result: result, args: args, name: name) else {
            return nil
        }
        
        return value.doubleValue
    }
    private func unwrapParamString(result: @escaping FlutterResult, args: Any?, name: String) -> String? {
        guard let argsDictionary = args as? Dictionary<String, Any> else {
            endCallWithParamError(result: result, message: "arguments is not Dictionary")
            return nil
        }
        guard let value = argsDictionary[name] as? String else {
            endCallWithParamError(result: result, message: "param (\(name)) is NULL")
            return nil
        }
        
        return value
    }
    
    func onMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
            /*=======================================================================*\
             Recording
             \*=======================================================================*/
        case "startRecord":
            guard let path: String = unwrapParamString(result: result, args: call.arguments, name: "path") else {return}
            guard let ret = mAudioManager?.startRecord(path: path) else {
                endCallWithParamError(result: result, message: "AudioManager not initialized?")
                return
            }
            endCallWithResult(result: result, ret: ret)
            
        case "stopRecord":
            guard let ret = mAudioManager?.stopRecord() else {
                endCallWithParamError(result: result, message: "AudioManager not initialized?")
                return
            }
            endCallWithResult(result: result, ret: ret)
            
        case "pauseRecord":
            guard let ret = mAudioManager?.pauseRecord() else {
                endCallWithParamError(result: result, message: "AudioManager not initialized?")
                return
            }
            endCallWithResult(result: result, ret: ret)
            
        case "resumeRecord":
            guard let ret = mAudioManager?.resumeRecord() else {
                endCallWithParamError(result: result, message: "AudioManager not initialized?")
                return
            }
            endCallWithResult(result: result, ret: ret)
            
            
            /*=======================================================================*\
             Playing
             \*=======================================================================*/
        case "startPlay":
            guard let path: String = unwrapParamString(result: result, args: call.arguments, name: "path") else {return}
            guard let ret = mAudioManager?.startPlay(path: path) else {
                endCallWithParamError(result: result, message: "AudioManager not initialized?")
                return
            }
            endCallWithResult(result: result, ret: ret)
            
        case "stopPlay":
            guard let ret = mAudioManager?.stopPlay() else {
                endCallWithParamError(result: result, message: "AudioManager not initialized?")
                return
            }
            endCallWithResult(result: result, ret: ret)
            
        case "pausePlay":
            guard let ret = mAudioManager?.pausePlay() else {
                endCallWithParamError(result: result, message: "AudioManager not initialized?")
                return
            }
            endCallWithResult(result: result, ret: ret)
            
        case "resumePlay":
            guard let ret = mAudioManager?.resumePlay() else {
                endCallWithParamError(result: result, message: "AudioManager not initialized?")
                return
            }
            endCallWithResult(result: result, ret: ret)
            
        case "seekTo":
            guard let timeMs: Int = unwrapParamInt(result: result, args: call.arguments, name: "position") else {return}
//            guard let sync: Bool = unwrapParamBool(result: result, args: call.arguments, name: "sync") else {return}
            guard let ret = mAudioManager?.seekTo(timeMs: timeMs) else {
                endCallWithParamError(result: result, message: "AudioManager not initialized?")
                return
            }
            endCallWithResult(result: result, ret: ret)
            
            //            if (sync!!) {
            //                audioManager!!.seekTo(position!!) {
            //                    endCallWithResult(result, AudioResult<NoValue>(AudioErrorInfo.OK))
            //                }
            //            } else {
            //                let ret = audioManager!!.seekTo(position!!, null)
            //                endCallWithResult(result, ret)
            //            }
            
        case "setPitch":
            guard let pitch: Double = unwrapParamDouble(result: result, args: call.arguments, name: "pitch") else {return}
            guard let ret = mAudioManager?.setPitch(pitch: pitch) else {
                endCallWithParamError(result: result, message: "AudioManager not initialized?")
                return
            }
            endCallWithResult(result: result, ret: ret)
            
        case "setSpeed":
            guard let speed: Double = unwrapParamDouble(result: result, args: call.arguments, name: "speed") else {return}
            guard let ret = mAudioManager?.setSpeed(speed: speed) else {
                endCallWithParamError(result: result, message: "AudioManager not initialized?")
                return
            }
            endCallWithResult(result: result, ret: ret)
            
        case "setVolume":
            guard let volume: Double = unwrapParamDouble(result: result, args: call.arguments, name: "volume") else {return}
            guard let ret = mAudioManager?.setVolume(volume: volume) else {
                endCallWithParamError(result: result, message: "AudioManager not initialized?")
                return
            }
            endCallWithResult(result: result, ret: ret)
            
            /*=======================================================================*\
             Other
             \*=======================================================================*/
        case "getDuration":
            guard let path: String = unwrapParamString(result: result, args: call.arguments, name: "path") else {return}
            guard let ret = mAudioManager?.getDuration(path: path) else {
                endCallWithParamError(result: result, message: "AudioManager not initialized?")
                return
            }
            endCallWithResult(result: result, ret: ret)
            
        case "setParams":
            guard let samplesPerSecond = unwrapParamInt(result: result, args: call.arguments, name: "samplesPerSecond") else {return}
            WAVEFORM_SAMPLES_PER_SECOND = samplesPerSecond
            guard let sendPerSecond = unwrapParamInt(result: result, args: call.arguments, name: "sendPerSecond") else {return}
            WAVEFORM_SEND_PER_SECOND = sendPerSecond
            guard let recordFormat = unwrapParamString(result: result, args: call.arguments, name: "recordFormat") else {return}
            RECORD_FORMAT = recordFormat
            guard let recordChannelCount = unwrapParamInt(result: result, args: call.arguments, name: "recordChannelCount") else {return}
            RECORD_CHANNEL_COUNT = recordChannelCount
            guard let recordSampleRate = unwrapParamInt(result: result, args: call.arguments, name: "recordSampleRate") else {return}
            RECORD_SAMPLE_RATE = recordSampleRate
            guard let recordBitRate = unwrapParamInt(result: result, args: call.arguments, name: "recordBitRate") else {return}
            RECORD_BIT_RATE = recordBitRate
            guard let recordFrameReadPerSecond = unwrapParamInt(result: result, args: call.arguments, name: "recordFrameReadPerSecond") else {return}
            RECORD_FRAME_READ_PER_SECOND = recordFrameReadPerSecond
            guard let playbackPositionNotifyIntervalMS = unwrapParamInt(result: result, args: call.arguments, name: "playbackPositionNotifyIntervalMS") else {return}
            PLAYBACK_POSITION_NOTIFY_INTERVAL_MS = playbackPositionNotifyIntervalMS

            
            mAudioManager = AudioManager(eventChannel: self)
            endCallWithResult(result: result, ret: AudioResult<NoValue>(type: AudioResultType.OK))
            

            /*=======================================================================*\
             For Debugging
             \*=======================================================================*/
            
        case "test":
            guard let name: String = unwrapParamString(result: result, args: call.arguments, name: "name") else {return}
            
            result("\(name) says hello")
//            var floatArray: [Float32] = [0.1, 0.2, 0.3];
//            sendEvent(data: [
//                "testEvent": FlutterStandardTypedData(float32: Data(buffer: UnsafeBufferPointer(start: &floatArray, count: 3)))
//            ])
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    
    
    /*======================================================================================================*\
     Event Channel Handling
     \*======================================================================================================*/
    func sendEvent(data: [String: Any]) {
        mEventSink?(data)
    }
    class EventChannelListener:NSObject, FlutterStreamHandler {
        let platformChannelsHandler: PlatformChannelsHandler?
        
        init(platformChannelsHandler: PlatformChannelsHandler?) {
            self.platformChannelsHandler = platformChannelsHandler
        }
        
        //Event Channel Handler
        func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
            self.platformChannelsHandler?.mEventSink = events
            return nil
        }
        
        func onCancel(withArguments arguments: Any?) -> FlutterError? {
            return nil
        }
    }
}


