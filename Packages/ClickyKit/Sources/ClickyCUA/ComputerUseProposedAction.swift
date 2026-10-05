//
//  ComputerUseProposedAction.swift
//  ClickyKit (ClickyCUA)
//
//  Universal data contract for proposed physical/system actions.
//

import CoreGraphics
import Foundation

// MARK: - ComputerUseProposedAction
public struct ComputerUseProposedAction: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var category: String
    public var appName: String
    public var appIcon: String
    public var title: String
    public var details: String
    public var targetCoordinate: CGPoint?
    public var actionType: ActionType

    public enum ActionType: String, Equatable, Sendable {
        case click
        case keyCombo
        case launchApp
        case runScript
    }

    public init(
        category: String = "Action Suggestion",
        appName: String = "System",
        appIcon: String = "macwindow",
        title: String,
        details: String,
        targetCoordinate: CGPoint? = nil,
        actionType: ActionType = .click
    ) {
        self.id = UUID()
        self.category = category
        self.appName = appName
        self.appIcon = appIcon
        self.title = title
        self.details = details
        self.targetCoordinate = targetCoordinate
        self.actionType = actionType
    }
}
