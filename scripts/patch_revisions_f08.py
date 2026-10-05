import re

path = "boringNotch/Clicky/HomeSpace/HomeSpaceRootView.swift"
with open(path, "r") as f:
    content = f.read()

# 1. Replace NotchAttachmentEarsShape with NotchUnifiedHuggingShape
old_ears_shape = """// MARK: - Notch Attachment Inverted Concave Ears (Opsi 1A)
// Flairs the notch outward into the card top edge with smooth concave fillets
struct NotchAttachmentEarsShape: Shape {
    var notchLeft: CGFloat
    var notchRight: CGFloat
    var notchHeight: CGFloat = 32
    var earRadius: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // 1. Left Inverted Concave Ear
        path.move(to: CGPoint(x: notchLeft, y: 0))
        path.addLine(to: CGPoint(x: notchLeft, y: notchHeight - earRadius))
        path.addQuadCurve(
            to: CGPoint(x: notchLeft - earRadius, y: notchHeight),
            control: CGPoint(x: notchLeft, y: notchHeight)
        )
        path.addLine(to: CGPoint(x: notchLeft, y: notchHeight))
        path.closeSubpath()

        // 2. Solid center bridge flush under notch
        path.addRect(CGRect(x: notchLeft, y: 0, width: notchRight - notchLeft, height: notchHeight))

        // 3. Right Inverted Concave Ear
        path.move(to: CGPoint(x: notchRight, y: 0))
        path.addLine(to: CGPoint(x: notchRight, y: notchHeight - earRadius))
        path.addQuadCurve(
            to: CGPoint(x: notchRight + earRadius, y: notchHeight),
            control: CGPoint(x: notchRight, y: notchHeight)
        )
        path.addLine(to: CGPoint(x: notchRight, y: notchHeight))
        path.closeSubpath()

        return path
    }
}"""

new_ears_shape = """// MARK: - Notch Unified Hugging Shape (Seamless Concave )  ( Ears & Card Body)
// Flairs the notch outward into the card top edge with smooth concave fillets )  (
struct NotchUnifiedHuggingShape: Shape {
    var notchLeft: CGFloat
    var notchRight: CGFloat
    var notchHeight: CGFloat = 32
    var earRadius: CGFloat = 18
    var cornerRadius: CGFloat = 20

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // 1. Top-left corner of the card
        path.move(to: CGPoint(x: 0, y: notchHeight + cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: cornerRadius, y: notchHeight),
            control: CGPoint(x: 0, y: notchHeight)
        )

        // 2. Card top edge to left notch ear
        path.addLine(to: CGPoint(x: notchLeft - earRadius, y: notchHeight))

        // 3. Concave flair ')' flaring UP into the notch left wall
        path.addQuadCurve(
            to: CGPoint(x: notchLeft, y: notchHeight - earRadius),
            control: CGPoint(x: notchLeft, y: notchHeight)
        )

        // 4. Up the left wall of notch
        path.addLine(to: CGPoint(x: notchLeft, y: 0))

        // 5. Across top behind notch
        path.addLine(to: CGPoint(x: notchRight, y: 0))

        // 6. Down the right wall of notch
        path.addLine(to: CGPoint(x: notchRight, y: notchHeight - earRadius))

        // 7. Concave flair '(' flaring DOWN into the card top edge
        path.addQuadCurve(
            to: CGPoint(x: notchRight + earRadius, y: notchHeight),
            control: CGPoint(x: notchRight, y: notchHeight)
        )

        // 8. Card top edge to top-right corner
        path.addLine(to: CGPoint(x: rect.width - cornerRadius, y: notchHeight))

        // 9. Top-right corner of the card
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: notchHeight + cornerRadius),
            control: CGPoint(x: rect.width, y: notchHeight)
        )

        // 10. Down the right edge
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - cornerRadius))

        // 11. Bottom-right corner
        path.addQuadCurve(
            to: CGPoint(x: rect.width - cornerRadius, y: rect.height),
            control: CGPoint(x: rect.width, y: rect.height)
        )

        // 12. Across bottom edge
        path.addLine(to: CGPoint(x: cornerRadius, y: rect.height))

        // 13. Bottom-left corner
        path.addQuadCurve(
            to: CGPoint(x: 0, y: rect.height - cornerRadius),
            control: CGPoint(x: 0, y: rect.height)
        )

        // 14. Close subpath up left edge to start
        path.closeSubpath()

        return path
    }
}"""

