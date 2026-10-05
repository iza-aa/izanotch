//
//  OverlayWindow.swift
//  leanring-buddy
//
//  System-wide transparent overlay window for blue glowing cursor.
//  One OverlayWindow is created per screen so the cursor buddy
//  seamlessly follows the cursor across multiple monitors.
//

import AppKit
import AVFoundation
import Combine
import SwiftUI
import ClickyFoundation
import ClickySpeech
import ClickyAgent
import ClickyDesignSystem
import ClickyCUA

class OverlayWindow: NSWindow {
    init(screen: NSScreen) {
        // Create window covering entire screen
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        // Make window transparent and non-interactive
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .screenSaver  // Always on top, above submenus and popups
        self.ignoresMouseEvents = true  // Click-through
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        self.isReleasedWhenClosed = false
        self.hasShadow = false

        // Important: Allow the window to appear even when app is not active
        self.hidesOnDeactivate = false

        // Cover the entire screen
        self.setFrame(screen.frame, display: true)

        // Make sure it's on the right screen
        if let screenForWindow = NSScreen.screens.first(where: { $0.frame == screen.frame }) {
            self.setFrameOrigin(screenForWindow.frame.origin)
        }
    }

    // Prevent window from becoming key (no focus stealing)
    override var canBecomeKey: Bool {
        return false
    }

    override var canBecomeMain: Bool {
        return false
    }
}

/// Pulsating Target Halo Ring around the target element on screen (HeyClicky v1.0.50)
struct GuidedTargetHaloView: View {
    let radius: CGFloat

    @State private var isPulsing = false
    @State private var appearOpacity: Double = 0.0

    var body: some View {
        ZStack {
            // Outer glowing pulse ring
            Circle()
                .stroke(DS.Colors.overlayCursorBlue.opacity(0.45), lineWidth: 2)
                .frame(
                    width: max(28, radius * 2) * (isPulsing ? 1.35 : 0.95),
                    height: max(28, radius * 2) * (isPulsing ? 1.35 : 0.95)
                )
                .shadow(color: DS.Colors.overlayCursorBlue.opacity(0.8), radius: 12, x: 0, y: 0)

            // Core focused ring
            Circle()
                .stroke(DS.Colors.overlayCursorBlue, lineWidth: 2.5)
                .frame(width: max(28, radius * 2), height: max(28, radius * 2))
        }
        .opacity(appearOpacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.2)) {
                appearOpacity = 1.0
            }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

// MARK: - Apple Keyboard Keycap Badges (Opsi 2B)

struct MacKeycapBadgeView: View {
    let key: String

    var body: some View {
        Text(key)
            .font(.system(size: 10.5, weight: .bold, design: .rounded))
            .foregroundColor(Color.black.opacity(0.85))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.white.opacity(0.95))
                    .shadow(color: Color.black.opacity(0.25), radius: 1, x: 0, y: 1)
            )
    }
}

