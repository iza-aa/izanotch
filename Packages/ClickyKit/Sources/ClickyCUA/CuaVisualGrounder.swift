import ClickyPlatform
import ClickyFoundation
//
//  CuaVisualGrounder.swift
//  boringNotch
//
//  Visual Perceptual Engine for CuaDrive ("Mata CuaDrive")
//  Replaces hardcoded (x, y) coordinates with dynamic element detection:
//  - Reads window layout using Apple Vision Fast OCR (100% offline, 10-20ms, silent flag -x)
//  - Detects physical bounding box (x, y, width, height) of UI elements
//  - Calculates exact geometric center point: (midX, midY)
//  - Strictly fail-closed: returns nil if element is not visually confirmed on screen
//

import AppKit
import CoreGraphics
import Foundation
import Vision

public struct GroundedUIElement: Sendable, Equatable {
    public let text: String
    public let windowRect: CGRect
    public let centerPoint: CGPoint
    public let confidence: Float

    public init(text: String, windowRect: CGRect, centerPoint: CGPoint, confidence: Float = 1.0) {
        self.text = text
        self.windowRect = windowRect
        self.centerPoint = centerPoint
        self.confidence = confidence
    }
}

public enum CuaVisualGrounder {

    // MARK: - Core Vision OCR Observation Extractor

    /// Captures the window or crop silently (-x) and returns all detected text elements with physical window rects and centers.
    public nonisolated static func extractElements(
        windowId: CGWindowID,
        windowBounds: CGRect,
        cropNorm: CGRect = CGRect(x: 0, y: 0, width: 1.0, height: 1.0)
    ) -> [GroundedUIElement] {
        let tempPath = "/tmp/cuadrive_ground_\(windowId).png"
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        proc.arguments = ["-x", "-l", "\(windowId)", tempPath]
        try? proc.run()
        proc.waitUntilExit()

        guard let imgSource = CGImageSourceCreateWithURL(URL(fileURLWithPath: tempPath) as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imgSource, 0, nil) else {
            return []
        }

        let fullW = CGFloat(cgImage.width)
        let fullH = CGFloat(cgImage.height)

        let cropX = Int(fullW * cropNorm.origin.x)
        let cropY = Int(fullH * cropNorm.origin.y)
        let cropW = Int(fullW * cropNorm.width)
        let cropH = Int(fullH * cropNorm.height)
        let cropRect = CGRect(x: cropX, y: cropY, width: max(cropW, 10), height: max(cropH, 10))

        guard let cropped = cgImage.cropping(to: cropRect) else { return [] }

        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate
        let handler = VNImageRequestHandler(cgImage: cropped, options: [:])
        try? handler.perform([req])

        guard let results = req.results else { return [] }

        var elements: [GroundedUIElement] = []
        for obs in results {
            guard let top = obs.topCandidates(1).first else { continue }
            let box = obs.boundingBox // Normalized relative to cropped image (0,0 is bottom-left)

            // Convert crop-relative normalized coords to full window normalized coords from top
            let cropNormYFromTop = 1.0 - (box.origin.y + box.height)
            let globalNormX = cropNorm.origin.x + box.origin.x * cropNorm.width
            let globalNormY = cropNorm.origin.y + cropNormYFromTop * cropNorm.height
            let globalNormW = box.width * cropNorm.width
            let globalNormH = box.height * cropNorm.height

            // Convert to macOS top-left window coordinates
            let windowX = windowBounds.origin.x + globalNormX * windowBounds.width
            let windowY = windowBounds.origin.y + globalNormY * windowBounds.height
            let widthPt = globalNormW * windowBounds.width
            let heightPt = globalNormH * windowBounds.height

            let centerX = windowX + widthPt * 0.5
            let centerY = windowY + heightPt * 0.5

            let elemRect = CGRect(x: windowX, y: windowY, width: widthPt, height: heightPt)
            let center = CGPoint(x: centerX, y: centerY)

            elements.append(GroundedUIElement(
                text: top.string,
                windowRect: elemRect,
                centerPoint: center,
                confidence: top.confidence
            ))
        }

        return elements
    }

    // MARK: - Cua-Driver Native Screenshot Grounding & Verification (Opsi A)

    /// Scans a window screenshot captured by cua-driver and locates elements in screenshot pixel coordinates.
    public nonisolated static func locateInScreenshot(
        imagePath: String,
        matching pattern: String,
        minNormY: CGFloat = 0.0,
        maxNormY: CGFloat = 0.20
    ) -> (text: String, pixelCenter: CGPoint, pixelSize: CGSize)? {
        guard let imgSource = CGImageSourceCreateWithURL(URL(fileURLWithPath: imagePath) as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imgSource, 0, nil) else { return nil }

        let imgW = CGFloat(cgImage.width)
        let imgH = CGFloat(cgImage.height)

        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([req])

        guard let results = req.results else { return nil }
        let lower = pattern.lowercased()

        for obs in results {
            guard let top = obs.topCandidates(1).first else { continue }
            let text = top.string
            guard text.lowercased().contains(lower) else { continue }

            let box = obs.boundingBox
            let normYFromTop = 1.0 - (box.origin.y + box.height)
            guard normYFromTop >= minNormY && normYFromTop <= maxNormY else { continue }

            // Precise Substring Bounding Box Extraction (Option 1 Canon):
            // If the observation contains multiple words or neighboring toolbar buttons (e.g. "BTCUSDT.P o O"),
            // isolate the specific bounding box of the matched target pattern (e.g. "BTCUSDT" or "USDT").
            if let matchedRange = text.range(of: pattern, options: .caseInsensitive),
               let subBox = try? top.boundingBox(for: matchedRange) {
                let subNormY = 1.0 - (subBox.boundingBox.origin.y + subBox.boundingBox.height)
                let subPxX = subBox.boundingBox.origin.x * imgW
                let subPxY = subNormY * imgH
                let subPxW = subBox.boundingBox.width * imgW
                let subPxH = subBox.boundingBox.height * imgH
                let subMidX = subPxX + subPxW * 0.5
                let subMidY = subPxY + subPxH * 0.5

                return (String(text[matchedRange]), CGPoint(x: subMidX, y: subMidY), CGSize(width: subPxW, height: subPxH))
            }

            // Fallback to observation bounding box if sub-box extraction is unavailable
            let pxX = box.origin.x * imgW
            let pxY = normYFromTop * imgH
            let pxW = box.width * imgW
            let pxH = box.height * imgH
            let midX = pxX + pxW * 0.5
            let midY = pxY + pxH * 0.5

            return (text, CGPoint(x: midX, y: midY), CGSize(width: pxW, height: pxH))
        }
        return nil
    }

    // MARK: - Universal Element Grounding (Zero Hardcoded XY)

    /// Finds any text element matching a keyword or regex pattern in the specified crop region.
    public nonisolated static func groundElement(
        matching pattern: String,
        windowId: CGWindowID,
        windowBounds: CGRect,
        cropNorm: CGRect = CGRect(x: 0, y: 0, width: 1.0, height: 1.0)
    ) -> GroundedUIElement? {
        let elements = extractElements(windowId: windowId, windowBounds: windowBounds, cropNorm: cropNorm)
        let lower = pattern.lowercased()
        return elements.first { $0.text.lowercased().contains(lower) }
    }
}
