//
//  ClickyAnalytics.swift
//  boringNotch
//
//  Clean analytics & diagnostic logging interface for Izanotchy.
//

import Foundation

public enum ClickyAnalytics {
    public static func configure() {
        ClickyLogger.info("[ANALYTICS]", "Clicky diagnostic telemetry configured")
    }

    public static func trackAppOpened() {
        ClickyLogger.info("[LIFECYCLE]", "App opened")
    }

    public static func trackOnboardingStarted() {
        ClickyLogger.info("[ONBOARDING]", "Onboarding sequence started")
    }

    public static func trackOnboardingReplayed() {
        ClickyLogger.info("[ONBOARDING]", "Onboarding replay triggered")
    }

    public static func trackOnboardingVideoCompleted() {
        ClickyLogger.info("[ONBOARDING]", "Onboarding video completed")
    }

    public static func trackOnboardingDemoTriggered() {
        ClickyLogger.info("[ONBOARDING]", "Onboarding interactive demo triggered")
    }

    public static func trackAllPermissionsGranted() {
        ClickyLogger.success("[PERMISSIONS]", "All permissions (Accessibility, Screen, Mic) granted!")
    }

    public static func trackPermissionGranted(permission: String) {
        ClickyLogger.success("[PERMISSIONS]", "Permission granted: \(permission)")
    }

    public static func trackPushToTalkStarted() {
        ClickyLogger.info("[PTT]", "Push-to-talk started (shortcut pressed)")
    }

    public static func trackPushToTalkReleased() {
        ClickyLogger.info("[PTT]", "Push-to-talk released (shortcut released)")
    }

    public static func trackUserMessageSent(transcript: String) {
        ClickyLogger.info("[VOICE]", "User speech transcribed: \"\(transcript)\"")
    }

    public static func trackAIResponseReceived(response: String) {
        ClickyLogger.success("[AI]", "AI response received: \"\(response)\"")
    }

    public static func trackElementPointed(elementLabel: String?) {
        ClickyLogger.info("[POINTING]", "Element pointed: \"\(elementLabel ?? "unknown")\"")
    }

    public static func trackResponseError(error: String) {
        ClickyLogger.error("[AI_ERROR]", "AI Response error: \(error)")
    }

    public static func trackTTSError(error: String) {
        ClickyLogger.error("[TTS_ERROR]", "TTS synthesis error: \(error)")
    }
}