/// Tokenizer that detects common macOS keyboard shortcuts in text and separates them for keycap rendering
func formatShortcutTokens(from text: String) -> [(isKeycap: Bool, content: [String])] {
    var processed = text
    let compoundPatterns: [(pattern: String, keys: String)] = [
        (#"(?i)\b(?:command|cmd)\s*(?:\+|\s)\s*(?:shift)\s*(?:\+|\s)\s*([a-z0-9])\b"#, "⌘,⇧,$1"),
        (#"(?i)\b(?:command|cmd)\s*(?:\+|\s)\s*(?:option|opt|alt)\s*(?:\+|\s)\s*([a-z0-9])\b"#, "⌘,⌥,$1"),
        (#"(?i)\b(?:control|ctrl)\s*(?:\+|\s)\s*(?:option|opt|alt)\b"#, "⌃,⌥"),
        (#"(?i)\b(?:command|cmd)\s*(?:\+|\s)\s*tab\b"#, "⌘,⇥"),
        (#"(?i)\b(?:command|cmd)\s*(?:\+|\s)\s*space\b"#, "⌘,␣"),
        (#"(?i)\b(?:command|cmd)\s*(?:\+|\s)\s*([a-z0-9])\b"#, "⌘,$1"),
        (#"(?i)\b(?:control|ctrl)\s*(?:\+|\s)\s*([a-z0-9])\b"#, "⌃,$1"),
        (#"(?i)\b(?:option|opt|alt)\s*(?:\+|\s)\s*([a-z0-9])\b"#, "⌥,$1"),
        (#"(?i)\bshift\s*(?:\+|\s)\s*([a-z0-9])\b"#, "⇧,$1"),
        (#"(?i)\b(?:escape|esc)\b"#, "⎋")
    ]

    for (pattern, keyTemplate) in compoundPatterns {
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(processed.startIndex..., in: processed)
            let matches = regex.matches(in: processed, options: [], range: range).reversed()
            for match in matches {
                var replacement = keyTemplate
                if match.numberOfRanges > 1, let subRange = Range(match.range(at: 1), in: processed) {
                    let keyChar = String(processed[subRange]).uppercased()
                    replacement = replacement.replacingOccurrences(of: "$1", with: keyChar)
                }
                if let matchRange = Range(match.range, in: processed) {
                    processed.replaceSubrange(matchRange, with: "[[KEYCAP:\(replacement)]]")
                }
            }
        }
    }

    var result: [(isKeycap: Bool, content: [String])] = []
    let parts = processed.components(separatedBy: "[[KEYCAP:")
    for (idx, part) in parts.enumerated() {
        if idx == 0 {
            if !part.isEmpty { result.append((isKeycap: false, content: [part])) }
        } else {
            let subParts = part.components(separatedBy: "]]")
            if let keyStr = subParts.first {
                let keys = keyStr.split(separator: ",").map(String.init)
                result.append((isKeycap: true, content: keys))
            }
            if subParts.count > 1 && !subParts[1].isEmpty {
                result.append((isKeycap: false, content: [subParts[1]]))
            }
        }
    }
    return result
}

/// A wrapping flow layout that places words and keycap badges inline across lines
@available(macOS 13.0, *)
struct WrappingFlowLayout: Layout {
    var horizontalSpacing: CGFloat = 4
    var verticalSpacing: CGFloat = 5
    var maxAllowedWidth: CGFloat = 260

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = min(proposal.width ?? maxAllowedWidth, maxAllowedWidth)
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxLineWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentY += lineHeight + verticalSpacing
                currentX = 0
                lineHeight = 0
            }
            currentX += size.width + horizontalSpacing
            lineHeight = max(lineHeight, size.height)
            maxLineWidth = max(maxLineWidth, currentX)
        }

        let actualW = maxLineWidth > horizontalSpacing ? maxLineWidth - horizontalSpacing : maxLineWidth
        return CGSize(width: min(maxWidth, actualW), height: currentY + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = min(bounds.width, maxAllowedWidth)
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.minX + maxWidth && currentX > bounds.minX {
                currentY += lineHeight + verticalSpacing
                currentX = bounds.minX
                lineHeight = 0
            }
            let yOffset = (lineHeight > 0 && size.height < lineHeight) ? (lineHeight - size.height) / 2 : 0
            subview.place(at: CGPoint(x: currentX, y: currentY + yOffset), proposal: .unspecified)
            currentX += size.width + horizontalSpacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

/// Sanitizes LLM text into a short, concise spoken phrase for the cursor overlay.
/// If user wants the full report, they view it in chat.
func sanitizeAndFormatCursorCardText(_ raw: String) -> String {
    var text = raw
    // 1. Cut off tables completely from cursor card (tables belong in HomeSpace chat)
    if let tableRange = text.range(of: #"(?m)^\s*\|"#, options: .regularExpression) {
        text = String(text[..<tableRange.lowerBound])
    }

    // 2. Strip raw markdown headers (###, ##, #)
    text = text.replacingOccurrences(of: #"(?m)^\s*#{1,6}\s*"#, with: "", options: .regularExpression)

    // 3. Strip horizontal dividers
    text = text.replacingOccurrences(of: #"(?m)^\s*---\s*$"#, with: "", options: .regularExpression)

    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "" }

    // 4. Extract first concise sentence / thought (ending at '.', '!', '?', or newline)
    let singleLine = trimmed.replacingOccurrences(of: "\n", with: " ")
    if let firstPeriodIndex = singleLine.firstIndex(where: { ".!?".contains($0) }) {
        let firstSentence = String(singleLine[...firstPeriodIndex]).trimmingCharacters(in: .whitespaces)
        if firstSentence.count <= 110 {
            return firstSentence
        }
    }

    // 5. If no period or single sentence is very long, cap neatly at word boundary (< 95 chars)
    if singleLine.count > 95 {
        let prefix = String(singleLine.prefix(95))
        if let lastSpace = prefix.lastIndex(of: " ") {
            return String(prefix[..<lastSpace]).trimmingCharacters(in: .whitespaces) + "..."
        }
        return prefix + "..."
    }

    return singleLine
}

/// Content view for response card with automatic inline Mac keycap badges (HeyClicky Architecture + Dynamic Intrinsic Hugging)
struct ResponseCardFormattedView: View {
    let text: String

    var body: some View {
        let cleanText = sanitizeAndFormatCursorCardText(text)
        let tokens = formatShortcutTokens(from: cleanText)

        WrappingFlowLayout(horizontalSpacing: 4, verticalSpacing: 5, maxAllowedWidth: 260) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                if token.isKeycap {
                    HStack(spacing: 3) {
                        ForEach(token.content, id: \.self) { key in
                            MacKeycapBadgeView(key: key)
                        }
                    }
                } else {
                    let words = token.content[0].split(separator: " ", omittingEmptySubsequences: false)
                    ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                        if !word.isEmpty {
                            Text(String(word))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
    }
}

// Cursor-like triangle shape (equilateral)
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let size = min(rect.width, rect.height)
        let height = size * sqrt(3.0) / 2.0

        // Top vertex
        path.move(to: CGPoint(x: rect.midX, y: rect.midY - height / 1.5))
        // Bottom left vertex
        path.addLine(to: CGPoint(x: rect.midX - size / 2, y: rect.midY + height / 3))
        // Bottom right vertex
        path.addLine(to: CGPoint(x: rect.midX + size / 2, y: rect.midY + height / 3))
        path.closeSubpath()
        return path
    }
}

// PreferenceKey for tracking bubble size
fileprivate struct OverlayBubbleSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

fileprivate struct OverlayNavigationBubbleSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

fileprivate struct OverlayStreamingResponseBubbleSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

/// The buddy's behavioral mode. Controls whether it follows the cursor,
/// is flying toward a detected UI element, or is pointing at an element.
enum BuddyNavigationMode {
    /// Default — buddy follows the mouse cursor with spring animation
    case followingCursor
    /// Buddy is animating toward a detected UI element location
    case navigatingToTarget
    /// Buddy has arrived at the target and is pointing at it with a speech bubble
    case pointingAtTarget
}

// SwiftUI view for the blue glowing cursor pointer.
// Each screen gets its own BlueCursorView. The view checks whether
// the cursor is currently on THIS screen and only shows the buddy
// triangle when it is. During voice interaction, the triangle is
// replaced by a waveform (listening), spinner (processing), or
// streaming text bubble (responding).
struct BlueCursorView: View {
    let screenFrame: CGRect
    let isFirstAppearance: Bool
    @ObservedObject var companionManager: CompanionManager

    @State private var cursorPosition: CGPoint
    @State private var isCursorOnThisScreen: Bool

    init(screenFrame: CGRect, isFirstAppearance: Bool, companionManager: CompanionManager) {
        self.screenFrame = screenFrame
        self.isFirstAppearance = isFirstAppearance
        self.companionManager = companionManager

        // Seed the cursor position from the current mouse location so the
        // buddy doesn't flash at (0,0) before onAppear fires.
        let mouseLocation = NSEvent.mouseLocation
        let localX = mouseLocation.x - screenFrame.origin.x
        let localY = screenFrame.height - (mouseLocation.y - screenFrame.origin.y)
        _cursorPosition = State(initialValue: CGPoint(x: localX + 35, y: localY + 25))
        _isCursorOnThisScreen = State(initialValue: screenFrame.contains(mouseLocation))
    }
    @State private var timer: Timer?
    @State private var welcomeText: String = ""
    @State private var showWelcome: Bool = true
    @State private var bubbleSize: CGSize = .zero
    @State private var bubbleOpacity: Double = 1.0
    @State private var cursorOpacity: Double = 0.0

    // MARK: - Buddy Navigation State

    /// The buddy's current behavioral mode (following cursor, navigating, or pointing).
    @State private var buddyNavigationMode: BuddyNavigationMode = .followingCursor

    /// The rotation angle of the triangle in degrees. Default is -35° (cursor-like).
    /// Changes to face the direction of travel when navigating to a target.
    @State private var triangleRotationDegrees: Double = -35.0

    /// Speech bubble text shown when pointing at a detected element.
    @State private var navigationBubbleText: String = ""
    @State private var navigationBubbleOpacity: Double = 0.0
    @State private var navigationBubbleSize: CGSize = .zero

    /// The cursor position at the moment navigation started, used to detect
    /// if the user moves the cursor enough to cancel the navigation.
    @State private var cursorPositionWhenNavigationStarted: CGPoint = .zero

    /// Timer driving the frame-by-frame bezier arc flight animation.
    /// Invalidated when the flight completes, is canceled, or the view disappears.
    @State private var navigationAnimationTimer: Timer?

    /// Scale factor applied to the buddy triangle during flight. Grows to ~1.3x
    /// at the midpoint of the arc and shrinks back to 1.0x on landing, creating
    /// an energetic "swooping" feel.
    @State private var buddyFlightScale: CGFloat = 1.0

    /// Scale factor for the navigation speech bubble's pop-in entrance.
    /// Starts at 0.5 and springs to 1.0 when the first character appears.
    @State private var navigationBubbleScale: CGFloat = 1.0

    /// True when the buddy is flying BACK to the cursor after pointing.
    /// Only during the return flight can cursor movement cancel the animation.
    @State private var isReturningToCursor: Bool = false

    /// Size of the unified streaming response text bubble.
    @State private var streamingResponseBubbleSize: CGSize = .zero

    /// Observer for HomeSpace chat window to suppress cursor card when chat is open
    @ObservedObject private var homeSpaceManager = HomeSpaceWindowManager.shared

    /// Text revealed word-by-word like HeyClicky CursorMessageBubbleWordToken
    @State private var displayedStreamingText: String = ""
    @State private var displayedWordCount: Int = 0

    /// Ticker running at 65ms for smooth, natural human reading pace word-by-word flow
    private let wordStreamTicker = Timer.publish(every: 0.065, on: .main, in: .common).autoconnect()

    // MARK: - Onboarding Video Layout

    private let onboardingVideoPlayerWidth: CGFloat = 330
    private let onboardingVideoPlayerHeight: CGFloat = 186

    private let fullWelcomeMessage = "hey! i'm clicky"

    private let navigationPointerPhrases = [
        "right here!",
        "this one!",
        "over here!",
        "click this!",
        "here it is!",
        "found it!"
    ]

    var body: some View {
        ZStack {
            // Completely transparent background (guarantees zero mouse interception)
            Color.clear

            // Welcome speech bubble (first launch only)
            if isCursorOnThisScreen && showWelcome && !welcomeText.isEmpty {
                Text(welcomeText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(companionManager.currentCursorColor)
                            .shadow(color: companionManager.currentCursorColor.opacity(0.45), radius: 6, x: 0, y: 0)
                    )
                    .fixedSize()
                    .overlay(
                        GeometryReader { geo in
                            Color.clear
                                .preference(key: OverlayBubbleSizePreferenceKey.self, value: geo.size)
                        }
                    )
                    .opacity(bubbleOpacity)
                    .position(x: cursorPosition.x + 10 + (bubbleSize.width / 2), y: cursorPosition.y + 18)
                    .animation(.spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0), value: cursorPosition)
                    .animation(.easeOut(duration: 0.5), value: bubbleOpacity)
                    .onPreferenceChange(OverlayBubbleSizePreferenceKey.self) { newSize in
                        bubbleSize = newSize
                    }
            }

            // Onboarding video — always in the view tree so opacity animation works
            // reliably. When no player exists or opacity is 0, nothing is visible.
            // allowsHitTesting(false) prevents it from intercepting clicks.
            OnboardingVideoPlayerView(player: companionManager.onboardingVideoPlayer)
                .frame(width: onboardingVideoPlayerWidth, height: onboardingVideoPlayerHeight)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: Color.black.opacity(0.4 * companionManager.onboardingVideoOpacity), radius: 12, x: 0, y: 6)
                .opacity(isCursorOnThisScreen ? companionManager.onboardingVideoOpacity : 0)
                .position(
                    x: cursorPosition.x + 10 + (onboardingVideoPlayerWidth / 2),
                    y: cursorPosition.y + 18 + (onboardingVideoPlayerHeight / 2)
                )
                .animation(.spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0), value: cursorPosition)
                .animation(.easeInOut(duration: 2.0), value: companionManager.onboardingVideoOpacity)
                .allowsHitTesting(false)

            // Onboarding prompt — "press control + option and say hi" streamed after video ends
            if isCursorOnThisScreen && companionManager.showOnboardingPrompt && !companionManager.onboardingPromptText.isEmpty {
                Text(companionManager.onboardingPromptText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(companionManager.currentCursorColor)
                            .shadow(color: companionManager.currentCursorColor.opacity(0.45), radius: 6, x: 0, y: 0)
                    )
                    .fixedSize()
                    .overlay(
                        GeometryReader { geo in
                            Color.clear
                                .preference(key: OverlayBubbleSizePreferenceKey.self, value: geo.size)
                        }
                    )
                    .opacity(companionManager.onboardingPromptOpacity)
                    .position(x: cursorPosition.x + 10 + (bubbleSize.width / 2), y: cursorPosition.y + 18)
                    .animation(.spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0), value: cursorPosition)
                    .animation(.easeOut(duration: 0.4), value: companionManager.onboardingPromptOpacity)
                    .onPreferenceChange(OverlayBubbleSizePreferenceKey.self) { newSize in
                        bubbleSize = newSize
                    }
            }

            // Navigation pointer bubble — shown when buddy arrives at a detected element.
            // Pops in with a scale-bounce (0.5x → 1.0x spring) and a bright initial
            // glow that settles, creating a "materializing" effect.
            // Suppressed when AI streaming response card is active to prevent duplicate overlapping cards.
            if buddyNavigationMode == .pointingAtTarget && !navigationBubbleText.isEmpty && !companionManager.isShowingStreamingResponse {
                Text(navigationBubbleText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(companionManager.currentCursorColor)
                            .shadow(
                                color: companionManager.currentCursorColor.opacity(0.5 + (1.0 - navigationBubbleScale) * 1.0),
                                radius: 6 + (1.0 - navigationBubbleScale) * 16,
                                x: 0, y: 0
                            )
                    )
                    .fixedSize()
                    .overlay(
                        GeometryReader { geo in
                            Color.clear
                                .preference(key: OverlayNavigationBubbleSizePreferenceKey.self, value: geo.size)
                        }
                    )
                    .scaleEffect(navigationBubbleScale)
                    .opacity(navigationBubbleOpacity)
                    .position(x: cursorPosition.x + 10 + (navigationBubbleSize.width / 2), y: cursorPosition.y + 18)
                    .animation(.spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0), value: cursorPosition)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: navigationBubbleScale)
                    .animation(.easeOut(duration: 0.5), value: navigationBubbleOpacity)
                    .onPreferenceChange(OverlayNavigationBubbleSizePreferenceKey.self) { newSize in
                        navigationBubbleSize = newSize
                    }
            }

            // Unified AI Response Text Bubble (HeyClicky Architecture + Dynamic Intrinsic Hugging)
            if isCursorOnThisScreen && companionManager.isShowingStreamingResponse && !displayedStreamingText.isEmpty {
                ResponseCardFormattedView(text: displayedStreamingText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(companionManager.currentCursorColor)
                            .shadow(color: companionManager.currentCursorColor.opacity(0.45), radius: 8, x: 0, y: 2)
                    )
                    .overlay(
                        GeometryReader { geo in
                            Color.clear
                                .preference(key: OverlayStreamingResponseBubbleSizePreferenceKey.self, value: geo.size)
                        }
                    )
                    .opacity(companionManager.streamingResponseOpacity)
                    .position(
                        calculateStreamingBubblePosition(
                            cursorPos: cursorPosition,
                            cardWidth: max(36, streamingResponseBubbleSize.width),
                            cardHeight: max(26, streamingResponseBubbleSize.height),
                            screenSize: screenFrame.size
                        )
                    )
                    .animation(.spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0), value: cursorPosition)
                    .animation(.easeOut(duration: 0.25), value: companionManager.streamingResponseOpacity)
                    .onPreferenceChange(OverlayStreamingResponseBubbleSizePreferenceKey.self) { newSize in
                        streamingResponseBubbleSize = newSize
                    }
            }

            // Pulsating Target Halo Ring (HeyClicky v1.0.50)
            if let targetScreenPoint = companionManager.detectedElementScreenLocation,
               screenFrame.contains(targetScreenPoint),
               (buddyNavigationMode == .navigatingToTarget || buddyNavigationMode == .pointingAtTarget) {
                let targetSwiftUIPos = convertScreenPointToSwiftUICoordinates(targetScreenPoint)
                GuidedTargetHaloView(radius: companionManager.detectedElementTargetRadius)
                    .position(targetSwiftUIPos)
                    .transition(.opacity)
            }

            // Blue triangle cursor — shown when idle or while TTS is playing (responding).
            // All three states (triangle, waveform, spinner) stay in the view tree
            // permanently and cross-fade via opacity so SwiftUI doesn't remove/re-insert
            // them (which caused a visible cursor "pop").
            //
            // During cursor following: fast spring animation for snappy tracking.
            // During navigation: NO implicit animation — the frame-by-frame bezier
            // timer controls position directly at 60fps for a smooth arc flight.
            Triangle()
                .fill(companionManager.currentCursorColor)
                .frame(width: 16, height: 16)
                .rotationEffect(.degrees(triangleRotationDegrees))
                .shadow(color: companionManager.currentCursorColor, radius: 8 + (buddyFlightScale - 1.0) * 20, x: 0, y: 0)
                .scaleEffect(buddyFlightScale)
                .opacity(buddyIsVisibleOnThisScreen && (companionManager.voiceState == .idle || companionManager.voiceState == .responding) ? cursorOpacity : 0)
                .position(cursorPosition)
                .animation(
                    buddyNavigationMode == .followingCursor
                        ? .spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0)
                        : nil,
                    value: cursorPosition
                )
                .animation(.easeIn(duration: 0.25), value: companionManager.voiceState)
                .animation(
                    buddyNavigationMode == .navigatingToTarget ? nil : .easeInOut(duration: 0.3),
                    value: triangleRotationDegrees
                )

            // Dynamic color waveform — replaces the triangle while listening
            BlueCursorWaveformView(audioPowerLevel: companionManager.currentAudioPowerLevel, cursorColor: companionManager.currentCursorColor)
                .opacity(buddyIsVisibleOnThisScreen && companionManager.voiceState == .listening ? cursorOpacity : 0)
                .position(cursorPosition)
                .animation(.spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0), value: cursorPosition)
                .animation(.easeIn(duration: 0.15), value: companionManager.voiceState)

            // Dynamic color spinner — shown while the AI is processing
            BlueCursorSpinnerView(cursorColor: companionManager.currentCursorColor)
                .opacity(buddyIsVisibleOnThisScreen && companionManager.voiceState == .processing ? cursorOpacity : 0)
                .position(cursorPosition)
                .animation(.spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0), value: cursorPosition)
                .animation(.easeIn(duration: 0.15), value: companionManager.voiceState)
        }
        .frame(width: screenFrame.width, height: screenFrame.height)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            // Set initial cursor position immediately before starting animation
            let mouseLocation = NSEvent.mouseLocation
            isCursorOnThisScreen = screenFrame.contains(mouseLocation)

            let swiftUIPosition = convertScreenPointToSwiftUICoordinates(mouseLocation)
            self.cursorPosition = CGPoint(x: swiftUIPosition.x + 35, y: swiftUIPosition.y + 25)

            startTrackingCursor()

            // Only show welcome message on first appearance (app start)
            // and only if the cursor starts on this screen
            if isFirstAppearance && isCursorOnThisScreen {
                withAnimation(.easeIn(duration: 2.0)) {
                    self.cursorOpacity = 1.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.bubbleOpacity = 0.0
                    startWelcomeAnimation()
                }
            } else {
                self.cursorOpacity = 1.0
            }
        }
        .onDisappear {
            timer?.invalidate()
            navigationAnimationTimer?.invalidate()
            companionManager.tearDownOnboardingVideo()
        }
        .onChange(of: companionManager.detectedElementScreenLocation) { newLocation in
            // When a UI element location is detected, navigate the buddy to
            // that position so it points at the element.
            guard let screenLocation = newLocation,
                  let displayFrame = companionManager.detectedElementDisplayFrame else {
                return
            }

            // Only navigate if the target is on THIS screen
            guard screenFrame.contains(CGPoint(x: displayFrame.midX, y: displayFrame.midY))
                  || displayFrame == screenFrame else {
                return
            }

            startNavigatingToElement(screenLocation: screenLocation)
        }
        .onReceive(NotificationCenter.default.publisher(for: .clickyAbortFlight)) { _ in
            cancelNavigationAndResumeFollowing()
        }
        // Plan perbaikan 22 Sep (3.3): observer notifikasi flight/TTS.
        // Audit: post tanpa observer = fire-and-forget nol efek. Koordinasi via
        // @Published sudah cukup untuk visibility; observer ini untuk log + hold.
        .onReceive(NotificationCenter.default.publisher(for: .clickyFlightStarted)) { _ in
            ClickyLogger.info("[SYNC]", "flight started — bubble held")
        }
        .onReceive(NotificationCenter.default.publisher(for: .clickyTTSStarted)) { _ in
            ClickyLogger.info("[SYNC]", "TTS started — bubble held for audio")
        }
        .onReceive(wordStreamTicker) { _ in
            guard companionManager.isShowingStreamingResponse,
                  !companionManager.streamingResponseText.isEmpty else {
                if !displayedStreamingText.isEmpty {
                    displayedStreamingText = ""
                    displayedWordCount = 0
                }
                return
            }

            let targetText = companionManager.streamingResponseText
            if !targetText.hasPrefix(displayedStreamingText) && !displayedStreamingText.isEmpty {
                displayedStreamingText = ""
                displayedWordCount = 0
            }

            let words = targetText.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            if displayedWordCount < words.count {
                displayedWordCount += 1
                displayedStreamingText = words.prefix(displayedWordCount).joined(separator: " ")
            }
        }
        .onChange(of: companionManager.isShowingStreamingResponse) { isShowing in
            if !isShowing {
                displayedStreamingText = ""
                displayedWordCount = 0
            }
        }
    }

    /// Whether the buddy triangle should be visible on this screen.
    /// True when cursor is on this screen during normal following, or
    /// when navigating/pointing at a target on this screen. When another
    /// screen is navigating (detectedElementScreenLocation is set on a different
    /// monitor), hide the cursor on this monitor so only one buddy is visible.
    private var buddyIsVisibleOnThisScreen: Bool {
        guard companionManager.isClickyCursorEnabled else { return false }
        switch buddyNavigationMode {
        case .followingCursor:
            // If another screen's BlueCursorView is navigating to an element on that monitor,
            // hide the cursor on this screen to prevent a duplicate buddy.
            // But if the target is on THIS screen (or single-monitor setup), safely fall back
            // to isCursorOnThisScreen so the cursor never vanishes!
            if let _ = companionManager.detectedElementScreenLocation,
               let displayFrame = companionManager.detectedElementDisplayFrame {
                let targetIsOnThisScreen = screenFrame.contains(CGPoint(x: displayFrame.midX, y: displayFrame.midY)) || displayFrame == screenFrame
                if !targetIsOnThisScreen {
                    return false // Target is actively on another monitor
                }
            }
            return isCursorOnThisScreen
        case .navigatingToTarget, .pointingAtTarget:
            return true
        }
    }

    // MARK: - Cursor Tracking

    private func startTrackingCursor() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            let mouseLocation = NSEvent.mouseLocation
            self.isCursorOnThisScreen = self.screenFrame.contains(mouseLocation)

            // During forward flight or pointing, the buddy is NOT interrupted by
            // mouse movement — it completes its full animation and return flight.
            // Only during the RETURN flight do we allow cursor movement to cancel
            // (so the buddy snaps to following if the user moves while it's flying back).
            if self.buddyNavigationMode == .navigatingToTarget && self.isReturningToCursor {
                let currentMouseInSwiftUI = self.convertScreenPointToSwiftUICoordinates(mouseLocation)
                let distanceFromNavigationStart = hypot(
                    currentMouseInSwiftUI.x - self.cursorPositionWhenNavigationStarted.x,
                    currentMouseInSwiftUI.y - self.cursorPositionWhenNavigationStarted.y
                )
                if distanceFromNavigationStart > 100 {
                    cancelNavigationAndResumeFollowing()
                }
                return
            }

            // During forward navigation or pointing, just skip cursor tracking
            if self.buddyNavigationMode != .followingCursor {
                return
            }

            // Normal cursor following
            let swiftUIPosition = self.convertScreenPointToSwiftUICoordinates(mouseLocation)
            let buddyX = swiftUIPosition.x + 35
            let buddyY = swiftUIPosition.y + 25
            self.cursorPosition = CGPoint(x: buddyX, y: buddyY)
        }
    }

    /// Converts a macOS screen point (AppKit, bottom-left origin) to SwiftUI
    /// coordinates (top-left origin) relative to this screen's overlay window.
    private func convertScreenPointToSwiftUICoordinates(_ screenPoint: CGPoint) -> CGPoint {
        let x = screenPoint.x - screenFrame.origin.x
        let y = (screenFrame.origin.y + screenFrame.height) - screenPoint.y
        return CGPoint(x: x, y: y)
    }

    /// Dynamically calculates the center point for the streaming response bubble
    /// ensuring it floats naturally next to the buddy with synchronous zero-jitter left anchoring
    /// and graceful 4-way screen boundary clamping.
    private func calculateStreamingBubblePosition(
        cursorPos: CGPoint,
        cardWidth: CGFloat,
        cardHeight: CGFloat,
        screenSize: CGSize
    ) -> CGPoint {
        var centerX = cursorPos.x + 20 + (cardWidth / 2)
        var centerY = cursorPos.y + 12 + (cardHeight / 2)

        // 1. Right screen boundary overflow -> flip to the left of the buddy
        if centerX + (cardWidth / 2) > screenSize.width - 16 {
            centerX = cursorPos.x - 20 - (cardWidth / 2)
        }

        // 2. Bottom screen boundary overflow (Dock area) -> flip above the buddy
        if centerY + (cardHeight / 2) > screenSize.height - 76 {
            centerY = cursorPos.y - 12 - (cardHeight / 2)
        }

        // 3. Top screen boundary overflow (Notch & Menu bar) -> push below the buddy
        if centerY - (cardHeight / 2) < 38 {
            centerY = cursorPos.y + 20 + (cardHeight / 2)
        }

        // 4. Safe screen clamping
        centerX = max(cardWidth / 2 + 16, min(centerX, screenSize.width - cardWidth / 2 - 16))
        centerY = max(cardHeight / 2 + 38, min(centerY, screenSize.height - cardHeight / 2 - 16))

        return CGPoint(x: centerX, y: centerY)
    }


    /// Calculates the frame center position of the triangle such that its pointy tip (apex)
    /// aligns precisely with the given `tipLocation` when rotated at `rotationDegrees`.
    static func triangleCenterForTip(at tipLocation: CGPoint, rotationDegrees: Double = -35.0, size: CGFloat = 16.0) -> CGPoint {
        let height = size * sqrt(3.0) / 2.0
        let tipOffsetY = -height / 1.5 // in local unrotated coords, tip is at (0, -9.2376)
        let rad = rotationDegrees * .pi / 180.0
        let rotatedTipX = -tipOffsetY * sin(rad)
        let rotatedTipY = tipOffsetY * cos(rad)
        return CGPoint(x: tipLocation.x - rotatedTipX, y: tipLocation.y - rotatedTipY)
    }

    // MARK: - Element Navigation

    /// Starts animating the buddy toward a detected UI element location.
    private func startNavigatingToElement(screenLocation: CGPoint) {
        // Don't interrupt welcome animation
        guard !showWelcome || welcomeText.isEmpty else { return }

        // Convert the AppKit screen location to SwiftUI coordinates for this screen
        let targetInSwiftUI = convertScreenPointToSwiftUICoordinates(screenLocation)

        // The targetInSwiftUI is the exact center of the target element (where GuidedTargetHaloView pulses).
        let clampedTarget = CGPoint(
            x: max(16, min(targetInSwiftUI.x, screenFrame.width - 16)),
            y: max(16, min(targetInSwiftUI.y, screenFrame.height - 16))
        )

        // Opsi 1A: Tip-as-Hotspot Alignment. Calculate frame center so that the triangle's tip (apex)
        // lands precisely on clampedTarget when arrival rotation (-35°) is applied.
        let destinationCenter = BlueCursorView.triangleCenterForTip(at: clampedTarget, rotationDegrees: -35.0)

        // Record the current cursor position so we can detect if the user
        // moves the mouse enough to cancel the return flight
        let mouseLocation = NSEvent.mouseLocation
        cursorPositionWhenNavigationStarted = convertScreenPointToSwiftUICoordinates(mouseLocation)

        // Plan sinkron-teks S2: reveal kata diparalelkan busur flight — mulai
        // dari kata pertama saat navigasi dimulai, bukan selesai duluan.
        displayedWordCount = 0
        // Enter navigation mode — stop cursor following
        buddyNavigationMode = .navigatingToTarget
        isReturningToCursor = false

        animateBezierFlightArc(to: destinationCenter) {
            guard self.buddyNavigationMode == .navigatingToTarget else { return }
            self.startPointingAtElement()
        }
    }

    /// Animates the buddy along CuaDriver's Dubins & Cubic Bezier flight curve with
    /// smootherstep speed profiling (300 -> 900 -> 200 pt/s), dynamic banking rotation,
    /// and 4-substep spring-damper overshoot settling upon arrival.
    private func animateBezierFlightArc(
        to destination: CGPoint,
        onComplete: @escaping () -> Void
    ) {
        navigationAnimationTimer?.invalidate()

        let runner = CuaMotionRunner(
            startPosition: cursorPosition,
            startHeadingRadians: (triangleRotationDegrees - 90.0) * (.pi / 180.0)
        )
        // Arrive pointing at -35° (standard resting pointer angle)
        runner.planFlight(to: destination, endVisualHeading: -35.0 * (.pi / 180.0))

        let frameInterval: Double = 1.0 / 60.0
        navigationAnimationTimer = Timer.scheduledTimer(withTimeInterval: frameInterval, repeats: true) { _ in
            let finished = runner.tick(dt: frameInterval)

            self.cursorPosition = runner.currentPosition
            self.buddyFlightScale = CGFloat(runner.currentScale)

            if runner.isSpringSettling || finished {
                // Settle at the rest angle (-35°) with smooth spring wobble
                self.triangleRotationDegrees = -35.0
            } else {
                // Dynamic banking: point the triangle's tip along the tangent of travel
                self.triangleRotationDegrees = runner.currentHeadingRadians * (180.0 / .pi) + 90.0
            }

            if finished {
                self.navigationAnimationTimer?.invalidate()
                self.navigationAnimationTimer = nil
                self.cursorPosition = destination
                self.buddyFlightScale = 1.0
                self.triangleRotationDegrees = -35.0
                onComplete()
            }
        }
    }

    /// Transitions to pointing mode — shows a speech bubble with a bouncy
    /// scale-in entrance and variable-speed character streaming.
    private func startPointingAtElement() {
        buddyNavigationMode = .pointingAtTarget

        // Rotate back to default pointer angle now that we've arrived
        triangleRotationDegrees = -35.0

        // Reset navigation bubble state — start small for the scale-bounce entrance
        navigationBubbleText = ""
        navigationBubbleOpacity = 1.0
        navigationBubbleSize = .zero
        navigationBubbleScale = 0.5

        // If AI streaming response card is active, suppress the duplicate blue bubble
        if companionManager.isShowingStreamingResponse && !companionManager.streamingResponseText.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                guard self.buddyNavigationMode == .pointingAtTarget else { return }
                ClickySoundEngine.shared.play(.done)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    guard self.buddyNavigationMode == .pointingAtTarget else { return }
                    self.startFlyingBackToCursor()
                }
            }
            return
        }

        // Use custom bubble text from the companion manager (e.g. element label)
        // if available, otherwise fall back to a random pointer phrase
        let pointerPhrase = companionManager.detectedElementBubbleText
            ?? (companionManager.detectedElementLabel != nil ? "\(companionManager.detectedElementLabel!) right here!" : nil)
            ?? navigationPointerPhrases.randomElement()
            ?? "this way!"

        streamNavigationBubbleCharacter(phrase: pointerPhrase, characterIndex: 0) {
            // All characters streamed — hold for 3 seconds, then fly back
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                guard self.buddyNavigationMode == .pointingAtTarget else { return }
                self.navigationBubbleOpacity = 0.0
                ClickySoundEngine.shared.play(.done)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    guard self.buddyNavigationMode == .pointingAtTarget else { return }
                    self.startFlyingBackToCursor()
                }
            }
        }
    }

    /// Streams the navigation bubble text one character at a time with variable
    /// delays (30–60ms) for a natural "speaking" rhythm.
    private func streamNavigationBubbleCharacter(
        phrase: String,
        characterIndex: Int,
        onComplete: @escaping () -> Void
    ) {
        guard buddyNavigationMode == .pointingAtTarget else { return }
        guard characterIndex < phrase.count else {
            onComplete()
            return
        }

        let charIndex = phrase.index(phrase.startIndex, offsetBy: characterIndex)
        navigationBubbleText.append(phrase[charIndex])

        // On the first character, trigger the scale-bounce entrance
        if characterIndex == 0 {
            navigationBubbleScale = 1.0
        }

        let characterDelay = Double.random(in: 0.03...0.06)
        DispatchQueue.main.asyncAfter(deadline: .now() + characterDelay) {
            self.streamNavigationBubbleCharacter(
                phrase: phrase,
                characterIndex: characterIndex + 1,
                onComplete: onComplete
            )
        }
    }

    /// Flies the buddy back to the current cursor position after pointing is done.
    private func startFlyingBackToCursor() {
        let mouseLocation = NSEvent.mouseLocation
        let cursorInSwiftUI = convertScreenPointToSwiftUICoordinates(mouseLocation)
        let cursorWithTrackingOffset = CGPoint(x: cursorInSwiftUI.x + 35, y: cursorInSwiftUI.y + 25)

        cursorPositionWhenNavigationStarted = cursorInSwiftUI

        buddyNavigationMode = .navigatingToTarget
        isReturningToCursor = true

        animateBezierFlightArc(to: cursorWithTrackingOffset) {
            self.finishNavigationAndResumeFollowing()
        }
    }

    /// Cancels an in-progress navigation because the user moved the cursor.
    private func cancelNavigationAndResumeFollowing() {
        navigationAnimationTimer?.invalidate()
        navigationAnimationTimer = nil
        navigationBubbleText = ""
        navigationBubbleOpacity = 0.0
        navigationBubbleScale = 1.0
        buddyFlightScale = 1.0
        finishNavigationAndResumeFollowing()
    }

    /// Returns the buddy to normal cursor-following mode after navigation completes.
    private func finishNavigationAndResumeFollowing() {
        navigationAnimationTimer?.invalidate()
        navigationAnimationTimer = nil
        buddyNavigationMode = .followingCursor
        isReturningToCursor = false
        triangleRotationDegrees = -35.0
        buddyFlightScale = 1.0
        cursorOpacity = 1.0
        navigationBubbleText = ""
        navigationBubbleOpacity = 0.0
        navigationBubbleScale = 1.0
        companionManager.clearDetectedElementLocation()
    }

    // MARK: - Welcome Animation

    private func startWelcomeAnimation() {
        withAnimation(.easeIn(duration: 0.4)) {
            self.bubbleOpacity = 1.0
        }

        var currentIndex = 0
        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
            guard currentIndex < self.fullWelcomeMessage.count else {
                timer.invalidate()
                // Hold the text for 2 seconds, then fade it out
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.bubbleOpacity = 0.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    self.showWelcome = false
                    // Start the onboarding video right after the welcome text disappears
                    self.companionManager.setupOnboardingVideo()
                }
                return
            }

            let index = self.fullWelcomeMessage.index(self.fullWelcomeMessage.startIndex, offsetBy: currentIndex)
            self.welcomeText.append(self.fullWelcomeMessage[index])
            currentIndex += 1
        }
    }
}

