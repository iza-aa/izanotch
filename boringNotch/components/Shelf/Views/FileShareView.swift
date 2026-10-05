//
//  FileShareView.swift
//  boringNotch
//
//  Created by Alexander on 2025-09-24.
//

import AppKit
import Defaults
import SwiftUI
import UniformTypeIdentifiers

struct FileShareView: View {
    @EnvironmentObject private var vm: BoringViewModel
    @StateObject private var quickShare = QuickShareService.shared
    @Default(.quickShareProvider) var quickShareProvider: String

    @State private var hostView: NSView?
    @State private var interactionNonce: UUID = .init()
    @State private var isProcessing = false
    
    private var selectedProvider: QuickShareProvider {
        quickShare.availableProviders.first(where: { $0.id == quickShareProvider }) ?? QuickShareProvider(id: "System Share Menu", imageData: nil, supportsRawText: true)
    }

    var body: some View {
        dropArea
            .background(NSViewHost(view: $hostView))
            .onDrop(of: [.fileURL, .url, .utf8PlainText, .plainText, .data, .image], isTargeted: $vm.dropZoneTargeting) { providers in
                interactionNonce = .init()
                vm.dropEvent = true
                Task { await handleDrop(providers) }
                return true
            }
            .onTapGesture {
                Task {
                    await handleClick()
                }
            }
    }

    private var dropArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(colors: [Color.black.opacity(0.35), Color.black.opacity(0.20)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            vm.dropZoneTargeting
                                ? Color.accentColor.opacity(0.9)
                                : Color.white.opacity(0.1),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [10])
                        )
                )
                .shadow(color: Color.black.opacity(0.6), radius: 6, x: 0, y: 2)

            // Content & Loading State
            if isProcessing || quickShare.isPickerOpen {
                VStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                    Text("Opening...")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            } else {
                VStack(spacing: 8) {
                    Group {
                        if selectedProvider.id == "AirDrop" || selectedProvider.id.lowercased().contains("airdrop") {
                            Image("airdrop")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } else if let imgData = selectedProvider.imageData, let nsImg = NSImage(data: imgData) {
                            Image(nsImage: nsImg)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } else {
                            Image("airdrop")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        }
                    }
                    .frame(width: 52, height: 52)
                    .scaleEffect(
                        vm.dropZoneTargeting ? 1.08 : 1.0
                    )
                    .animation(.spring(response: 0.36, dampingFraction: 0.7), value: vm.dropZoneTargeting)

                    Text(selectedProvider.id)
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(16)
                .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isProcessing || quickShare.isPickerOpen)
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Actions

    private func handleDrop(_ providers: [NSItemProvider]) async {
        withAnimation(.easeInOut(duration: 0.15)) {
            isProcessing = true
        }
        defer {
            withAnimation(.easeInOut(duration: 0.2)) {
                isProcessing = false
            }
        }
        await quickShare.shareDroppedFiles(providers, using: selectedProvider, from: hostView)
    }
    
    private func handleClick() async {
        withAnimation(.easeInOut(duration: 0.15)) {
            isProcessing = true
        }
        try? await Task.sleep(for: .milliseconds(60))
        await quickShare.showFilePicker(for: selectedProvider, from: hostView)
        withAnimation(.easeInOut(duration: 0.2)) {
            isProcessing = false
        }
    }
}

// MARK: - Host NSView extractor for anchoring share sheet

private struct NSViewHost: NSViewRepresentable {
    @Binding var view: NSView?
    
    func makeNSView(context: Context) -> NSView {
        let v = NSView(frame: .zero)
        DispatchQueue.main.async { self.view = v }
        return v
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { self.view = nsView }
    }
}