assert old_ears_shape in content, "Could not find old_ears_shape"
content = content.replace(old_ears_shape, new_ears_shape)

# 2. Replace body wrapping with unified shape
old_body_chunk = """    var body: some View {
        let totalHeight: CGFloat = 580 + notchHeight
        ZStack(alignment: .top) {
            Color.clear.frame(width: 900, height: totalHeight)

            // Notch Inverted Concave Ears (Opsi 1A - menyatu dengan notch fisik)
            NotchAttachmentEarsShape(
                notchLeft: notchLeft,
                notchRight: notchRight,
                notchHeight: notchHeight,
                earRadius: 14
            )
            .fill(Color(hex: "#141517"))

            // Main Content Window (580pt height, sits at y: notchHeight flush below notch)
            HStack(spacing: 0) {
                // MARK: - Section 1: Sidebar (Session Manager / Multi-Buddy)
                if !isSidebarCollapsed && !isCreatingNewBuddy {
                    sidebarView
                        .frame(width: 235)
                        .transition(.move(edge: .leading).combined(with: .opacity))

                    // Vertical Divider
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 1)
                }

                // MARK: - Section 2: Active Chat Workspace
                chatWorkspaceView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: 900, height: 580)
            .background(
                ZStack {
                    // Solid dark slate base
                    Color(hex: "#141517")

                    // Smooth black gradient at top merging directly into the notch
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0.0),
                            .init(color: .black.opacity(0.85), location: 0.08),
                            .init(color: .black.opacity(0.35), location: 0.20),
                            .init(color: Color.clear, location: 0.38)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            )
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 18,
                    bottomLeadingRadius: 22,
                    bottomTrailingRadius: 22,
                    topTrailingRadius: 18,
                    style: .continuous
                )
            )
            .shadow(color: Color.black.opacity(0.45), radius: 18, x: 0, y: 10)
            .offset(y: notchHeight)
            .animation(.spring(response: 0.32, dampingFraction: 0.8), value: isSidebarCollapsed || isCreatingNewBuddy)
        }
        .frame(width: 900, height: totalHeight)"""

new_body_chunk = """    var body: some View {
        let totalHeight: CGFloat = 580 + notchHeight
        let unifiedShape = NotchUnifiedHuggingShape(
            notchLeft: notchLeft,
            notchRight: notchRight,
            notchHeight: notchHeight,
            earRadius: 18,
            cornerRadius: 20
        )

        ZStack(alignment: .top) {
            Color.clear.frame(width: 900, height: totalHeight)

            // Main Content Window (580pt height, sits at y: notchHeight flush below notch)
            HStack(spacing: 0) {
                // MARK: - Section 1: Sidebar (Session Manager / Multi-Buddy)
                if !isSidebarCollapsed && !isCreatingNewBuddy {
                    sidebarView
                        .frame(width: 235)
                        .transition(.move(edge: .leading).combined(with: .opacity))

                    // Vertical Divider
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 1)
                }

                // MARK: - Section 2: Active Chat Workspace
                chatWorkspaceView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: 900, height: 580)
            .offset(y: notchHeight)
        }
        .frame(width: 900, height: totalHeight)
        .background(
            ZStack {
                // Solid dark slate base
                Color(hex: "#141517")

                // Smooth black gradient at top merging directly into the notch
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0.0),
                        .init(color: .black.opacity(0.85), location: 0.08),
                        .init(color: .black.opacity(0.35), location: 0.20),
                        .init(color: Color.clear, location: 0.38)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .clipShape(unifiedShape)
        .shadow(color: Color.black.opacity(0.45), radius: 18, x: 0, y: 10)
        .animation(.spring(response: 0.32, dampingFraction: 0.8), value: isSidebarCollapsed || isCreatingNewBuddy)"""

assert old_body_chunk in content, "Could not find old_body_chunk"
content = content.replace(old_body_chunk, new_body_chunk)

