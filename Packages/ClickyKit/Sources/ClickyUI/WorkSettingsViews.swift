//
//  WorkSettingsViews.swift
//  boringNotch (Izanotchy)
//
//  Settings WORK Sections 1:1 with HeyClicky 1.0.50 Reference:
//  - AgentsSettingsView (Foto 1): Agent folder, Auto-approve extra usage, Always allow computer use, Suggest agent tasks, Files & Folders.
//  - IntegrationsSettingsView (Foto 2): Search, Add custom connector, Connected list, Available Integrations list, Connect modal.
//

import AppKit
import Defaults
import Foundation
import SwiftUI
import ClickyFoundation
import ClickyAIProviders

// MARK: - 1. Agents Settings View (1:1 Foto 1)

struct AgentsSettingsView: View {
    @Default(.agentFolderPath) private var agentFolderPath
    @Default(.autoApproveExtraUsage) private var autoApproveExtraUsage
    @Default(.alwaysAllowComputerUse) private var alwaysAllowComputerUse
    @Default(.suggestAgentTasks) private var suggestAgentTasks

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header Title
                Text("Agents")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 12)

                // Section: Autonomy
                VStack(alignment: .leading, spacing: 10) {
                    Text("Autonomy")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))

                    VStack(spacing: 0) {
                        // Row 1: Agent folder
                        HStack {
                            Text("Agent folder")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)

                            Spacer()

                            Button(action: selectAgentFolder) {
                                HStack(spacing: 6) {
                                    Image(systemName: "folder.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(hex: "#60A5FA"))

                                    Text(shortenedPath(agentFolderPath))
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.85))
                                        .lineLimit(1)

                                    Text("Change...")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(Color(hex: "#60A5FA"))
                                        .padding(.leading, 4)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)

                        Divider().background(Color.white.opacity(0.08))

                        // Row 2: Auto-approve extra usage
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Auto-approve extra usage")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)

                                Text("Automatically approve usage charges over the included monthly limit to prevent agent tasks from pausing mid-execution.")
                                    .font(.system(size: 11.5))
                                    .foregroundColor(.white.opacity(0.5))
                                    .lineSpacing(2)
                            }

                            Spacer(minLength: 20)

                            Toggle("", isOn: $autoApproveExtraUsage)
                                .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#3B82F6")))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)

                        Divider().background(Color.white.opacity(0.08))

                        // Row 3: Always allow computer use
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text("Always allow computer use")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white)

                                    Text("Full Access")
                                        .font(.system(size: 9.5, weight: .bold))
                                        .foregroundColor(Color(hex: "#38BDF8"))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color(hex: "#38BDF8").opacity(0.15))
                                        .clipShape(Capsule())
                                }

                                Text("Allow Clicky to use your mouse and keyboard without asking for confirmation every time.")
                                    .font(.system(size: 11.5))
                                    .foregroundColor(.white.opacity(0.5))
                                    .lineSpacing(2)
                            }

                            Spacer(minLength: 20)

                            Toggle("", isOn: $alwaysAllowComputerUse)
                                .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#3B82F6")))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)

                        Divider().background(Color.white.opacity(0.08))

                        // Row 4: Suggest agent tasks
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Suggest agent tasks")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)

                                Text("Get context-aware task suggestions based on what you're working on.")
                                    .font(.system(size: 11.5))
                                    .foregroundColor(.white.opacity(0.5))
                                    .lineSpacing(2)
                            }

                            Spacer(minLength: 20)

                            Toggle("", isOn: $suggestAgentTasks)
                                .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#3B82F6")))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .background(Color(hex: "#181A1E"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }

                // Section: Files & Folders
                VStack(alignment: .leading, spacing: 10) {
                    Text("Files & Folders")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(Color(hex: "#4ADE80"))
                                .font(.system(size: 14))

                            Text("Active Workspace Sandbox")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)

                            Spacer()

                            Text("Read & Write")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color(hex: "#4ADE80"))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2.5)
                                .background(Color(hex: "#4ADE80").opacity(0.12))
                                .clipShape(Capsule())
                        }

                        Text(agentFolderPath)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        Text("Agents can read and create files, inspect codebases, and run build commands within this directory.")
                            .font(.system(size: 11.5))
                            .foregroundColor(.white.opacity(0.45))
                    }
                    .padding(16)
                    .background(Color(hex: "#181A1E"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }

                Spacer(minLength: 30)
            }
            .padding(.horizontal, 28)
        }
    }

    private func selectAgentFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Select Agent Folder"

        if panel.runModal() == .OK, let url = panel.url {
            agentFolderPath = url.path
            ClickyLogger.info("[AGENTS]", "Agent folder updated to: \(url.path)")
        }
    }

    private func shortenedPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return path.replacingOccurrences(of: home, with: "~")
        }
        return path
    }
}

// MARK: - 2. Integrations Settings View (1:1 Foto 2)

