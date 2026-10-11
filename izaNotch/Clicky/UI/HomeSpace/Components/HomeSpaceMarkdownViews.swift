//
//  HomeSpaceMarkdownViews.swift
//  izaNotch (Izanotchy)
//
//  Rich Markdown message renderer and interactive data table component for HomeSpace.
//  Parses markdown headings, paragraphs, and tables with responsive column formatting.
//

import SwiftUI

public struct MarkdownTableData: Identifiable {
    public let id = UUID()
    public let headers: [String]
    public let rows: [[String]]

    public init(headers: [String], rows: [[String]]) {
        self.headers = headers
        self.rows = rows
    }
}

public enum MarkdownMessageBlock: Identifiable {
    case text(String)
    case heading(String)
    case table(MarkdownTableData)

    public var id: String {
        switch self {
        case .text(let t): return "t_\(t.hashValue)"
        case .heading(let h): return "h_\(h.hashValue)"
        case .table(let d): return "tbl_\(d.id.uuidString)"
        }
    }
}

public func parseMarkdownMessageBlocks(from rawText: String) -> [MarkdownMessageBlock] {
    let lines = rawText.components(separatedBy: .newlines)
    var blocks: [MarkdownMessageBlock] = []
    var currentTextLines: [String] = []

    func isTableRow(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("|") && trimmed.hasSuffix("|") && trimmed.filter { $0 == "|" }.count >= 2
    }

    func isTableDelimiter(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard isTableRow(trimmed) else { return false }
        let cells = trimmed.split(separator: "|", omittingEmptySubsequences: true)
        return !cells.isEmpty && cells.allSatisfy { cell in
            let cTrim = cell.trimmingCharacters(in: .whitespaces)
            return cTrim.allSatisfy { $0 == "-" || $0 == ":" || $0 == " " }
        }
    }

    func isHeadingLine(_ line: String) -> (isH: Bool, text: String) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("### ") {
            return (true, String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces))
        } else if trimmed.hasPrefix("## ") {
            return (true, String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces))
        } else if trimmed.hasPrefix("# ") {
            return (true, String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces))
        }
        return (false, "")
    }

    func flushText() {
        if !currentTextLines.isEmpty {
            let combined = currentTextLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !combined.isEmpty && combined != "---" {
                blocks.append(.text(combined))
            }
            currentTextLines.removeAll()
        }
    }

    func parseTable(from lines: [String]) -> MarkdownTableData? {
        guard lines.count >= 2 else { return nil }
        let headerLine = lines[0]
        let delimiterLine = lines[1]
        guard isTableDelimiter(delimiterLine) else { return nil }

        let headers = headerLine.split(separator: "|", omittingEmptySubsequences: true).map { $0.trimmingCharacters(in: .whitespaces) }
        guard !headers.isEmpty else { return nil }

        var dataRows: [[String]] = []
        for line in lines.dropFirst(2) {
            guard isTableRow(line) else { continue }
            let cells = line.split(separator: "|", omittingEmptySubsequences: true).map { $0.trimmingCharacters(in: .whitespaces) }
            if !cells.isEmpty {
                dataRows.append(cells)
            }
        }
        return MarkdownTableData(headers: headers, rows: dataRows)
    }

    var i = 0
    while i < lines.count {
        let line = lines[i]
        let hCheck = isHeadingLine(line)
        if hCheck.isH {
            flushText()
            blocks.append(.heading(hCheck.text))
            i += 1
            continue
        }
        if isTableRow(line) {
            if i + 1 < lines.count && isTableDelimiter(lines[i + 1]) {
                flushText()
                var tblLines: [String] = [line, lines[i + 1]]
                i += 2
                while i < lines.count && isTableRow(lines[i]) {
                    tblLines.append(lines[i])
                    i += 1
                }
                if let tblData = parseTable(from: tblLines) {
                    blocks.append(.table(tblData))
                } else {
                    currentTextLines.append(contentsOf: tblLines)
                }
                continue
            }
        }
        currentTextLines.append(line)
        i += 1
    }
    flushText()

    return blocks
}

