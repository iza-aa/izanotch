//
//  MiniMonthCalendarView.swift
//  izaNotch
//
//  Created for boringNotch Home Tab Dashboard.
//

import SwiftUI

struct MiniMonthCalendarView: View {
    @State private var displayedMonth: Date = Date()
    @State private var hoveredDate: Date? = nil

    private let calendar = Calendar.current
    private let daysOfWeek = ["S", "M", "T", "W", "T", "F", "S"]

    private var monthYearFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }

    var body: some View {
        ZStack {
            // Background Card matching Music Album Art geometry
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.6), Color.black.opacity(0.38)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.45), radius: 4, x: 0, y: 2)

            VStack(spacing: 5) {
                // 1. Month & Year Header with navigation
                HStack(alignment: .center) {
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            displayedMonth = Date()
                        }
                    }) {
                        Text(monthYearFormatter.string(from: displayedMonth))
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()

                    HStack(spacing: 6) {
                        Button(action: {
                            changeMonth(by: -1)
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 16, height: 16)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: {
                            changeMonth(by: 1)
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 16, height: 16)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 7)

                // 2. Day of Week Header (S M T W T F S)
                HStack(spacing: 0) {
                    ForEach(daysOfWeek, id: \.self) { day in
                        Text(day)
                            .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.45))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 6)

                // 3. Month Date Grid
                let days = generateDaysInMonth(for: displayedMonth)
                VStack(spacing: 1.8) {
                    ForEach(0..<days.count / 7, id: \.self) { weekIndex in
                        HStack(spacing: 0) {
                            ForEach(0..<7, id: \.self) { dayIndex in
                                let date = days[weekIndex * 7 + dayIndex]
                                dayCell(date: date)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 6)
            }
        }
    }

    @ViewBuilder
    private func dayCell(date: Date) -> some View {
        let isCurrentMonth = calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
        let isToday = calendar.isDateInToday(date)
        let dayNumber = calendar.component(.day, from: date)

        ZStack {
            if isToday {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 15.5, height: 15.5)
                    .shadow(color: Color.blue.opacity(0.6), radius: 3)
            } else if hoveredDate == date {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 15.5, height: 15.5)
            }

            Text("\(dayNumber)")
                .font(.system(size: 9, weight: isToday ? .bold : .medium, design: .rounded))
                .foregroundColor(
                    isToday ? .white : (isCurrentMonth ? .white.opacity(0.85) : .white.opacity(0.22))
                )
        }
        .frame(height: 12)
        .contentShape(Rectangle())
        .onHover { isHover in
            hoveredDate = isHover ? date : nil
        }
    }

    private func changeMonth(by amount: Int) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
            if let newDate = calendar.date(byAdding: .month, value: amount, to: displayedMonth) {
                displayedMonth = newDate
            }
        }
    }

    private func generateDaysInMonth(for date: Date) -> [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else { return [] }
        let startOfMonth = monthInterval.start

        // Find weekday of the 1st of month (1 is Sunday in standard Gregorian)
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let leadingDays = firstWeekday - 1

        var days: [Date] = []

        // Leading days from previous month
        for i in (1...leadingDays).reversed() {
            if let prevDate = calendar.date(byAdding: .day, value: -i, to: startOfMonth) {
                days.append(prevDate)
            }
        }

        // Current month days
        guard let range = calendar.range(of: .day, in: .month, for: date) else { return days }
        for i in 0..<range.count {
            if let currentDay = calendar.date(byAdding: .day, value: i, to: startOfMonth) {
                days.append(currentDay)
            }
        }

        // Trailing days from next month to complete 5 or 6 rows (multiple of 7)
        let totalCells = (days.count <= 35) ? 35 : 42
        let trailingDays = totalCells - days.count
        if let lastDay = days.last {
            for i in 1...trailingDays {
                if let nextDate = calendar.date(byAdding: .day, value: i, to: lastDay) {
                    days.append(nextDate)
                }
            }
        }

        return days
    }
}
