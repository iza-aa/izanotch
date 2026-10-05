import re

path = "boringNotch/Clicky/HomeSpace/HomeSpaceRootView.swift"
with open(path, "r") as f:
    content = f.read()

# Locate the section from // 1. Live Hero Avatar Preview & Name/Role
start_marker = "                // 1. Live Hero Avatar Preview & Name/Role"
end_marker = "                // 5. Action Buttons (Save & Cancel)"

assert start_marker in content, "Could not find start_marker"
assert end_marker in content, "Could not find end_marker"

start_idx = content.find(start_marker)
end_idx = content.find(end_marker)

new_content_block = """                // 1. Live Hero Avatar Preview & Name/Role (Clean Minimalist Form)
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

                // 2. Character Shapes (11 Templates — Clean Icons, Zero Cards, Zero Text)
                VStack(alignment: .leading, spacing: 8) {
                    Text("CHARACTER TEMPLATES (11 SHAPES)")
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
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.horizontal, 24)

                // 3. Bottom Controls: Left = Free Color Picker; Right = Stacked Dropdowns
                HStack(alignment: .top, spacing: 20) {
                    // LEFT COLUMN: Free Color Palette Picker (Visual Drag + Hex Input + Signature Swatches)
                    VStack(alignment: .leading, spacing: 7) {
                        Text("COLOR")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.45))
                            .tracking(0.6)

                        HStack(spacing: 8) {
                            // Native macOS ColorPicker (Drag color wheel / spectrum / sliders / eyedropper)
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
                            .frame(width: 28, height: 28)

                            // Hex text input field (freely type hex codes)
                            HStack(spacing: 3) {
                                Text("#")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.5))

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
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white)
                                .frame(width: 58)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4.5)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                            )

                            // Quick Swatches (Gold, Cyan, Purple, Red)
                            HStack(spacing: 5) {
                                ForEach(["#FF9800", "#03BDA7", "#905AFD", "#FF233B"], id: \.self) { hex in
                                    Button(action: {
                                        ClickySoundEngine.shared.play(.send)
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                            editCloudColorHex = hex
                                        }
                                    }) {
                                        Circle()
                                            .fill(Color(hex: hex))
                                            .frame(width: 14, height: 14)
                                            .overlay(
                                                Circle()
                                                    .stroke(editCloudColorHex.uppercased() == hex ? Color.white : Color.clear, lineWidth: 1.5)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // RIGHT COLUMN: Stacked Dropdowns (Expression on top, Animation on bottom)
                    VStack(alignment: .leading, spacing: 7) {
                        // Row 1: Expression Preset Dropdown (27 presets)
                        HStack(spacing: 8) {
                            Text("EXPRESSION")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white.opacity(0.45))
                                .frame(width: 68, alignment: .leading)

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
                                            Text("\\(preset.badgeNumber)  \\(preset.displayName)")
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
                            .menuStyle(.borderlessButton)
                        }

                        // Row 2: Animation Sequencer Dropdown (23 animations) + Live Play/Stop
                        HStack(spacing: 8) {
                            Text("ANIMATION")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white.opacity(0.45))
                                .frame(width: 68, alignment: .leading)

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
                                            Text("\\(anim.displayName) (\\(anim.category.rawValue))")
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
                            .menuStyle(.borderlessButton)

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

"""

content = content[:start_idx] + new_content_block + content[end_idx:]

with open(path, "w") as f:
    f.write(content)

print("SUCCESS: F-09 patch applied to HomeSpaceRootView.swift successfully!")