public struct MarkdownTableBlockView: View {
    public let data: MarkdownTableData
    @State private var hoveredRow: Int? = nil

    public init(data: MarkdownTableData) {
        self.data = data
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Header Row
                HStack(spacing: 0) {
                    ForEach(0..<data.headers.count, id: \.self) { colIdx in
                        let header = data.headers[colIdx]
                        let colWidth = columnWidth(for: header, totalCols: data.headers.count)
                        let align = alignment(for: header)

                        Text(header)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.95))
                            .multilineTextAlignment(align == .leading ? .leading : .center)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .frame(width: colWidth, alignment: align)

                        if colIdx < data.headers.count - 1 {
                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 1)
                        }
                    }
                }
                .background(
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.white.opacity(0.06)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                Divider()
                    .background(Color.white.opacity(0.18))

                // Data Rows
                ForEach(0..<data.rows.count, id: \.self) { rowIdx in
                    let row = data.rows[rowIdx]
                    HStack(spacing: 0) {
                        ForEach(0..<data.headers.count, id: \.self) { colIdx in
                            let cellText = colIdx < row.count ? row[colIdx] : "-"
                            let header = data.headers[colIdx]
                            let colWidth = columnWidth(for: header, totalCols: data.headers.count)
                            let align = alignment(for: header)

                            cellView(text: cellText, header: header)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 7)
                                .frame(width: colWidth, alignment: align)

                            if colIdx < data.headers.count - 1 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.05))
                                    .frame(width: 1)
                            }
                        }
                    }
                    .background(
                        hoveredRow == rowIdx
                            ? Color.white.opacity(0.08)
                            : (rowIdx % 2 == 1 ? Color.white.opacity(0.025) : Color.clear)
                    )
                    .onHover { isHovered in
                        hoveredRow = isHovered ? rowIdx : nil
                    }

                    if rowIdx < data.rows.count - 1 {
                        Divider().background(Color.white.opacity(0.06))
                    }
                }
            }
            .background(Color(hex: "#14161B").opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 2)
            .padding(.vertical, 6)
        }
    }

    private func columnWidth(for header: String, totalCols: Int) -> CGFloat {
        let h = header.lowercased()
        if h == "no" || h == "#" { return 30 }
        if h.contains("timeframe") || h == "tf" { return 54 }
        if h.contains("sinyal") || h.contains("konsensus") { return 82 }
        if h.contains("indikator") || h.contains("metode") { return 130 }
        if h.contains("nilai") || h.contains("kondisi") || h.contains("status") { return 230 }
        if h.contains("koin") || h.contains("coin") || h.contains("symbol") { return 88 }
        if h.contains("setup") || h.contains("arah") || h.contains("bias") { return 68 }
        if h.contains("entry") { return 70 }
        if h.contains("sl") || h.contains("stop loss") || h.contains("bukti") { return 112 }
        if h.contains("tp") || h.contains("take profit") { return 70 }
        if h.contains("rr") || h.contains("bruto") || h.contains("risk") { return 66 }
        if h.contains("jarak") { return 60 }
        if h.contains("demand") || h.contains("area") { return 100 }
        return totalCols <= 5 ? 100 : 75
    }

    private func alignment(for header: String) -> Alignment {
        let h = header.lowercased()
        if h.contains("indikator") || h.contains("metode") || h.contains("nilai") || h.contains("kondisi") || h.contains("koin") || h.contains("symbol") {
            return .leading
        }
        return .center
    }

    @ViewBuilder
    private func cellView(text: String, header: String) -> some View {
        let h = header.lowercased()
        let tLower = text.lowercased()
        let align = alignment(for: header)

        if h.contains("rr") || text.hasPrefix("1:") {
            Text(text)
                .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "#34D399"))
        } else if h.contains("sl") || h.contains("jarak") {
            Text(text)
                .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                .foregroundColor(Color(hex: "#F87171"))
        } else if h.contains("entry") {
            Text(text)
                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(hex: "#60A5FA"))
        } else if tLower == "long" || tLower.contains("bullish") {
            Text(text)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#34D399"))
                .lineLimit(1)
                .padding(.horizontal, 7)
                .padding(.vertical, 2.5)
                .background(Color(hex: "#34D399").opacity(0.18))
                .clipShape(Capsule())
        } else if tLower == "short" || tLower.contains("bearish") {
            Text(text)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#F87171"))
                .lineLimit(1)
                .padding(.horizontal, 7)
                .padding(.vertical, 2.5)
                .background(Color(hex: "#F87171").opacity(0.18))
                .clipShape(Capsule())
        } else if tLower.contains("netral") || tLower.contains("neutral") {
            Text(text)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#FBBF24"))
                .lineLimit(1)
                .padding(.horizontal, 7)
                .padding(.vertical, 2.5)
                .background(Color(hex: "#FBBF24").opacity(0.18))
                .clipShape(Capsule())
        } else if h.contains("koin") || h.contains("coin") {
            Text(text)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
        } else {
            Text(text)
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(align == .leading ? .leading : .center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

public struct MarkdownFormattedMessageView: View {
    public let text: String

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        let blocks = parseMarkdownMessageBlocks(from: text)
        VStack(alignment: .leading, spacing: 8) {
            ForEach(blocks) { block in
                switch block {
                case .heading(let h):
                    HStack(spacing: 7) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color(hex: "#38BDF8"))
                            .frame(width: 3, height: 13)
                        Text(h)
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 2)
                case .text(let t):
                    Text(LocalizedStringKey(t))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.92))
                        .lineSpacing(3.5)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                case .table(let tbl):
                    MarkdownTableBlockView(data: tbl)
                }
            }
        }
    }
}
// MARK: - HomeSpaceEgressReportView (Schema C3: Egress 5-Part Structured View)
public struct HomeSpaceEgressReportView: View {
    public let result: EgressResult
    @State private var isExpanded: Bool = true

