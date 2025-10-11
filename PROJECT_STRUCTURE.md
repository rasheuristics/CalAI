# CalAI Project Structure

This document outlines the organized iOS project structure following industry best practices.

## Directory Structure

```
CalAI/
├── App/                              # Application lifecycle & configuration
│   ├── CalAIApp.swift               # App entry point
│   ├── ContentView.swift            # Root content view
│   └── Config.swift                 # App configuration
│
├── Core/                            # Core business logic & infrastructure
│   ├── Managers/                    # Core manager classes
│   │   ├── CalendarManager.swift
│   │   ├── AIManager.swift
│   │   ├── FontManager.swift
│   │   ├── AppearanceManager.swift
│   │   ├── HapticManager.swift
│   │   ├── SyncManager.swift
│   │   ├── DeltaSyncManager.swift
│   │   ├── CrossDeviceSyncManager.swift
│   │   ├── ConflictResolutionManager.swift
│   │   ├── WebhookManager.swift
│   │   ├── EventTasksSystem.swift
│   │   └── GestureHandler.swift
│   │
│   └── Data/                        # Core Data stack
│       ├── CoreDataManager.swift
│       ├── CalAIDataModel.xcdatamodeld
│       ├── CachedEvent+CoreDataClass.swift
│       ├── CachedEvent+CoreDataProperties.swift
│       ├── CalendarSyncStatus+CoreDataClass.swift
│       └── CalendarSyncStatus+CoreDataProperties.swift
│
├── Features/                        # Feature modules (organized by domain)
│   │
│   ├── Calendar/                    # Calendar feature
│   │   ├── Views/
│   │   │   ├── CalendarTabView.swift
│   │   │   ├── WeekCalendarView.swift
│   │   │   ├── MonthCalendarView.swift
│   │   │   └── YearCalendarView.swift
│   │   └── CalendarCommand.swift
│   │
│   ├── AI/                          # AI assistant feature
│   │   ├── Views/
│   │   │   └── AITabView.swift
│   │   └── VoiceManager.swift
│   │
│   ├── Events/                      # Events management
│   │   └── Views/
│   │       ├── EventsTabView.swift
│   │       ├── AddEventView.swift
│   │       ├── EditEventView.swift
│   │       ├── EventShareView.swift
│   │       └── ConflictResolutionView.swift
│   │
│   ├── Settings/                    # Settings & configuration
│   │   └── Views/
│   │       ├── SettingsTabView.swift
│   │       ├── AdvancedSettingsView.swift
│   │       ├── AnalyticsSettingsView.swift
│   │       ├── NotificationSettingsView.swift
│   │       ├── CrashReportingSettingsView.swift
│   │       ├── SyncStatusView.swift
│   │       └── ConflictWarningView.swift
│   │
│   ├── MorningBriefing/            # Morning briefing feature
│   │   ├── Views/
│   │   │   ├── MorningBriefingView.swift
│   │   │   └── MorningBriefingSettingsView.swift
│   │   ├── MorningBriefingService.swift
│   │   ├── WeatherService.swift
│   │   └── MorningBriefing.swift (model)
│   │
│   └── PostMeeting/                # Post-meeting features (Phase 12 - currently disabled)
│       ├── Views/
│       │   ├── ActionItemsView.swift
│       │   ├── MeetingFollowUpView.swift
│       │   ├── MeetingPreparationView.swift
│       │   ├── PostMeetingSummaryView.swift
│       │   └── SmartReschedulingView.swift
│       ├── PostMeetingService.swift
│       ├── MeetingFollowUp.swift (model)
│       ├── MeetingPreparation.swift (model)
│       └── SmartRescheduling.swift (model)
│
├── Models/                          # Shared data models
│   ├── AppError.swift
│   └── NotificationPreferences.swift
│
├── Services/                        # External services & APIs
│   ├── GoogleCalendarManager.swift
│   ├── OutlookCalendarManager.swift
│   ├── AnalyticsService.swift
│   ├── AppLaunchOptimizer.swift
│   ├── AssetOptimizer.swift
│   ├── CacheManager.swift
│   ├── CalendarAnalyticsService.swift
│   ├── CoreDataPerformanceOptimizer.swift
│   ├── CrashReporter.swift
│   ├── ErrorRecoveryManager.swift
│   ├── MeetingAnalyzer.swift
│   ├── NaturalLanguageParser.swift
│   ├── OfflineModeManager.swift
│   ├── SmartConflictDetector.swift
│   ├── SmartNotificationManager.swift
│   ├── SmartSuggestionsService.swift
│   ├── SyncQueueManager.swift
│   ├── TravelTimeManager.swift
│   └── TutorialCoordinator.swift
│
├── Utilities/                       # Helper utilities & extensions
│   ├── EventICSExporter.swift
│   ├── QRCodeGenerator.swift
│   ├── SecureStorage.swift
│   ├── DesignSystem.swift
│   ├── CrashReporter.swift
│   └── EventFilterService.swift
│
├── Views/                          # Shared/Common views
│   └── Common/
│       ├── EmptyStateView.swift
│       ├── ErrorBannerView.swift
│       ├── ErrorRecoveryView.swift
│       ├── LoadingSkeletonView.swift
│       ├── TooltipView.swift
│       └── OnboardingView.swift
│
├── Resources/                      # Assets & resources
│   ├── Assets.xcassets
│   ├── Fonts/
│   └── Preview Content/
│
├── SupportingFiles/               # Configuration files
│   ├── Info.plist
│   └── CalAI.entitlements
│
└── Tests/                         # Unit & UI tests
    ├── EventFilterServiceTests.swift
    ├── DesignSystemTests.swift
    ├── CrashReporterTests.swift
    ├── AppErrorTests.swift
    ├── MeetingAnalyzerTests.swift
    └── NotificationPreferencesTests.swift
```

## Organization Principles

### 1. **Feature-Based Organization**
   - Each major feature has its own directory
   - Contains related views, view models, and feature-specific models
   - Promotes modularity and easier navigation

### 2. **Core Infrastructure Separation**
   - Core managers and data layer separated from features
   - Shared across all features
   - Easy to test and maintain

### 3. **Service Layer**
   - External services (Google, Outlook) isolated
   - Platform services (Analytics, Notifications) centralized
   - Easy to mock for testing

### 4. **Shared Resources**
   - Common views in Views/Common
   - Shared models in Models/
   - Utilities accessible to all features

### 5. **Clean Dependencies**
   - Features depend on Core, not on each other
   - Services are injected, not directly accessed
   - Models are shared but immutable

## Benefits

- **Scalability**: Easy to add new features
- **Maintainability**: Clear boundaries between components
- **Testability**: Isolated components easier to test
- **Collaboration**: Team members can work on separate features
- **Navigation**: Quick to find relevant code

## Migration Notes

After reorganizing, update:
1. Xcode project file references
2. Import statements in Swift files
3. Build phase configurations
4. Test target memberships