# 3. Replace welcome state in chatWorkspaceView (lines 699-740)
old_welcome_chunk = """                                if companion.activeBuddy.messages.isEmpty && !companion.isResponding {
                                    // Clean Welcome State (100% Dynamic, no mock dummy)
                                    VStack(spacing: 14) {
                                        Spacer(minLength: 35)

                                        ZStack {
                                            Circle()
                                                .fill(Color(hex: companion.activeBuddy.avatarColorHex.isEmpty ? "#38BDF8" : companion.activeBuddy.avatarColorHex))
                                                .frame(width: 58, height: 58)
                                                .blur(radius: 14)
                                                .opacity(0.5)

                                            CompanionProceduralAvatarView(
                                                definition: companion.activeBuddy.avatarDefinition,
                                                expressionName: "happy",
                                                autoBlink: true,
                                                size: 60
                                            )
                                        }
                                        .frame(width: 68, height: 68)

                                        VStack(spacing: 4) {
                                            Text("Hi Rezki, I'm \\(companion.activeBuddy.name)")
                                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                                .foregroundColor(.white)

                                            Text("Ask me anything about your active screen, documents, or code.")
                                                .font(.system(size: 12.5, weight: .regular))
                                                .foregroundColor(.white.opacity(0.55))
                                                .multilineTextAlignment(.center)
                                        }

                                        // Real suggestions based on passive active app inspector
                                        if let suggestion = suggestionMonitor.activeSuggestion, !suggestion.prompt.isEmpty {
                                            FollowUpPillButton(text: suggestion.prompt) {
                                                submitPrompt(suggestion.prompt)
                                            }
                                            .padding(.top, 6)
                                        }

                                        Spacer(minLength: 20)
                                    }
                                    .frame(maxWidth: .infinity)
                                } else {"""

new_welcome_chunk = """                                if companion.activeBuddy.messages.isEmpty && !companion.isResponding {
                                    // Clean Modern Welcome State (Zero redundant avatar, zero aura)
                                    VStack(spacing: 16) {
                                        Spacer(minLength: 40)

                                        // Status Pill Badge
                                        HStack(spacing: 6) {
                                            Circle()
                                                .fill(Color(hex: companion.activeBuddy.avatarColorHex.isEmpty ? "#03BDA7" : companion.activeBuddy.avatarColorHex))
                                                .frame(width: 6, height: 6)
                                            Text(companion.activeBuddy.name.uppercased())
                                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                                .foregroundColor(.white.opacity(0.85))
                                                .tracking(0.8)
                                            Text("•")
                                                .foregroundColor(.white.opacity(0.3))
                                            Text("READY")
                                                .font(.system(size: 9.5, weight: .semibold))
                                                .foregroundColor(Color(hex: "#03BDA7"))
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4.5)
                                        .background(
                                            Capsule()
                                                .fill(Color.white.opacity(0.06))
                                                .overlay(
                                                    Capsule()
                                                        .stroke(Color.white.opacity(0.1), lineWidth: 0.8)
                                                )
                                        )

                                        // Modern High-Tech Typography
                                        VStack(spacing: 6) {
                                            Text("What would you like to explore?")
                                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                                .foregroundColor(.white)

                                            Text("Ask anything about your active screen, documents, code, or market data.")
                                                .font(.system(size: 13, weight: .regular))
                                                .foregroundColor(.white.opacity(0.55))
                                                .multilineTextAlignment(.center)
                                        }

                                        // Quick Action Prompt Chips
                                        HStack(spacing: 8) {
                                            Button(action: {
                                                submitPrompt("Analyze active screen context and provide key insights")
                                            }) {
                                                HStack(spacing: 6) {
                                                    Image(systemName: "sparkles")
                                                        .font(.system(size: 11))
                                                    Text("Screen Context")
                                                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                                                }
                                                .foregroundColor(.white.opacity(0.85))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 7)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                        .fill(Color.white.opacity(0.06))
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                                .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                                                        )
                                                )
                                            }
                                            .buttonStyle(.plain)

                                            Button(action: {
                                                submitPrompt("Summarize active document or open terminal logs")
                                            }) {
                                                HStack(spacing: 6) {
                                                    Image(systemName: "doc.text.magnifyingglass")
                                                        .font(.system(size: 11))
                                                    Text("Summarize Docs")
                                                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                                                }
                                                .foregroundColor(.white.opacity(0.85))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 7)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                        .fill(Color.white.opacity(0.06))
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                                .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                                                        )
                                                )
                                            }
                                            .buttonStyle(.plain)

                                            Button(action: {
                                                submitPrompt("Analyze BTC / USDT futures trend and volume profile")
                                            }) {
                                                HStack(spacing: 6) {
                                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                                        .font(.system(size: 11))
                                                    Text("Futures Analysis")
                                                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                                                }
                                                .foregroundColor(.white.opacity(0.85))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 7)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                        .fill(Color.white.opacity(0.06))
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                                .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                                                        )
                                                )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.top, 4)

                                        // Real suggestions based on passive active app inspector
                                        if let suggestion = suggestionMonitor.activeSuggestion, !suggestion.prompt.isEmpty {
                                            FollowUpPillButton(text: suggestion.prompt) {
                                                submitPrompt(suggestion.prompt)
                                            }
                                            .padding(.top, 4)
                                        }

                                        Spacer(minLength: 25)
                                    }
                                    .frame(maxWidth: .infinity)
                                } else {"""

