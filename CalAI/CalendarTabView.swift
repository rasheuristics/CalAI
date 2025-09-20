import SwiftUI
import EventKit

enum CalendarViewType: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case year = "Year"
}

struct CalendarTabView: View {
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var fontManager: FontManager
    @State private var selectedDate = Date()
    @State private var currentViewType: CalendarViewType = .month
    @State private var zoomScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero

    var body: some View {
        VStack(spacing: 0) {
                // iOS-style header with view switcher
                CalendarHeaderView(
                    selectedDate: $selectedDate,
                    currentViewType: $currentViewType,
                    fontManager: fontManager
                )

                // Main calendar content
                GeometryReader { geometry in
                    Group {
                        switch currentViewType {
                        case .day:
                            DayCalendarView(
                                selectedDate: $selectedDate,
                                events: calendarManager.events,
                                zoomScale: $zoomScale,
                                offset: $offset
                            )
                        case .week:
                            WeekCalendarView(
                                selectedDate: $selectedDate,
                                events: calendarManager.events,
                                zoomScale: $zoomScale,
                                offset: $offset
                            )
                        case .month:
                            MonthCalendarView(
                                selectedDate: $selectedDate
                            )
                        case .year:
                            YearCalendarView(
                                selectedDate: $selectedDate
                            )
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
    }
}

struct CalendarHeaderView: View {
    @Binding var selectedDate: Date
    @Binding var currentViewType: CalendarViewType
    @ObservedObject var fontManager: FontManager

    var body: some View {
        VStack(spacing: 12) {
            // Top navigation with month/year and view switcher
            HStack {
                // Month/Year display
                VStack(alignment: .leading, spacing: 2) {
                    Text(monthYearText)
                        .dynamicFont(size: 28, weight: .bold, fontManager: fontManager)
                        .foregroundColor(.primary)

                    if currentViewType == .day || currentViewType == .week {
                        Text(currentDateText)
                            .dynamicFont(size: 17, weight: .medium, fontManager: fontManager)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // View type picker
                Picker("View", selection: $currentViewType) {
                    ForEach(CalendarViewType.allCases, id: \.self) { viewType in
                        Text(viewType.rawValue).tag(viewType)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
            }
            .padding(.horizontal)

            // Today button and navigation
            HStack {
                Button("Today") {
                    selectedDate = Date()
                }
                .foregroundColor(.blue)
                .dynamicFont(size: 15, fontManager: fontManager)

                Spacer()

                // Navigation arrows
                HStack(spacing: 20) {
                    Button(action: previousPeriod) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.blue)
                    }

                    Button(action: nextPeriod) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.top, 8)
        .background(Color(.systemBackground))
    }

    private var monthYearText: String {
        let formatter = DateFormatter()
        switch currentViewType {
        case .day, .week, .month:
            formatter.dateFormat = "MMMM yyyy"
        case .year:
            formatter.dateFormat = "yyyy"
        }
        return formatter.string(from: selectedDate)
    }

    private var currentDateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: selectedDate)
    }

    private func previousPeriod() {
        let calendar = Calendar.current
        switch currentViewType {
        case .day:
            selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        case .week:
            selectedDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
        case .month:
            selectedDate = calendar.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
        case .year:
            selectedDate = calendar.date(byAdding: .year, value: -1, to: selectedDate) ?? selectedDate
        }
    }

    private func nextPeriod() {
        let calendar = Calendar.current
        switch currentViewType {
        case .day:
            selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        case .week:
            selectedDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
        case .month:
            selectedDate = calendar.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
        case .year:
            selectedDate = calendar.date(byAdding: .year, value: 1, to: selectedDate) ?? selectedDate
        }
    }
}