    public init(result: EgressResult) {
        self.result = result
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Egress 5-Part Summary
            HStack(spacing: 8) {
                Image(systemName: "list.clipboard")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(hex: "#38BDF8"))
                Text("Laporan Terstruktur")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(4)
                }
                .buttonStyle(.plain)
                .help(isExpanded ? "Ciutkan Laporan" : "Bentangkan Laporan")
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // 1. Fakta (Facts)
                    if !result.report.facts.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color(hex: "#38BDF8"))
                                Text("Fakta")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color(hex: "#38BDF8"))
                            }
                            ForEach(result.report.facts, id: \.self) { fact in
                                HStack(alignment: .top, spacing: 6) {
                                    Circle()
                                        .fill(Color(hex: "#38BDF8").opacity(0.8))
                                        .frame(width: 4, height: 4)
                                        .padding(.top, 5)
                                    Text(fact)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white.opacity(0.92))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
                    }

                    // 2. Asumsi (Assumptions)
                    if !result.report.assumptions.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "questionmark.circle")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color(hex: "#A78BFA"))
                                Text("Asumsi")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color(hex: "#A78BFA"))
                            }
                            ForEach(result.report.assumptions, id: \.self) { item in
                                HStack(alignment: .top, spacing: 6) {
                                    Circle()
                                        .fill(Color(hex: "#A78BFA").opacity(0.8))
                                        .frame(width: 4, height: 4)
                                        .padding(.top, 5)
                                    Text(item)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white.opacity(0.85))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
                    }

                    // 3. Tindakan Selesai (Completed Actions)
                    if !result.report.completedActions.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color(hex: "#34D399"))
                                Text("Aksi Selesai")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color(hex: "#34D399"))
                            }
                            ForEach(result.report.completedActions, id: \.self) { item in
                                HStack(alignment: .top, spacing: 6) {
                                    Circle()
                                        .fill(Color(hex: "#34D399").opacity(0.8))
                                        .frame(width: 4, height: 4)
                                        .padding(.top, 5)
                                    Text(item)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white.opacity(0.85))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
                    }

                    // 4. Menunggu Persetujuan (Awaiting Approval)
                    if !result.report.awaitingApproval.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color(hex: "#F59E0B"))
                                Text("Menunggu Persetujuan")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color(hex: "#F59E0B"))
                            }
                            ForEach(result.report.awaitingApproval, id: \.self) { item in
                                HStack(alignment: .top, spacing: 6) {
                                    Circle()
                                        .fill(Color(hex: "#F59E0B").opacity(0.8))
                                        .frame(width: 4, height: 4)
                                        .padding(.top, 5)
                                    Text(item)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white.opacity(0.9))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: "#F59E0B").opacity(0.08)))
                    }

                    // 5. Pertanyaan Terbuka (Open Questions)
                    if !result.report.openQuestions.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color(hex: "#EC4899"))
                                Text("Pertanyaan Terbuka")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color(hex: "#EC4899"))
                            }
                            ForEach(result.report.openQuestions, id: \.self) { item in
                                HStack(alignment: .top, spacing: 6) {
                                    Circle()
                                        .fill(Color(hex: "#EC4899").opacity(0.8))
                                        .frame(width: 4, height: 4)
                                        .padding(.top, 5)
                                    Text(item)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white.opacity(0.9))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: "#EC4899").opacity(0.08)))
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: "#0F172A").opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.8)
                )
        )
        .frame(maxWidth: 540, alignment: .leading)
    }
}
// MARK: - HomeSpaceDeliverableCardView (PRD §A9, MT-02: Deliverable Card & In-Place Revision)
public struct HomeSpaceDeliverableCardView: View {
    public let deliverable: EgressDeliverable
    public var onRevise: ((String) -> Void)? = nil