assert old_welcome_chunk in content, "Could not find old_welcome_chunk"
content = content.replace(old_welcome_chunk, new_welcome_chunk)

# 4. Helper properties for Presets & Animations display names
helper_props = """    private var currentPresetDisplayName: String {
        if let p = CompanionAvatarLabCatalog.allPresets.first(where: { $0.semanticKey == editAvatarLabExpression || $0.id == editAvatarLabExpression }) {
            return "\\(p.number)  \\(p.displayName)"
        }
        return "00  Neutral Upward"
    }

    private var currentAnimationDisplayName: String {
        if let s = animationEngine.currentSequence {
            return s.displayName
        }
        return "Select Sequence (23 available)..."
    }

    // MARK: - Full Workspace Edit Character View (Option 1: Centered Studio Canvas)"""

# Find where editCharacterFullWorkspaceView starts and ends
old_edit_start = "    // MARK: - Full Workspace Edit Character View (Option 1: Centered Studio Canvas)"
assert old_edit_start in content, "Could not find old_edit_start"

# We will locate the start of editCharacterFullWorkspaceView and replace it until private func editPromptFileName
start_idx = content.find(old_edit_start)
end_marker = "    private func editPromptFileName(for name: String) -> String {"
end_idx = content.find(end_marker)
assert start_idx != -1 and end_idx != -1, "Could not locate editCharacterFullWorkspaceView boundaries"

