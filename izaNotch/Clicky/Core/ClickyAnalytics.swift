//
//  ClickyAnalytics.swift
//  izaNotch
//
//  Clean analytics & diagnostic logging interface for Izanotchy.
//

import Foundation

enum ClickyAnalytics {
    static func configure() {
        ClickyLogger.info("[ANALYTICS]", "Clicky diagnostic telemetry configured")
    }

    static func trackAppOpened() {
        ClickyLogger.info("[LIFECYCLE]", "App opened")
    }

    static func trackOnboardingStarted() {
        ClickyLogger.info("[ONBOARDING]", "Onboarding sequence started")
    }

    static func trackOnboardingReplayed() {
        ClickyLogger.info("[ONBOARDING]", "Onboarding replay triggered")
    }

    static func trackOnboardingVideoCompleted() {
        ClickyLogger.info("[ONBOARDING]", "Onboarding video completed")
    }

    static func trackOnboardingDemoTriggered() {
        ClickyLogger.info("[ONBOARDING]", "Onboarding interactive demo triggered")
    }

    static func trackAllPermissionsGranted() {
        ClickyLogger.success("[PERMISSIONS]", "All permissions (Accessibility, Screen, Mic) granted!")
    }

    static func trackPermissionGranted(permission: String) {
        ClickyLogger.success("[PERMISSIONS]", "Permission granted: \(permission)")
    }

    static func trackPushToTalkStarted() {
        ClickyLogger.info("[PTT]", "Push-to-talk started (shortcut pressed)")
    }

    static func trackPushToTalkReleased() {
        ClickyLogger.info("[PTT]", "Push-to-talk released (shortcut released)")
    }

    static func trackUserMessageSent(transcript: String) {
        ClickyLogger.info("[VOICE]", "User speech transcribed: \"\(transcript)\"")
    }

    static func trackAIResponseReceived(response: String) {
        ClickyLogger.success("[AI]", "AI response received: \"\(response)\"")
    }

    static func trackElementPointed(elementLabel: String?) {
        ClickyLogger.info("[POINTING]", "Element pointed: \"\(elementLabel ?? "unknown")\"")
    }

    static func trackResponseError(error: String) {
        ClickyLogger.error("[AI_ERROR]", "AI Response error: \(error)")
    }

    static func trackTTSError(error: String) {
        ClickyLogger.error("[TTS_ERROR]", "TTS synthesis error: \(error)")
    }
}