    @State private var isEditingInline: Bool = false
    @State private var editedContent: String = ""
    @State private var currentVersion: Int = 1
    @State private var previewSnippet: String = ""
    @State private var fileSizeFormatted: String = ""
    @State private var isCopied: Bool = false
    @State private var saveStatusMessage: String? = nil

    public init(deliverable: EgressDeliverable, onRevise: ((String) -> Void)? = nil) {
        self.deliverable = deliverable
        self.onRevise = onRevise
        _currentVersion = State(initialValue: deliverable.version)
    }

    private var artifactURL: URL? {
        let path = deliverable.artifact
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        } else if path.hasPrefix("~") {
            return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        }
        return nil
    }

    private var artifactFileName: String {
        artifactURL?.lastPathComponent ?? deliverable.artifact
    }

    private var typeVisuals: (icon: String, label: String, colorHex: String) {
        let ext = artifactURL?.pathExtension.lowercased() ?? ""
        let t = deliverable.type.lowercased()
        if ext == "json" || ext == "yaml" || ext == "yml" || t == "data" {
            return ("curlybraces", "Data", "#38BDF8")
        } else if ext == "csv" || ext == "tsv" || ext == "xlsx" || t == "spreadsheet" {
            return ("tablecells.fill", "Spreadsheet", "#34D399")
        } else if ext == "swift" || ext == "py" || ext == "js" || ext == "ts" || ext == "html" || t == "code" {
            return ("chevron.left.forwardslash.chevron.right", "Kode", "#A78BFA")
        } else if t == "email" || t == "draft" || ext == "eml" {
            return ("envelope.badge.fill", "Draf Pesan", "#F59E0B")
        } else if ext == "png" || ext == "jpg" || ext == "jpeg" || ext == "pdf" || t == "media" {
            return ("photo.fill", "Media", "#EC4899")
        } else {
            return ("doc.text.fill", "Dokumen", "#38BDF8")
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Type Badge & Version & Title
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: typeVisuals.icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(hex: typeVisuals.colorHex))
                    Text(typeVisuals.label)
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(Color(hex: typeVisuals.colorHex))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(
                    Capsule().fill(Color(hex: typeVisuals.colorHex).opacity(0.15))
                )

                Text(deliverable.title ?? artifactFileName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()

                Text("v\(currentVersion)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
            }

            // Preview Section
            if isEditingInline {
                VStack(alignment: .leading, spacing: 6) {
                    TextEditor(text: $editedContent)
                        .font(.system(size: 11.5, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.4)))
                        .frame(minHeight: 120, maxHeight: 220)

                    HStack {
                        Button(action: saveInlineRevision) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 10.5))
                                Text("Simpan ke Artifact yang Sama")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(Color(hex: "#34D399"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color(hex: "#34D399").opacity(0.16)))
                        }
                        .buttonStyle(.plain)

                        Button(action: { isEditingInline = false }) {
                            Text("Batal")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                        }
                        .buttonStyle(.plain)

                        if let msg = saveStatusMessage {
                            Text(msg)
                                .font(.system(size: 10.5))
                                .foregroundStyle(Color(hex: "#34D399"))
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    if !previewSnippet.isEmpty {
                        Text(previewSnippet)
                            .font(.system(size: 11.5, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(4)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.3)))
                    } else if let summ = deliverable.summary, !summ.isEmpty {
                        Text(summ)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
                    }

                    if !fileSizeFormatted.isEmpty {
                        Text(fileSizeFormatted)
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
            }

            // Action Toolbar: Preview / Revise / Copy Path
            HStack(spacing: 8) {
                // Open File
                Button(action: openArtifact) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 10.5))
                        Text("Buka")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help("Buka berkas artifact secara native")

                // Revise Artifact (In-Place, Zero Duplication)
                Button(action: startRevision) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil.line")
                            .font(.system(size: 10.5))
                        Text("Revisi")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Color(hex: "#38BDF8"))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(hex: "#38BDF8").opacity(0.14)))
                }
                .buttonStyle(.plain)
                .help("Revisi artifact ini langsung tanpa membuat salinan duplikat")

                Spacer()

                // Copy Path
                Button(action: copyArtifactPath) {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10))
                        Text(isCopied ? "Tersalin" : "Salin Path")
                            .font(.system(size: 10.5))
                    }
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: "#111827").opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.8)
                )
        )
        .frame(maxWidth: 540, alignment: .leading)
        .onAppear {
            loadArtifactMetadata()
        }
    }

    private func loadArtifactMetadata() {
        guard let url = artifactURL, FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            fileSizeFormatted = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
        if let content = try? String(contentsOf: url, encoding: .utf8) {
            editedContent = content
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            previewSnippet = String(trimmed.prefix(280))
        }
    }

    private func openArtifact() {
        guard let url = artifactURL, FileManager.default.fileExists(atPath: url.path) else { return }
        NSWorkspace.shared.open(url)
    }

    private func startRevision() {
        if onRevise != nil {
            onRevise?(deliverable.artifact)
        } else {
            NotificationCenter.default.post(
                name: Notification.Name("HomeSpaceReviseArtifact"),
                object: deliverable.artifact
            )
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                isEditingInline.toggle()
            }
        }
    }

    private func saveInlineRevision() {
        guard let url = artifactURL else { return }
        do {
            try editedContent.write(to: url, atomically: true, encoding: .utf8)
            currentVersion += 1
            loadArtifactMetadata()
            saveStatusMessage = "Tersimpan (v\(currentVersion))"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                saveStatusMessage = nil
                isEditingInline = false
            }
        } catch {
            saveStatusMessage = "Gagal menyimpan: \(error.localizedDescription)"
        }
    }

    private func copyArtifactPath() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(deliverable.artifact, forType: .string)
        isCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            isCopied = false
        }
    }
}
// MARK: - HomeSpaceDraftSkillReviewView (PRD §A8, MT-06: Draft Skill Review & Finalization)
public struct HomeSpaceDraftSkillReviewView: View {
    @ObservedObject var teachEngine = CompanionTeachModeEngine.shared