// MARK: - Blue Cursor Waveform

/// A small dynamic waveform that replaces the triangle cursor while
/// the user is holding the push-to-talk shortcut and speaking.
private struct BlueCursorWaveformView: View {
    let audioPowerLevel: CGFloat
    var cursorColor: Color = DS.Colors.overlayCursorBlue

    private let barCount = 5
    private let listeningBarProfile: [CGFloat] = [0.4, 0.7, 1.0, 0.7, 0.4]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 36.0)) { timelineContext in
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<barCount, id: \.self) { barIndex in
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(cursorColor)
                        .frame(
                            width: 2,
                            height: barHeight(
                                for: barIndex,
                                timelineDate: timelineContext.date
                            )
                        )
                }
            }
            .shadow(color: cursorColor.opacity(0.6), radius: 6, x: 0, y: 0)
            .animation(.linear(duration: 0.08), value: audioPowerLevel)
        }
    }

    private func barHeight(for barIndex: Int, timelineDate: Date) -> CGFloat {
        let animationPhase = CGFloat(timelineDate.timeIntervalSinceReferenceDate * 3.6) + CGFloat(barIndex) * 0.35
        let normalizedAudioPowerLevel = max(audioPowerLevel - 0.008, 0)
        let easedAudioPowerLevel = pow(min(normalizedAudioPowerLevel * 2.85, 1), 0.76)
        let reactiveHeight = easedAudioPowerLevel * 10 * listeningBarProfile[barIndex]
        let idlePulse = (sin(animationPhase) + 1) / 2 * 1.5
        return 3 + reactiveHeight + idlePulse
    }
}

