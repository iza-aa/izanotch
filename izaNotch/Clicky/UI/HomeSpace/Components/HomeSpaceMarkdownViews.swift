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
