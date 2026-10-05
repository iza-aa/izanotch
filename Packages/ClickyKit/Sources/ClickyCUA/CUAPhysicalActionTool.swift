import ClickyPlatform
import ClickyFoundation
//
//  CUAPhysicalActionTool.swift
//  izaNotch (Izanotchy)
//
//  Modular CUA Physical Action Tool Protocol & Context.
//  Encapsulates individual physical cursor hands (Click, Scroll, Type, Read) into isolated, testable tools.
//

import AppKit
import Foundation

public struct CUAPhysicalActionContext: Sendable {
    public let normalizedPoint: CGPoint
    public let appName: String
    public let targetPID: pid_t?
    public let snapshotPath: String?
    public let subGoal: String
    public let targetElement: String
    public let textToType: String?

    public init(
        normalizedPoint: CGPoint,
        appName: String,
        targetPID: pid_t?,
        snapshotPath: String?,
        subGoal: String,
        targetElement: String,
        textToType: String?
    ) {
        self.normalizedPoint = normalizedPoint
        self.appName = appName
        self.targetPID = targetPID
        self.snapshotPath = snapshotPath
        self.subGoal = subGoal
        self.targetElement = targetElement
        self.textToType = textToType
    }
}

public struct CUAPhysicalActionResult: Sendable {
    public let observationResult: String
    public let isSuccess: Bool

    public init(observationResult: String, isSuccess: Bool = true) {
        self.observationResult = observationResult
        self.isSuccess = isSuccess
    }
}

public protocol CUAPhysicalActionTool: Sendable {
    var supportedActionTypes: [String] { get }
    @MainActor func execute(actionType: String, context: CUAPhysicalActionContext) async -> CUAPhysicalActionResult
}
