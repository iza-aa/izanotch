import sys

path = "/Users/heizaaa/Desktop/cdev/iza-3/boringNotch/Clicky/HomeSpace/HomeSpaceRootView.swift"

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

start_marker = "            // Centered Scrollable Canvas (Option 1)\n            ScrollView {"

end_marker = """                    .padding(.top, 6)
                }
                .frame(maxWidth: 480)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
            }"""

if start_marker not in content:
    print("ERROR: start_marker not found!")
    sys.exit(1)

if end_marker not in content:
    print("ERROR: end_marker not found!")
    sys.exit(1)

start_idx = content.find(start_marker)
end_idx = content.find(end_marker) + len(end_marker)

replacement = """            // MARK: - Opsi 5A: Split 2-Column Studio Inspector (Zero-Scroll Preview)
            HStack(alignment: .top, spacing: 14) {
                // -----------------------------------------------------------------
                // LEFT COLUMN (~220pt, 100% Fixed & Sticky - Zero Scroll)
                // -----------------------------------------------------------------
                VStack(spacing: 10) {
                    // 1. Large Live Hero Avatar Preview
                    ZStack {
                        CompanionProceduralAvatarView(
                            definition: currentEditDefinition,
                            expressionName: editAvatarLabExpression,
                            autoBlink: true,
                            size: 92
                        )
                    }
                    .frame(width: 100, height: 96)
                    .padding(.top, 4)

                    // Live Status Pill (Animation or Theme)
                    if animationEngine.isPlaying, let seq = animationEngine.currentSequence {
                        HStack(spacing: 6) {
                            Circle().fill(Color(hex: "#10B981")).frame(width: 5, height: 5)
                            Text("Playing: \\(seq.displayName)")
                                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                                .lineLimit(1)

                            Button(action: {
                                animationEngine.stop()
                            }) {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(2.5)
                                    .background(Circle().fill(Color.white.opacity(0.12)))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color(hex: "#10B981").opacity(0.15)))
                    } else if let matched = CompanionColorTheme.matchTheme(cloudHex: editCloudColorHex, ringHex: editRingColorHex) {
                        HStack(spacing: 4) {
                            Circle().fill(matched.cloudColor).frame(width: 5, height: 5)
                            Text(matched.name)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                    }

                    // 2. Name & Role Inputs
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text("NAME")
                                    .font(.system(size: 9, weight: .bold))
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
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 0.8))
                                )
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("ROLE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white.opacity(0.45))
                            TextField("Role or specialty", text: $editRole)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 0.8))
                                )
                        }
                    }

                    Spacer(minLength: 4)

                    // 3. Action Buttons (Save & Cancel)
                    VStack(spacing: 6) {
                        Button(action: saveCharacterEdits) {
                            Text("Save Character")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(hex: "#0F172A"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color.white))
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                isEditingCharacter = false
                            }
                        }) {
                            Text("Cancel")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.white.opacity(0.06)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: 220)
                .padding(.leading, 16)
                .padding(.bottom, 12)

                // Vertical Divider
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1)
                    .padding(.vertical, 4)

                // -----------------------------------------------------------------
                // RIGHT COLUMN (Tab-Switched Controls - Zero Scroll Needed for Results)
                // -----------------------------------------------------------------
                VStack(alignment: .leading, spacing: 8) {
                    // Studio Tab Switcher (Shape & Color, Presets 27, Animations 23)
                    HStack(spacing: 6) {
                        ForEach(StudioTab.allCases) { tab in
                            let isTabSelected = editStudioTab == tab
                            Button(action: {
                                ClickySoundEngine.shared.play(.open)
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    editStudioTab = tab
                                }
                            }) {
                                Text(tab.rawValue)
                                    .font(.system(size: 11, weight: isTabSelected ? .bold : .medium, design: .rounded))
                                    .foregroundColor(isTabSelected ? .white : .white.opacity(0.55))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule()
                                            .fill(isTabSelected ? Color.white.opacity(0.14) : Color.white.opacity(0.03))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                    .padding(.bottom, 2)

                    // Tab Content
                    if editStudioTab == .shapeAndColor {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 14) {
                                // 1. Character Templates (11 Shapes)
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("CHARACTER TEMPLATES (11 SHAPES)")
                                            .font(.system(size: 9.5, weight: .bold))
                                            .foregroundColor(.white.opacity(0.45))
                                            .tracking(0.6)
                                        Spacer()
                                        let currentT = CompanionAvatarLabCatalog.allTemplates.first { $0.id == editSelectedTemplateId }
                                        Text(currentT?.name ?? "Strobi")
                                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                                            .foregroundColor(Color(hex: editCloudColorHex.isEmpty ? "#FF9800" : editCloudColorHex))
                                    }

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
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
                                                    VStack(spacing: 4) {
                                                        ZStack {
                                                            Circle()
                                                                .fill(isSelected ? Color(hex: editCloudColorHex.isEmpty ? "#FF9800" : editCloudColorHex).opacity(0.25) : Color.white.opacity(0.04))
                                                                .frame(width: 40, height: 40)

                                                            CompanionProceduralAvatarView(
                                                                definition: template.toAvatarDefinition(cloudColorHex: isSelected ? editCloudColorHex : nil),
                                                                expressionName: "neutral",
                                                                autoBlink: false,
                                                                size: 30
                                                            )
                                                        }
                                                        .overlay(
                                                            Circle()
                                                                .stroke(isSelected ? Color(hex: editCloudColorHex.isEmpty ? "#FF9800" : editCloudColorHex) : Color.white.opacity(0.12), lineWidth: isSelected ? 1.6 : 0.8)
                                                        )

                                                        Text(template.name)
                                                            .font(.system(size: 9.5, weight: isSelected ? .bold : .medium, design: .rounded))
                                                            .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                                                            .lineLimit(1)
                                                    }
                                                    .frame(width: 54)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }

                                // 2. Color Themes (12 Harmonious Colors with Gold, Cyan Green, Purple, Red)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("HARMONIOUS COLOR PALETTE (12 COLORS)")
                                        .font(.system(size: 9.5, weight: .bold))
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

                                // 3. Persona markdown file link
                                Button(action: {
                                    let targetSlug = (editName.isEmpty ? companion.activeBuddy.name : editName).lowercased().replacingOccurrences(of: " ", with: "-")
                                    let specFile = CompanionWorkspaceManager.shared.workspaceURL(for: targetSlug).appendingPathComponent("\\(targetSlug).md")
                                    if !FileManager.default.fileExists(atPath: specFile.path) {
                                        if let profile = CompanionRosterStore.shared.allCompanions.first(where: { $0.id == companion.activeSessionID }) {
                                            _ = CompanionWorkspaceManager.shared.generateCompanionSpec(for: profile)
                                        } else {
                                            let dummyProfile = CompanionProfile(
                                                slug: targetSlug,
                                                name: editName.isEmpty ? companion.activeBuddy.name : editName,
                                                role: editRole.isEmpty ? companion.activeBuddy.roleDescription : editRole,
                                                summary: editRole.isEmpty ? companion.activeBuddy.roleDescription : editRole,
                                                cloudColorHex: editCloudColorHex.isEmpty ? companion.activeBuddy.avatarColorHex : editCloudColorHex,
                                                ringColorHex: editRingColorHex.isEmpty ? companion.activeBuddy.ringColorHex : editRingColorHex
                                            )
                                            _ = CompanionWorkspaceManager.shared.generateCompanionSpec(for: dummyProfile)
                                        }
                                    }
                                    NSWorkspace.shared.open(specFile)
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "doc.text")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(Color(hex: "#38BDF8"))

                                        VStack(alignment: .leading, spacing: 1) {
                                            Text("\\((editName.isEmpty ? companion.activeBuddy.name : editName).lowercased().replacingOccurrences(of: \\" \\", with: \\"-\\")).md")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundColor(.white)
                                            Text("System prompt & persona guidelines")
                                                .font(.system(size: 9.5, weight: .regular))
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.up.right.square")
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.45))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color.white.opacity(0.04))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.trailing, 14)
                        }
                    } else if editStudioTab == .presets {
                        // Presets 27 Grid
                        ScrollView(.vertical, showsIndicators: true) {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                                ForEach(CompanionAvatarLabCatalog.allPresets) { preset in
                                    let isSelected = editAvatarLabExpression == preset.semanticKey
                                    Button(action: {
                                        animationEngine.stop()
                                        ClickySoundEngine.shared.play(.send)
                                        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                                            editAvatarLabExpression = preset.semanticKey
                                        }
                                    }) {
                                        HStack(spacing: 6) {
                                            Text(preset.badgeNumber)
                                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                                .foregroundColor(isSelected ? .white : Color(hex: "#38BDF8"))
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 2)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                        .fill(isSelected ? Color(hex: "#38BDF8") : Color.white.opacity(0.08))
                                                )

                                            Text(preset.name)
                                                .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                                                .foregroundColor(isSelected ? .white : .white.opacity(0.85))
                                                .lineLimit(1)

                                            Spacer(minLength: 0)

                                            if isSelected {
                                                Circle()
                                                    .fill(Color(hex: "#10B981"))
                                                    .frame(width: 5, height: 5)
                                            }
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 7)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(isSelected ? Color(hex: "#38BDF8").opacity(0.18) : Color.white.opacity(0.04))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                        .stroke(isSelected ? Color(hex: "#38BDF8").opacity(0.6) : Color.white.opacity(0.08), lineWidth: 0.8)
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.trailing, 14)
                        }
                    } else if editStudioTab == .animations {
                        // Animations 23 List
                        ScrollView(.vertical, showsIndicators: true) {
                            VStack(spacing: 6) {
                                ForEach(CompanionAvatarLabCatalog.allAnimations) { anim in
                                    let isCurrentSeq = animationEngine.currentSequence?.id == anim.id
                                    let isPlayingThis = isCurrentSeq && animationEngine.isPlaying

                                    HStack(spacing: 10) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 6) {
                                                Text(anim.displayName)
                                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                                    .foregroundColor(.white)

                                                Text(anim.category.rawValue)
                                                    .font(.system(size: 8.5, weight: .medium))
                                                    .foregroundColor(.white.opacity(0.5))
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 1)
                                                    .background(Capsule().fill(Color.white.opacity(0.08)))
                                            }

                                            Text("\\(anim.steps.count) steps • \\(anim.steps.map { $0.expressionKey }.joined(separator: \\" → \\"))")
                                                .font(.system(size: 9, weight: .regular))
                                                .foregroundColor(.white.opacity(0.45))
                                                .lineLimit(1)
                                        }

                                        Spacer()

                                        Button(action: {
                                            if isPlayingThis {
                                                animationEngine.stop()
                                            } else {
                                                ClickySoundEngine.shared.play(.send)
                                                animationEngine.play(sequence: anim) { stepExpr in
                                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                                        editAvatarLabExpression = stepExpr
                                                    }
                                                }
                                            }
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: isPlayingThis ? "stop.fill" : "play.fill")
                                                    .font(.system(size: 8, weight: .bold))
                                                Text(isPlayingThis ? "Stop" : "Play")
                                                    .font(.system(size: 10, weight: .bold))
                                            }
                                            .foregroundColor(isPlayingThis ? Color.white : Color(hex: "#0F172A"))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(
                                                Capsule()
                                                    .fill(isPlayingThis ? Color(hex: "#EF4444") : Color(hex: "#38BDF8"))
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(isPlayingThis ? Color(hex: "#38BDF8").opacity(0.12) : Color.white.opacity(0.04))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .stroke(isPlayingThis ? Color(hex: "#38BDF8").opacity(0.4) : Color.white.opacity(0.08), lineWidth: 0.8)
                                            )
                                    )
                                }
                            }
                            .padding(.trailing, 14)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 12)
            }"""

new_content = content[:start_idx] + replacement + content[end_idx:]
with open(path, "w", encoding="utf-8") as f:
    f.write(new_content)

print("SUCCESS: editCharacterFullWorkspaceView patched successfully to Opsi 5A Split 2-Column Studio Inspector!")