    @State private var skillName: String = ""
    @State private var whenToUse: String = ""
    @State private var steps: [String] = []
    @State private var newStepText: String = ""
    @State private var validationRule: String = ""
    @State private var outputDescription: String = ""
    @State private var approvalBoundary: String = ""
    @State private var isSavedMessage: String? = nil

    public var onDismiss: (() -> Void)? = nil

    public init(onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(hex: "#F59E0B"))

                Text("Tinjau Draft Skill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)

                Text("DRAFT")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(hex: "#F59E0B"))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Capsule().fill(Color(hex: "#F59E0B").opacity(0.18)))

                Spacer()

                Button(action: {
                    teachEngine.cancelTeaching()
                    onDismiss?()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(6)
                        .background(Circle().fill(Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // 1. Nama Skill
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nama Skill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                        TextField("Nama skill...", text: $skillName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
                    }

                    // 2. Kapan Digunakan
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Kapan Digunakan (Trigger Rule)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                        TextField("Kondisi kapan skill ini dieksekusi...", text: $whenToUse)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
                    }

                    // 3. Urutan Langkah Kerja (Recorded Steps)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Urutan Langkah Kerja (\(steps.count) langkah terekam)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))

                        ForEach(steps.indices, id: \.self) { idx in
                            HStack(spacing: 6) {
                                Text("\(idx + 1).")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color(hex: "#38BDF8"))
                                    .frame(width: 20, alignment: .leading)

                                TextField("Langkah...", text: $steps[idx])
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(.white.opacity(0.92))

                                Button(action: { steps.remove(at: idx) }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(7)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.04)))
                        }

                        // Add Step Field
                        HStack(spacing: 6) {
                            TextField("Tambah langkah baru...", text: $newStepText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11))
                                .foregroundStyle(.white)

                            Button(action: {
                                let clean = newStepText.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !clean.isEmpty {
                                    steps.append(clean)
                                    newStepText = ""
                                }
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color(hex: "#38BDF8"))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(7)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.03)))
                    }

                    // 4. Validasi Hasil
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Aturan Validasi")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                        TextField("Kondisi verifikasi keberhasilan...", text: $validationRule)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
                    }

                    // 5. Output
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Output yang Diharapkan")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                        TextField("Format atau artefak output...", text: $outputDescription)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
                    }

                    // 6. Batasan Approval (Approval Boundary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Batasan Approval (Tindakan Wajib Konfirmasi)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(hex: "#F59E0B").opacity(0.8))
                        TextField("Contoh: Pengiriman eksternal, penghapusan...", text: $approvalBoundary)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: "#F59E0B").opacity(0.08)))
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 280)

            // Action Toolbar
            HStack(spacing: 8) {
                // Finalize Button
                Button(action: finalizeSkill) {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11))
                        Text("Finalisasi Skill")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(Color(hex: "#0F172A"))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        Capsule().fill(Color(hex: "#34D399"))
                    )
                }
                .buttonStyle(.plain)

                // Save as Draft Button
                Button(action: saveAsDraft) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 11))
                        Text("Simpan sebagai Draf")
                            .font(.system(size: 11.5, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)

                Spacer()

                if let msg = isSavedMessage {
                    Text(msg)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(hex: "#34D399"))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(hex: "#111827").opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(hex: "#F59E0B").opacity(0.35), lineWidth: 1)
                )
        )
        .frame(maxWidth: 540, alignment: .leading)
        .onAppear {
            populateFromDraft()
        }
    }

    private func populateFromDraft() {
        if let draft = teachEngine.activeDraftSkill {
            skillName = draft.name
            whenToUse = draft.whenToUse
            steps = draft.steps
            validationRule = draft.validation
            outputDescription = draft.output
            approvalBoundary = draft.approvalBoundary.joined(separator: ", ")
        }
    }

    private func compiledSkill(isDraft: Bool) -> CompanionSkill {
        let boundaries = approvalBoundary.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return CompanionSkill(
            name: skillName.isEmpty ? "skill-\(UUID().uuidString.prefix(6))" : skillName,
            whenToUse: whenToUse,
            requiredInputs: [],
            access: ["Desktop Workspace", "Target App"],
            steps: steps,
            validation: validationRule,
            output: outputDescription,
            approvalBoundary: boundaries,
            origin: "teach-mode",
            draft: isDraft
        )
    }

    private func finalizeSkill() {
        let skill = compiledSkill(isDraft: false)
        teachEngine.finalizeDraftSkill(skill)
        isSavedMessage = "Skill difinalisasi!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            onDismiss?()
        }
    }

    private func saveAsDraft() {
        let skill = compiledSkill(isDraft: true)
        CompanionSkillLibrary.shared.saveSkill(skill)
        teachEngine.activeDraftSkill = nil
        isSavedMessage = "Draf tersimpan!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            onDismiss?()
        }
    }
}