// MARK: - Blue Cursor Spinner

/// A small spinning indicator that replaces the triangle cursor
/// while the AI is processing a voice input.
private struct BlueCursorSpinnerView: View {
    var cursorColor: Color = DS.Colors.overlayCursorBlue
    @State private var isSpinning = false

    var body: some View {
        Circle()
            .trim(from: 0.15, to: 0.85)
            .stroke(
                AngularGradient(
                    colors: [
                        cursorColor.opacity(0.0),
                        cursorColor
                    ],
                    center: .center
                ),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
            )
            .frame(width: 14, height: 14)
            .rotationEffect(.degrees(isSpinning ? 360 : 0))
            .shadow(color: cursorColor.opacity(0.6), radius: 6, x: 0, y: 0)
            .onAppear {
                withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                    isSpinning = true
                }
            }
    }
}

// Manager for overlay windows — creates one per screen so the cursor
// buddy seamlessly follows the cursor across multiple monitors.
@MainActor
class OverlayWindowManager {
    static let shared = OverlayWindowManager()
    private var overlayWindows: [OverlayWindow] = []
    var hasShownOverlayBefore = false
    var isOverlayVisible: Bool {
        !overlayWindows.isEmpty
    }

    func rebuildOverlayWindows() {
        showOverlay(onScreens: NSScreen.screens, companionManager: CompanionManager.shared)
    }

