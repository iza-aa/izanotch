import AppKit
import Foundation
import Vision

@main
struct ProbeCuaDriverTV {
    static func main() async {
        print("==================================================================")
        print("🧪 PROBING CUA-DRIVER EMBEDDED DAEMON FOR TRADINGVIEW")
        print("==================================================================")

        let client = CuaDriverClient.shared
        print("1. Checking binary path: \(client.binaryPath ?? "nil")")
        guard client.isAvailable else {
            print("❌ cua-driver binary not available")
            exit(1)
        }

        do {
            print("2. Listing windows via cua-driver...")
            let windows = try await client.listWindows()
            print("Found \(windows.count) windows.")
            let tvWindows = windows.filter { $0.appName.contains("TradingView") }
            print("TradingView windows: \(tvWindows.count)")
            for w in tvWindows {
                print("  - ID: \(w.windowId), PID: \(w.pid), Title: '\(w.title)', Bounds: \(w.bounds), OnScreen: \(w.isOnScreen)")
            }

            guard let tv = tvWindows.first(where: { $0.isOnScreen && $0.bounds.width >= 600 }) else {
                print("⚠️ No large on-screen TradingView window found.")
                return
            }

            print("3. Getting window state with screenshot_out_file for TradingView...")
            let shotPath = "/tmp/tv_snapshot_probe.png"
            let res = try await client.executeTool(name: "get_window_state", arguments: [
                "pid": tv.pid,
                "window_id": tv.windowId,
                "screenshot_out_file": shotPath,
                "session": CuaDriverClient.defaultSession
            ])
            print("Tool response keys: \(res.keys.joined(separator: ", "))")
            if let sc = res["structuredContent"] as? [String: Any] {
                print("Screenshot width: \(sc["screenshot_width"] ?? "?")")
                print("Screenshot height: \(sc["screenshot_height"] ?? "?")")
                print("Screenshot scale: \(sc["screenshot_scale"] ?? "?")")
                print("Window bounds: \(sc["window_bounds"] ?? "?")")
            }
            if FileManager.default.fileExists(atPath: shotPath) {
                let attr = try FileManager.default.attributesOfItem(atPath: shotPath)
                let size = attr[.size] as? Int ?? 0
                print("✅ Screenshot exists at \(shotPath) with size: \(size) bytes")

                // Run Vision OCR directly on the screenshot image to get pixel coordinates
                guard let imgSource = CGImageSourceCreateWithURL(URL(fileURLWithPath: shotPath) as CFURL, nil),
                      let cgImage = CGImageSourceCreateImageAtIndex(imgSource, 0, nil) else {
                    print("❌ Failed to load CGImage from screenshot")
                    return
                }

                let imgW = CGFloat(cgImage.width)
                let imgH = CGFloat(cgImage.height)
                print("CGImage dimensions: \(Int(imgW))x\(Int(imgH)) pixels")

                let req = VNRecognizeTextRequest()
                req.recognitionLevel = .fast
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try? handler.perform([req])

                guard let results = req.results else {
                    print("❌ No OCR results")
                    return
                }

                print("Total OCR text blocks detected: \(results.count)")
                // Find candidates in top 20% of image
                for obs in results {
                    guard let top = obs.topCandidates(1).first else { continue }
                    let box = obs.boundingBox
                    // In Vision: box.origin.y = 0 at bottom, 1 at top.
                    // Distance from top: (1.0 - (box.origin.y + box.height))
                    let normYFromTop = 1.0 - (box.origin.y + box.height)
                    if normYFromTop <= 0.20 {
                        let pxX = box.origin.x * imgW
                        let pxY = normYFromTop * imgH
                        let pxW = box.width * imgW
                        let pxH = box.height * imgH
                        let midX = pxX + pxW * 0.5
                        let midY = pxY + pxH * 0.5
                        print("  [TOP TOOLBAR] '\(top.string)' at (\(Int(midX)), \(Int(midY))) [size \(Int(pxW))x\(Int(pxH))] (normY: \(String(format: "%.3f", normYFromTop)))")
                    }
                }
            } else {
                print("❌ Screenshot was not saved to \(shotPath)")
            }

            print("\n✅ CUA-DRIVER SUCCESSFULLY CONNECTED TO TRADINGVIEW!")
        } catch {
            print("❌ Error during Cua-Driver execution: \(error)")
        }
    }
}
