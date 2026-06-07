import Foundation

enum ScriptError: Error, Equatable {
    case compileFailed
    case permissionDenied      // TCC 自动化授权被拒（错误码 -1743）
    case execution(String)
}

protocol ScriptRunning {
    func run(_ source: String) throws -> NSAppleEventDescriptor
}

/// NSAppleScript 非线程安全：调用方保证始终在同一队列上执行（Provider 用专用串行队列）。
final class AppleScriptRunner: ScriptRunning {
    func run(_ source: String) throws -> NSAppleEventDescriptor {
        guard let script = NSAppleScript(source: source) else {
            throw ScriptError.compileFailed
        }
        var errorDict: NSDictionary?
        let result = script.executeAndReturnError(&errorDict)
        if let errorDict {
            let code = errorDict[NSAppleScript.errorNumber] as? Int ?? 0
            if code == -1743 { throw ScriptError.permissionDenied }
            throw ScriptError.execution("\(errorDict)")
        }
        return result
    }
}
