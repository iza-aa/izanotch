import sys

file_path = "/Users/heizaaa/Desktop/cdev/iza-3/boringNotch/Clicky/HomeSpace/HomeSpaceRootView.swift"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

start_marker = "            // Centered Workspace Content (Max width 640pt, perfectly centered, zero scroll)\n            VStack(spacing: 11) {"
end_marker = "            .frame(maxWidth: 640)\n            .padding(.bottom, 14)\n        }"

if start_marker not in content:
    print("ERROR: start_marker not found")
    sys.exit(1)

if end_marker not in content:
    print("ERROR: end_marker not found")
    sys.exit(1)

replacement = """            // Top-Pinned Workspace Content
            VStack(alignment: .leading, spacing: 18) {
                // 1. Live Hero Avatar Preview & Name/Role (Clean Minimalist Form)
                HStack(spacing: 16) {
                    CompanionProceduralAvatarView(
                        definition: currentEditDefinition,
                        expressionName: animationEngine.isPlaying ? animationEngine.currentExpressionKey : editAvatarLabExpression,
                        autoBlink: true,
                        size: 72
                    )
                    .frame(width: 76, height: 76)

                    VStack(alignment: .leading, spacing: 6) {
                        // Name & Role Inputs (Zero redundant buttons, zero extra pills)
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("NAME")
                                    .font(.system(size: 8.5, weight: .bold))
                                    .foregroundColor(.white.opacity(0.45))

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
                    }
                }
                .padding(.horizontal, 24)

                // 2. Character Shapes: "CHARACTER" (Clean Icons, Zero Cards, Zero Text)
                VStack(alignment: .leading, spacing: 8) {
                    Text("CHARACTER")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.45))
                        .tracking(0.6)

                    HStack(spacing: 12) {
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
                                ZStack {
                                    if isSelected {
                                        Circle()
                                            .stroke(Color(hex: editCloudColorHex.isEmpty ? "#FF233B" : editCloudColorHex), lineWidth: 2)
                                            .frame(width: 40, height: 40)
                                    }

                                    CompanionProceduralAvatarView(
                                        definition: template.toAvatarDefinition(cloudColorHex: isSelected ? editCloudColorHex : nil),
                                        expressionName: "neutral",
                                        autoBlink: false,
                                        size: 28
                                    )
                                    .frame(width: 32, height: 32)
                                }
                                .frame(width: 42, height: 42)
                                .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .help(template.name)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 24)

                // 3. Option 2: 3-Column Top-Label Controls (COLOR | EXPRESSION | ANIMATION)
                HStack(alignment: .top, spacing: 18) {
                    // COLUMN 1: COLOR (Custom Swatch + Proportioned Hex Field + 4 Swatches)
                    VStack(alignment: .leading, spacing: 7) {
                        Text("COLOR")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.45))
                            .tracking(0.6)

                        HStack(spacing: 6) {
                            // Circular Swatch with ColorPicker overlay
                            Circle()
                                .fill(Color(hex: editCloudColorHex.isEmpty ? "#FF233B" : editCloudColorHex))
                                .frame(width: 22, height: 22)
                                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                                .overlay(
                                    ColorPicker("", selection: Binding(
                                        get: {
                                            Color(hex: editCloudColorHex.isEmpty ? "#FF233B" : editCloudColorHex)
                                        },
                                        set: { newColor in
                                            if let nsColor = NSColor(newColor).usingColorSpace(.sRGB) {
                                                let r = Int(round(nsColor.redComponent * 255.0))
                                                let g = Int(round(nsColor.greenComponent * 255.0))
                                                let b = Int(round(nsColor.blueComponent * 255.0))
                                                editCloudColorHex = String(format: "#%02X%02X%02X", r, g, b)
                                            }
                                        }
                                    ), supportsOpacity: false)
                                    .labelsHidden()
                                    .opacity(0.015)
                                )

                            // Hex text input field
                            HStack(spacing: 2) {
                                Text("#")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.4))

                                TextField("HEX", text: Binding(
                                    get: {
                                        editCloudColorHex.replacingOccurrences(of: "#", with: "").uppercased()
                                    },
                                    set: { newText in
                                        let cleaned = newText.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                                        if cleaned.count <= 6 {
                                            editCloudColorHex = "#" + cleaned
                                        }
                                    }
                                ))
                                .textFieldStyle(.plain)
                                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white)
                                .frame(width: 48)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                            )

                            // Quick Swatches (Gold, Cyan, Purple, Red)
                            HStack(spacing: 4) {
                                ForEach(["#FF9800", "#03BDA7", "#905AFD", "#FF233B"], id: \.self) { hex in
                                    Button(action: {
                                        ClickySoundEngine.shared.play(.send)
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                            editCloudColorHex = hex
                                        }
                                    }) {
                                        Circle()
                                            .fill(Color(hex: hex))
                                            .frame(width: 12, height: 12)
                                            .overlay(
                                                Circle()
                                                    .stroke(editCloudColorHex.uppercased() == hex ? Color.white : Color.clear, lineWidth: 1.2)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .frame(width: 170, alignment: .leading)

                    // COLUMN 2: EXPRESSION (1 Chevron on Right)
                    VStack(alignment: .leading, spacing: 7) {
                        Text("EXPRESSION")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.45))
                            .tracking(0.6)

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
                                        Text("\(preset.badgeNumber)  \(preset.displayName)")
                                        if editAvatarLabExpression == preset.semanticKey {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(currentPresetDisplayName)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.horizontal, 9)
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
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // COLUMN 3: ANIMATION (1 Chevron on Right + Live Play/Stop)
                    VStack(alignment: .leading, spacing: 7) {
                        Text("ANIMATION")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.45))
                            .tracking(0.6)

                        HStack(spacing: 6) {
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
                                            Text("\(anim.displayName) (\(anim.category.rawValue))")
                                            if animationEngine.currentSequence?.id == anim.id {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Text(currentAnimationDisplayName)
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                .padding(.horizontal, 9)
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
                            .buttonStyle(.plain)

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
                                        .font(.system(size: 8, weight: .bold))
                                    Text(animationEngine.isPlaying ? "Stop" : "Play")
                                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(animationEngine.isPlaying ? Color(hex: "#FF233B") : Color(hex: "#03BDA7"))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color.white.opacity(0.08))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 24)
            }
            .frame(maxWidth: 640)

            // Pushes Action Buttons firmly to the bottom
            Spacer()

            // 4. Action Buttons (Save & Cancel) Pinned to Bottom
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
            .frame(maxWidth: 640)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }"""

start_pos = content.find(start_marker)
end_pos = content.find(end_marker) + len(end_marker)

new_content = content[:start_pos] + replacement + content[end_pos:]

with open(file_path, "w", encoding="utf-8") as f:
    f.write(new_content)

print("SUCCESS: Option 2 applied to HomeSpaceRootView.swift")