    func showAllOverlays() {
        showOverlay(onScreens: NSScreen.screens, companionManager: CompanionManager.shared)
    }

    func hideAllOverlays() {
        hideOverlay()
    }

    func showOverlay(onScreens screens: [NSScreen], companionManager: CompanionManager) {
        // Hide any existing overlays
        hideOverlay()

        // Track if this is the first time showing overlay (welcome message)
        let isFirstAppearance = !hasShownOverlayBefore
        hasShownOverlayBefore = true

        // Create one overlay window per screen
        for screen in screens {
            let window = OverlayWindow(screen: screen)

            let contentView = BlueCursorView(
                screenFrame: screen.frame,
                isFirstAppearance: isFirstAppearance,
                companionManager: companionManager
            )

            let hostingView = NSHostingView(rootView: contentView)
            hostingView.frame = screen.frame
            window.contentView = hostingView
            window.setFrame(screen.frame, display: true)
            window.ignoresMouseEvents = true

            overlayWindows.append(window)
            window.orderFrontRegardless()
        }
    }

    func hideOverlay() {
        for window in overlayWindows {
            window.orderOut(nil)
            window.contentView = nil
        }
        overlayWindows.removeAll()
    }

    /// Fades out overlay windows over `duration` seconds, then removes them.
    func fadeOutAndHideOverlay(duration: TimeInterval = 0.4) {
        let windowsToFade = overlayWindows
        overlayWindows.removeAll()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            for window in windowsToFade {
                window.animator().alphaValue = 0
            }
        }, completionHandler: {
            for window in windowsToFade {
                window.orderOut(nil)
                window.contentView = nil
            }
        })
    }

    func isShowingOverlay() -> Bool {
        return !overlayWindows.isEmpty
    }
}

// MARK: - Onboarding Video Player

/// NSViewRepresentable wrapping an AVPlayerLayer so HLS video plays
/// inside SwiftUI. Uses a custom NSView subclass to keep the player
/// layer sized to the view's bounds automatically.
private struct OnboardingVideoPlayerView: NSViewRepresentable {
    let player: AVPlayer?

    func makeNSView(context: Context) -> AVPlayerNSView {
        let view = AVPlayerNSView()
        view.player = player
        return view
    }

    func updateNSView(_ nsView: AVPlayerNSView, context: Context) {
        nsView.player = player
    }
}

private class AVPlayerNSView: NSView {
    var player: AVPlayer? {
        didSet { playerLayer.player = player }
    }

    private let playerLayer = AVPlayerLayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        playerLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }
}

extension Notification.Name {
    static let clickyAbortFlight = Notification.Name("clickyAbortFlight")
}
