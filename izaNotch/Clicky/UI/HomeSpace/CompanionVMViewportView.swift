//
//  CompanionVMViewportView.swift
//  izaNotch
//
//  Grok-Bot Style Application VM Viewport View.
//  Hosts the real WebKit application runtime with persistent sessions,
//  a titlebar with app switcher / provider chips, virtual agent cursor overlay,
//  and human takeover protocol for 2FA / login.
//

import SwiftUI
import AppKit
import WebKit

public struct VMWebViewRepresentable: NSViewRepresentable {
    @ObservedObject var controller: CompanionVMViewportController

    public func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(calibratedRed: 0.07, green: 0.07, blue: 0.08, alpha: 1.0).cgColor
        controller.viewportContainer = container

        if let wv = controller.webView {
            wv.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(wv)
            NSLayoutConstraint.activate([
                wv.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                wv.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                wv.topAnchor.constraint(equalTo: container.topAnchor),
                wv.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
        }
        return container
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        controller.viewportContainer = nsView
        if let wv = controller.webView {
            if wv.superview == nil {
                wv.translatesAutoresizingMaskIntoConstraints = false
                nsView.addSubview(wv)
                NSLayoutConstraint.activate([
                    wv.leadingAnchor.constraint(equalTo: nsView.leadingAnchor),
                    wv.trailingAnchor.constraint(equalTo: nsView.trailingAnchor),
                    wv.topAnchor.constraint(equalTo: nsView.topAnchor),
                    wv.bottomAnchor.constraint(equalTo: nsView.bottomAnchor)
                ])
            }
            if nsView.bounds.width > 50 {
                controller.updateViewportLayout(width: nsView.bounds.width, height: nsView.bounds.height, isModal: false)
            }
            if controller.isTakeoverActive {
                DispatchQueue.main.async {
                    if let win = wv.window ?? nsView.window {
                        win.makeKeyAndOrderFront(nil)
                        let shifted = win.makeFirstResponder(wv)
                        ClickyLogger.info("[TAKEOVER]", "First responder shifted to WKWebView: success=\(shifted), window='\(win.title)'")
                    }
                }
            }
        }
    }
}

public struct CompanionVMViewportView: View {
    @ObservedObject private var controller = CompanionVMViewportController.shared
    @ObservedObject private var companion = CompanionManager.shared
    public var onDismiss: (() -> Void)? = nil

    public init(onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 1. VM Titlebar
            vmTitlebar

            Divider().background(Color.white.opacity(0.08))

            // 2. Real Web Application Canvas & Virtual CUA Cursor
            ZStack(alignment: .topLeading) {
                // Interactive or Display WebKit View
                VMWebViewRepresentable(controller: controller)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(controller.isTakeoverActive)

                // Virtual Agent Cursor Overlay (Visible when companion operates)
                if !controller.isTakeoverActive {
                    virtualAgentCursorOverlay
                }

                // Takeover Notification Banner Overlay (When Login / 2FA is Required)
                if controller.requiresLoginTakeover || controller.isTakeoverActive {
                    VStack {
                        takeoverNotificationBanner
                            .padding(.top, 10)
                            .padding(.horizontal, 14)
                        Spacer()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#111215"))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.75), radius: 20, x: 0, y: 10)
        .onAppear {
            let app = companion.activeBuddy.workflowAppNames.first ?? "Workspace"
            controller.prepareViewport(slug: companion.activeBuddy.slug, app: app)
        }
    }

    // MARK: - VM Titlebar
    private var vmTitlebar: some View {
        HStack(spacing: 10) {
            // macOS Window Control Dots
            HStack(spacing: 6) {
                Circle().fill(Color(hex: "#EF4444")).frame(width: 9, height: 9)
                Circle().fill(Color(hex: "#F59E0B")).frame(width: 9, height: 9)
                Circle().fill(Color(hex: "#10B981")).frame(width: 9, height: 9)
            }

            // App Icon & Name dynamically derived from active site adapter (Zero Hardcoding)
            let currentAdapter = WebSiteAdapterRegistry.shared.adapter(for: controller.webView?.url)
            AppSystemIconView(appName: currentAdapter.name, size: 16)

            Text(currentAdapter.name)
                .font(.system(size: 11.5, weight: .bold))
                .foregroundColor(.white.opacity(0.90))

            // Provider Switcher Chips dynamically rendered from registered adapters
            HStack(spacing: 4) {
                ForEach(WebSiteAdapterRegistry.shared.adapters, id: \.id) { ad in
                    providerChip(id: ad.id, label: ad.name)
                }
            }
            .padding(.leading, 6)
            Spacer()

            // Status Badge
            HStack(spacing: 5) {
                Circle()
                    .fill(Color(hex: "#10B981"))
                    .frame(width: 6, height: 6)
                Text("Isolated Workspace")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#34D399"))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color(hex: "#064E3B").opacity(0.6))
                    .overlay(Capsule().stroke(Color(hex: "#10B981").opacity(0.3), lineWidth: 0.6))
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(hex: "#1C1E23"))
    }

    private func providerChip(id: String, label: String) -> some View {
        let isSelected = controller.mailProvider == id
        return Button(action: {
            controller.setMailProvider(id)
        }) {
            Text(label)
                .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                .padding(.horizontal, 7)
                .padding(.vertical, 2.5)
                .background(
                    Capsule()
                        .fill(isSelected ? Color(hex: "#38BDF8").opacity(0.25) : Color.white.opacity(0.04))
                        .overlay(Capsule().stroke(isSelected ? Color(hex: "#38BDF8").opacity(0.6) : Color.white.opacity(0.08), lineWidth: 0.6))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Virtual Agent Cursor Overlay
    private var virtualAgentCursorOverlay: some View {
        ZStack {
            // Ripple Pulse when clicking
            if controller.isClicking {
                Circle()
                    .stroke(Color(hex: "#38BDF8"), lineWidth: 2)
                    .frame(width: 28, height: 28)
                    .position(controller.vmCursorPosition)
                    .transition(.scale.combined(with: .opacity))
            }

            // Virtual Arrow Cursor
            HStack(spacing: 4) {
                Image(systemName: "cursorarrow")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "#38BDF8"))
                    .shadow(color: Color.black.opacity(0.8), radius: 3)

                Text(companion.activeBuddy.name)
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color(hex: "#0284C7")))
                    .shadow(radius: 2)
            }
            .position(x: controller.vmCursorPosition.x + 18, y: controller.vmCursorPosition.y + 12)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Takeover Notification Banner
    // MARK: - Takeover Notification Banner (Consolidated TakeoverStatusView)
    public var takeoverNotificationBanner: some View {
        let currentAdapter = WebSiteAdapterRegistry.shared.adapter(for: controller.webView?.url)
        return TakeoverStatusView(
            isTakeoverActive: controller.isTakeoverActive,
            title: controller.isTakeoverActive ? "Human Takeover Active" : "Authentication Required",
            subtitle: controller.isTakeoverActive
                ? "You are directly controlling the VM. Click Resume when signed in."
                : "Sign in to \(currentAdapter.name) so \(companion.activeBuddy.name) can access your messages.",
            onToggleTakeover: {
                withAnimation(.spring(response: 0.25)) {
                    controller.isTakeoverActive.toggle()
                    if !controller.isTakeoverActive {
                        controller.requiresLoginTakeover = false
                        Task { @MainActor in
                            _ = await controller.captureSnapshot()
                        }
                    }
                }
            }
        )
    }
}
