//
//  ClickySubprocess.swift
//  ClickyFoundation
//
//  Safe asynchronous process execution utility (Anti-Hang & Anti-Watchdog)
//

import Foundation

public enum ClickySubprocess {
    public static func runAsync(executable: String, arguments: [String], timeoutSeconds: TimeInterval = 4.0) async -> (exitCode: Int32, output: String) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments
                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                var hasResumed = false
                let lock = NSLock()

                let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInitiated))
                timer.schedule(deadline: .now() + timeoutSeconds)
                timer.setEventHandler {
                    lock.lock()
                    defer { lock.unlock() }
                    if !hasResumed {
                        hasResumed = true
                        if process.isRunning {
                            process.terminate()
                        }
                        continuation.resume(returning: (-1, "TIMEOUT"))
                    }
                }
                timer.resume()

                do {
                    try process.run()
                    process.waitUntilExit()
                    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    let outStr = String(data: outData, encoding: .utf8) ?? ""
                    let errStr = String(data: errData, encoding: .utf8) ?? ""
                    let combined = outStr + (errStr.isEmpty ? "" : " [stderr: \(errStr)]")

                    lock.lock()
                    defer { lock.unlock() }
                    if !hasResumed {
                        hasResumed = true
                        timer.cancel()
                        continuation.resume(returning: (process.terminationStatus, combined))
                    }
                } catch {
                    lock.lock()
                    defer { lock.unlock() }
                    if !hasResumed {
                        hasResumed = true
                        timer.cancel()
                        continuation.resume(returning: (-1, "EXEC_FAILED: \(error.localizedDescription)"))
                    }
                }
            }
        }
    }
}
