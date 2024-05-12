//
//  Utils.swift
//  Runner
//
//  Created by Jinaing Bi on R 4/08/14.
//

import Foundation

var WAVEFORM_SAMPLES_PER_SECOND = 0
var WAVEFORM_SEND_PER_SECOND = 0
var RECORD_FORMAT = ""
var RECORD_CHANNEL_COUNT = 1
var RECORD_SAMPLE_RATE = 44100
var RECORD_BIT_RATE = 64000
var RECORD_FRAME_READ_PER_SECOND = 50
var PLAYBACK_POSITION_NOTIFY_INTERVAL_MS = 10



enum AudioState {
    case Playing, PlayPaused, Recording, RecordPaused, Idle
}

enum AudioResultType: String {
    case OK = "OK"
    case NG = "NG"
    case StateErrNotRecording = "State Error: Not recording"
    case StateErrNotPlaying = "State Error: Not playing"
    case StateErrNotIdle = "State Error: Not idle"
    case NoPermission = "No Permission"
    case FileNotFound = "File Not Found"
    case ParamError = "Parameter Error"
}

class AudioResult <Result> {
    private let type: AudioResultType
    var value: Result? = nil
    private var extraString: String = ""

//    init(error: AudioErrorInfo, result: Result? = nil) {
//        self.errorInfo = error
//        self.result = result
//    }
    
//    init(error: AudioErrorInfo, result: Result) {
//        self.errorInfo = error
//        self.result = result
//    }
    
    init(type: AudioResultType, value: Result? = nil, extraString: String = "") {
        self.type = type
        self.value = value
        self.extraString = extraString
    }
    
    var error: String {
        get {
            if (extraString == "") {
                return type	.rawValue
            }
            return type.rawValue + extraString
        }
    }
    
    func isOK() -> Bool {
        return type == AudioResultType.OK
    }
}

class NoValue{}



private let LOG_LINENO_LEN = 5
private let LOG_NAME_LEN = 10
private let LOG_FUN_LEN = 60

//
//class Logger {
//    private let name: String
//    private let showFileName: Bool
//    private let nameWithPadding: String
//    
//    init(name:String, showFileName: Bool = false) {
//        self.name = name
//        self.nameWithPadding = name.padding(toLength: LOG_NAME_LEN, withPad: " ", startingAt: 0)
//        self.showFileName = showFileName
//    }
//    
//    public func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line ) {
//        let lineWithPadding = String(line).leftPadding(toLength: LOG_LINENO_LEN, withPad: "0")
//        let funWithPadding = function.padding(toLength: LOG_FUN_LEN, withPad: " ", startingAt: 0)
//        print("[L\(lineWithPadding)][\(nameWithPadding)] [\(funWithPadding)] \(message)")
//    }
//}

extension String {
    func leftPadding(toLength: Int, withPad character: Character) -> String {
        let stringLength = self.count
        if stringLength < toLength {
            return String(repeatElement(character, count: toLength - stringLength)) + self
        } else {
            return String(self.suffix(toLength))
        }
    }
}
