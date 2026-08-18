import Foundation

public struct LocalVoiceOverBuilder: Sendable {
    public static func numberToIndonesianWords(_ n: Int) -> String {
        let units = ["nol", "satu", "dua", "tiga", "empat", "lima", "enam", "tujuh", "delapan", "sembilan", "sepuluh", "sebelas"]
        if n < 12 && n >= 0 { return units[n] }
        if n < 20 { return "\(units[n - 10]) belas" }
        if n < 100 {
            let tens = n / 10
            let rem = n % 10
            return rem == 0 ? "\(units[tens]) puluh" : "\(units[tens]) puluh \(units[rem])"
        }
        return "\(n)"
    }

    public static func buildScript(title: String, offsetMinutes: Int) -> String {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if offsetMinutes <= 0 {
            return "Pengingat: Agenda \(cleanTitle) dimulai sekarang."
        } else {
            let offsetWords = numberToIndonesianWords(offsetMinutes)
            return "Pengingat: Agenda \(cleanTitle) akan dimulai dalam \(offsetWords) menit."
        }
    }
}