new_edit_chunk = helper_props + """
    private var editCharacterFullWorkspaceView: some View {
        VStack(spacing: 0) {
            // Header Bar: Symmetrical Absolute Centered Title via ZStack
            ZStack {
                // Absolute Center Title (100% aligned with Avatar and Form center)
                Text("Edit Character")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                // Leading (< Back to Chat) & Trailing (⤢ and ✕) Buttons
                HStack {
                    Button(action: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            isEditingCharacter = false
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 10, weight: .bold))
                            Text("Back to Chat")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.08))
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Cancel and return to chat")

                    Spacer()

                    // Top-Right Action Buttons (⤢ and ✕)
                    HStack(spacing: 10) {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isSidebarCollapsed.toggle()
                            }
                        }) {
                            Image(systemName: isSidebarCollapsed ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white.opacity(0.55))
                        }
                        .buttonStyle(.plain)
                        .help(isSidebarCollapsed ? "Show sidebar" : "Expand workspace")

                        Button(action: {
                            ClickySoundEngine.shared.play(.close)
                            onClose()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.55))
                        }
                        .buttonStyle(.plain)
                        .help("Close back to notch")
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            // Centered Workspace Content (Max width 640pt, perfectly centered, zero scroll)
            VStack(spacing: 11) {
                // 1. Live Hero Avatar Preview & Name/Role
                HStack(spacing: 16) {
                    CompanionProceduralAvatarView(
                        definition: currentEditDefinition,
                        expressionName: animationEngine.isPlaying ? animationEngine.currentExpressionKey : editAvatarLabExpression,
                        autoBlink: true,
                        size: 72
                    )
                    .frame(width: 76, height: 76)

                    VStack(alignment: .leading, spacing: 6) {
                        // Name & Role Inputs
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text("NAME")
                                        .font(.system(size: 8.5, weight: .bold))
                                        .foregroundColor(.white.opacity(0.45))
                                    Spacer()
                                    if let currentT = CompanionAvatarLabCatalog.allTemplates.first(where: { $0.id == editSelectedTemplateId }),
                                       editName.lowercased() != currentT.name.lowercased() {
                                        Button(action: {
                                            editName = currentT.name
                                        }) {
                                            Text("Use '\\(currentT.name)'")
                                                .font(.system(size: 8.5, weight: .semibold))
                                                .foregroundColor(Color(hex: "#38BDF8"))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                TextField("Companion Name", text: $editName)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(Color.white.opacity(0.06))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 0.8)
                                    )
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("ROLE")
                                    .font(.system(size: 8.5, weight: .bold))
                                    .foregroundColor(.white.opacity(0.45))
                                TextField("Role", text: $editRole)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(Color.white.opacity(0.06))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 0.8)
                                    )
                            }
                        }

                        // Live Status Pill (Animation or Theme)
                        if animationEngine.isPlaying, let seq = animationEngine.currentSequence {
                            HStack(spacing: 5) {
                                Circle().fill(Color(hex: "#10B981")).frame(width: 5, height: 5)
                                Text("Playing: \\(seq.displayName)")
                                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineLimit(1)
                                Button(action: {
                                    animationEngine.stop()
                                }) {
                                    Image(systemName: "stop.fill")
                                        .font(.system(size: 6.5, weight: .bold))
                                        .foregroundColor(.white.opacity(0.8))
                                        .padding(2)
                                        .background(Circle().fill(Color.white.opacity(0.12)))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(Capsule().fill(Color(hex: "#10B981").opacity(0.15)))
                        } else if let matched = CompanionColorTheme.matchTheme(cloudHex: editCloudColorHex, ringHex: editRingColorHex) {
                            HStack(spacing: 4) {
                                Circle().fill(matched.cloudColor).frame(width: 5, height: 5)
                                Text(matched.name)
                                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(Capsule().fill(Color.white.opacity(0.08)))
                        }
                    }
                }
                .padding(.horizontal, 24)

                // 2. Character Shapes (11 Templates, 6-column open grid matching color palette)
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("CHARACTER TEMPLATES (11 SHAPES)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.45))
                            .tracking(0.6)
                        Spacer()
                        let currentT = CompanionAvatarLabCatalog.allTemplates.first { $0.id == editSelectedTemplateId }
                        Text(currentT?.name ?? "Strobi")
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(hex: editCloudColorHex.isEmpty ? "#FF9800" : editCloudColorHex))
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                        ForEach(CompanionAvatarLabCatalog.allTemplates) { template in
                            let isSelected = editSelectedTemplateId == template.id
                            Button(action: {
                                ClickySoundEngine.shared.play(.send)
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                    let oldT = CompanionAvatarLabCatalog.allTemplates.first(where: { $0.id == editSelectedTemplateId })
                                    let isNameOldOrEmpty = (oldT != nil && editName.lowercased() == oldT!.name.lowercased()) || editName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    editSelectedTemplateId = template.id
                                    if isNameOldOrEmpty {
                                        editName = template.name
                                    }
                                    if editCloudColorHex.isEmpty {
                                        editCloudColorHex = template.defaultColors.bodyHex
                                    }
                                }
                            }) {
                                HStack(spacing: 5) {
                                    CompanionProceduralAvatarView(
                                        definition: template.toAvatarDefinition(cloudColorHex: isSelected ? editCloudColorHex : nil),
                                        expressionName: "neutral",
                                        autoBlink: false,
                                        size: 20
                                    )
                                    .frame(width: 22, height: 22)

                                    Text(template.name)
                                        .font(.system(size: 9.5, weight: isSelected ? .bold : .medium, design: .rounded))
                                        .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(isSelected ? Color(hex: editCloudColorHex.isEmpty ? "#FF9800" : editCloudColorHex).opacity(0.2) : Color.white.opacity(0.04))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .stroke(isSelected ? Color(hex: editCloudColorHex.isEmpty ? "#FF9800" : editCloudColorHex) : Color.white.opacity(0.08), lineWidth: isSelected ? 1.4 : 0.6)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 24)

                // 3. Color Themes (12 Harmonious Colors, 6-column open grid)
                VStack(alignment: .leading, spacing: 5) {
                    Text("HARMONIOUS COLOR PALETTE (12 COLORS)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.45))
                        .tracking(0.6)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                        ForEach(CompanionColorTheme.allThemes) { theme in
                            ThemeSwatchButton(
                                theme: theme,
                                isSelected: isThemeSelected(theme),
                                onSelect: {
                                    ClickySoundEngine.shared.play(.send)
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                        editCloudColorHex = theme.cloudColorHex
                                        editRingColorHex = theme.ringColorHex
                                    }
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 24)

                // 4. Expression Presets & Animation Sequencer Dropdowns
                VStack(spacing: 8) {
                    // Row 1: Expression Preset Dropdown (27 presets)
                    HStack(spacing: 8) {
                        Text("EXPRESSION")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.45))
                            .frame(width: 76, alignment: .leading)

                        Menu {
                            ForEach(CompanionAvatarLabCatalog.allPresets) { preset in
                                Button(action: {
                                    animationEngine.stop()
                                    ClickySoundEngine.shared.play(.send)
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                                        editAvatarLabExpression = preset.semanticKey
                                    }
                                }) {
                                    HStack {
                                        Text("\\(preset.number)  \\(preset.displayName)")
                                        if editAvatarLabExpression == preset.semanticKey {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(currentPresetDisplayName)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 0.8)
                            )
                        }
                    }

                    // Row 2: Animation Sequencer Dropdown (23 animations) + Live Play/Stop
                    HStack(spacing: 8) {
                        Text("ANIMATION")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.45))
                            .frame(width: 76, alignment: .leading)

                        Menu {
                            ForEach(CompanionAvatarLabCatalog.allAnimations) { anim in
                                Button(action: {
                                    ClickySoundEngine.shared.play(.send)
                                    animationEngine.play(sequence: anim) { stepExpr in
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                            editAvatarLabExpression = stepExpr.semanticKey
                                        }
                                    }
                                }) {
                                    HStack {
                                        Text("\\(anim.displayName) (\\(anim.category.capitalized))")
                                        if animationEngine.currentSequence?.id == anim.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(currentAnimationDisplayName)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 0.8)
                            )
                        }

                        Button(action: {
                            if animationEngine.isPlaying {
                                animationEngine.stop()
                            } else if let s = animationEngine.currentSequence {
                                animationEngine.play(sequence: s) { stepExpr in
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        editAvatarLabExpression = stepExpr.semanticKey
                                    }
                                }
                            } else if let firstAnim = CompanionAvatarLabCatalog.allAnimations.first {
                                animationEngine.play(sequence: firstAnim) { stepExpr in
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        editAvatarLabExpression = stepExpr.semanticKey
                                    }
                                }
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: animationEngine.isPlaying ? "stop.fill" : "play.fill")
                                    .font(.system(size: 9, weight: .bold))
                                Text(animationEngine.isPlaying ? "Stop" : "Play")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(animationEngine.isPlaying ? Color(hex: "#FF233B") : Color(hex: "#03BDA7"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)

                // 5. Action Buttons (Save & Cancel)
                HStack(spacing: 12) {
                    Button(action: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            isEditingCharacter = false
                        }
                    }) {
                        Text("Cancel")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        saveCharacterEdits()
                    }) {
                        Text("Save Character")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.white)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)
            }
            .frame(maxWidth: 640)
            .padding(.bottom, 14)
        }
    }

"""

content = content[:start_idx] + new_edit_chunk + content[end_idx:]

with open(path, "w") as f:
    f.write(content)

print("SUCCESS: HomeSpaceRootView.swift patched successfully!")