struct IntegrationsSettingsView: View {
    @ObservedObject private var manager = IntegrationsManager.shared
    @State private var connectingItem: IntegrationItem?
    @State private var isShowingCustomConnectorSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // Header Title
                Text("Integrations")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 12)

                // Search Bar + Add Custom Connector Button (Foto 2)
                HStack(spacing: 12) {
                    // Search Input
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.4))

                        TextField("Search integrations...", text: $manager.searchText)
                            .font(.system(size: 13))
                            .textFieldStyle(.plain)
                            .foregroundColor(.white)

                        if !manager.searchText.isEmpty {
                            Button(action: { manager.searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )

                    // Add Custom Connector Button
                    Button(action: { isShowingCustomConnectorSheet = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                            Text("Add custom connector")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

                // Section: CONNECTED
                if !manager.connectedIntegrations.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("CONNECTED")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundColor(.white.opacity(0.45))
                            .tracking(0.6)

                        VStack(spacing: 0) {
                            ForEach(Array(manager.connectedIntegrations.enumerated()), id: \.element.id) { index, item in
                                integrationRow(item: item, isConnected: true)

                                if index < manager.connectedIntegrations.count - 1 {
                                    Divider().background(Color.white.opacity(0.06))
                                }
                            }
                        }
                        .background(Color(hex: "#181A1E"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                }

                // Section: AVAILABLE INTEGRATIONS
                VStack(alignment: .leading, spacing: 10) {
                    Text("AVAILABLE INTEGRATIONS")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundColor(.white.opacity(0.45))
                        .tracking(0.6)

                    VStack(spacing: 0) {
                        ForEach(Array(manager.availableIntegrations.enumerated()), id: \.element.id) { index, item in
                            integrationRow(item: item, isConnected: false)

                            if index < manager.availableIntegrations.count - 1 {
                                Divider().background(Color.white.opacity(0.06))
                            }
                        }
                    }
                    .background(Color(hex: "#181A1E"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }

                Spacer(minLength: 30)
            }
            .padding(.horizontal, 28)
        }
        .sheet(item: $connectingItem) { item in
            IntegrationConnectionSheet(item: item) {
                connectingItem = nil
            }
        }
        .sheet(isPresented: $isShowingCustomConnectorSheet) {
            CustomConnectorSheet {
                isShowingCustomConnectorSheet = false
            }
        }
    }

    // MARK: - Row Builder

    @ViewBuilder
    private func integrationRow(item: IntegrationItem, isConnected: Bool) -> some View {
        HStack(spacing: 14) {
            // Brand Logo
            if let img = manager.logoImage(for: item) {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                fallbackIcon(for: item)
            }

            // Name & Description
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)

                    if isConnected {
                        HStack(spacing: 3) {
                            Circle().fill(Color(hex: "#4ADE80")).frame(width: 5, height: 5)
                            Text("Connected")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color(hex: "#4ADE80"))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "#4ADE80").opacity(0.12))
                        .clipShape(Capsule())
                    }
                }

                Text(item.description)
                    .font(.system(size: 11.5))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            // Action Button
            if isConnected {
                Button(action: {
                    manager.disconnect(id: item.id)
                }) {
                    Text("Disconnect")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            } else {
                Button(action: {
                    connectingItem = item
                }) {
                    Text("Connect")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func fallbackIcon(for item: IntegrationItem) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.08))
                .frame(width: 28, height: 28)

            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

// MARK: - 3. Connection Sheet Modal

struct IntegrationConnectionSheet: View {
    let item: IntegrationItem
    let onDismiss: () -> Void

    @State private var credentialText: String = ""
    @State private var isTesting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            HStack(spacing: 12) {
                if let img = IntegrationsManager.shared.logoImage(for: item) {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Connect to \(item.name)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)

                    Text(item.description)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()
            }

            Divider().background(Color.white.opacity(0.1))

            // Input Field
            VStack(alignment: .leading, spacing: 6) {
                Text(item.credentialLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))

                SecureField(item.placeholder, text: $credentialText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))

                if let urlStr = item.docsURL, let url = URL(string: urlStr) {
                    Link("Get your credentials from \(item.name) settings ↗", destination: url)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#60A5FA"))
                        .padding(.top, 2)
                }
            }

            Spacer()

            // Buttons
            HStack {
                Button("Cancel") {
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(action: {
                    IntegrationsManager.shared.connect(id: item.id, credential: credentialText)
                    onDismiss()
                }) {
                    Text("Connect & Save")
                        .font(.system(size: 12, weight: .semibold))
                }
                .disabled(credentialText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 440, height: 260)
        .background(Color(hex: "#181A1E"))
    }
}

// MARK: - 4. Custom Connector Sheet

struct CustomConnectorSheet: View {
    let onDismiss: () -> Void

    @State private var name: String = ""
    @State private var endpoint: String = ""
    @State private var token: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Custom Connector")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            Text("Connect any OpenAPI REST service or Model Context Protocol (MCP) server directly into Izanotchy.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))

            Divider().background(Color.white.opacity(0.1))

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Connector Name")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))

                    TextField("e.g. Internal Jira Server", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Server Endpoint (URL / Stdio Path)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))

                    TextField("https://api.mycompany.com/v1", text: $endpoint)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Bearer Token / Secret (Optional)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))

                    SecureField("Token...", text: $token)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Spacer()

            HStack {
                Button("Cancel") {
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save Connector") {
                    IntegrationsManager.shared.addCustomConnector(name: name, endpoint: endpoint, token: token)
                    onDismiss()
                }
                .disabled(name.isEmpty || endpoint.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 440, height: 350)
        .background(Color(hex: "#181A1E"))
    }
}
