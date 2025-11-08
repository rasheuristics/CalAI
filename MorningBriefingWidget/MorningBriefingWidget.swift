//
//  MorningBriefingWidget.swift
//  MorningBriefingWidget
//
//  Created by Belachew Tessema on 11/7/25.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> MorningBriefingEntry {
        MorningBriefingEntry(
            date: Date(),
            greeting: "Good Morning",
            weather: nil,
            eventsSummary: "Loading events...",
            nextEvent: nil,
            tasksCount: 0
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (MorningBriefingEntry) -> ()) {
        let weather = SharedWeatherStorage.shared.loadWeather()
        let entry = MorningBriefingEntry(
            date: Date(),
            greeting: getGreeting(),
            weather: weather,
            eventsSummary: "3 events today",
            nextEvent: "Team Meeting at 10:00 AM",
            tasksCount: 5
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [MorningBriefingEntry] = []

        // Load weather from shared storage
        let weather = SharedWeatherStorage.shared.loadWeather()

        // Generate timeline entries for the next 24 hours (update every hour)
        let currentDate = Date()
        for hourOffset in 0 ..< 24 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!

            // In a real implementation, fetch actual calendar data here
            // For now, using placeholder data for events/tasks
            let entry = MorningBriefingEntry(
                date: entryDate,
                greeting: getGreeting(for: entryDate),
                weather: weather,
                eventsSummary: "Check your calendar",
                nextEvent: "No upcoming events",
                tasksCount: 0
            )
            entries.append(entry)
        }

        // Update every hour
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }

    private func getGreeting(for date: Date = Date()) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12:
            return "Good Morning"
        case 12..<17:
            return "Good Afternoon"
        case 17..<22:
            return "Good Evening"
        default:
            return "Good Night"
        }
    }
}

struct MorningBriefingEntry: TimelineEntry {
    let date: Date
    let greeting: String
    let weather: WeatherData?
    let eventsSummary: String
    let nextEvent: String?
    let tasksCount: Int
}

struct MorningBriefingWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        ZStack {
            // Beautiful gradient background matching the app
            LinearGradient(
                colors: [
                    Color(red: 0.4, green: 0.6, blue: 1.0),
                    Color(red: 0.6, green: 0.4, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 10) {
                // Header with greeting and weather
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.greeting)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)

                        if let weather = entry.weather {
                            Text(weather.condition)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }

                    Spacer()

                    // Weather temperature
                    if let weather = entry.weather {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(weather.temperatureFormatted)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)

                            Text(weather.highLowFormatted)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                }

                Divider()
                    .background(Color.white.opacity(0.3))

                // Events summary
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 13))
                    Text(entry.eventsSummary)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundColor(.white.opacity(0.95))

                // Next event
                if let nextEvent = entry.nextEvent {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                        Text(nextEvent)
                            .font(.system(size: 12, weight: .regular))
                            .lineLimit(1)
                    }
                    .foregroundColor(.white.opacity(0.9))
                }

                Spacer()

                // Bottom row: Tasks and weather details
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "checklist")
                            .font(.system(size: 12))
                        Text("\(entry.tasksCount) tasks")
                            .font(.system(size: 12, weight: .medium))
                    }

                    if let weather = entry.weather, weather.precipitationChance > 20 {
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "drop.fill")
                                .font(.system(size: 11))
                            Text("\(weather.precipitationChance)%")
                                .font(.system(size: 11))
                        }
                    }
                }
                .foregroundColor(.white.opacity(0.95))
            }
            .padding(14)
        }
        .widgetURL(URL(string: "calai://morning-briefing"))
    }
}

struct MorningBriefingWidget: Widget {
    let kind: String = "MorningBriefingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                MorningBriefingWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                MorningBriefingWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Morning Briefing")
        .description("Your daily calendar overview and upcoming events")
        .supportedFamilies([.systemSmall, .systemMedium])
        // Add deep link URL so tapping widget opens the Morning Briefing screen
        .onBackgroundURLSessionEvents { sessionIdentifier, completion in
            completion()
        }
    }
}

#Preview(as: .systemSmall) {
    MorningBriefingWidget()
} timeline: {
    MorningBriefingEntry(
        date: .now,
        greeting: "Good Morning",
        weather: WeatherData(
            temperature: 72,
            feelsLike: 70,
            condition: "Partly Cloudy",
            conditionDescription: "Partly Cloudy",
            high: 75,
            low: 68,
            precipitationChance: 30,
            humidity: 65,
            windSpeed: 5.5,
            icon: "02d"
        ),
        eventsSummary: "3 events today",
        nextEvent: "Team Meeting at 10:00 AM",
        tasksCount: 5
    )
    MorningBriefingEntry(
        date: .now,
        greeting: "Good Afternoon",
        weather: WeatherData(
            temperature: 75,
            feelsLike: 73,
            condition: "Sunny",
            conditionDescription: "Sunny",
            high: 78,
            low: 68,
            precipitationChance: 10,
            humidity: 55,
            windSpeed: 4.2,
            icon: "01d"
        ),
        eventsSummary: "2 events remaining",
        nextEvent: "Coffee with Sarah at 2:00 PM",
        tasksCount: 3
    )
}
