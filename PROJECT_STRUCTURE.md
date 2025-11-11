# CalAI Project Structure

This document outlines the actual iOS project structure.

**Note:** This structure is functional but not fully organized. Core files remain in the root directory for historical reasons. Future refactoring may move them into `App/`, `Core/Managers/`, and `Core/Data/` subdirectories.

## Directory Structure

```
CalAI/
├── [ROOT]/                          # App lifecycle, core managers & data
│   ├── CalAIApp.swift               # App entry point
│   ├── ContentView.swift            # Root content view (with tab navigation)
│   ├── Config.swift                 # App configuration & feature flags
│   ├── IntentClassifier.swift       # AI intent classification
│   ├── DayCalendarView.swift        # Day view component
│   │
│   ├── CalendarManager.swift        # Core manager classes (12 files)
│   ├── AIManager.swift
│   ├── FontManager.swift
│   ├── AppearanceManager.swift
│   ├── HapticManager.swift
│   ├── SyncManager.swift
│   ├── DeltaSyncManager.swift
│   ├── CrossDeviceSyncManager.swift
│   ├── ConflictResolutionManager.swift
│   ├── WebhookManager.swift
│   ├── EventTasksSystem.swift
│   ├── GestureHandler.swift
│   │
│   ├── CoreDataManager.swift        # Core Data stack (6 files)
│   ├── CalAIDataModel.xcdatamodeld
│   ├── CachedEvent+CoreDataClass.swift
│   ├── CachedEvent+CoreDataProperties.swift
│   ├── CalendarSyncStatus+CoreDataClass.swift
│   └── CalendarSyncStatus+CoreDataProperties.swift
│
├── Features/                        # Feature modules (organized by domain)
│   │
│   ├── AI/                          # AI assistant feature
│   │   └── Views/
│   │       └── AITabView.swift
│   │
│   ├── Calendar/                    # Calendar feature
│   │   ├── Views/
│   │   │   ├── CalendarTabView.swift
│   │   │   ├── WeekCalendarView.swift
│   │   │   ├── MonthCalendarView.swift
│   │   │   └── YearCalendarView.swift
│   │   └── CalendarCommand.swift
│   │
│   ├── Events/                      # Events management
│   │   ├── Models/
│   │   └── Views/
│   │       ├── AddEventView.swift
│   │       ├── EditEventView.swift
│   │       ├── EventShareTabView.swift
│   │       └── ConflictResolutionView.swift
│   │
│   ├── Focus/                       # Focus mode feature
│   │   └── Views/
│   │
│   ├── Insights/                    # Analytics & insights
│   │   ├── Models/
│   │   ├── ViewModels/
│   │   │   └── InsightsViewModel.swift
│   │   └── Views/
│   │       └── InsightsView.swift
│   │
│   ├── MorningBriefing/            # Morning briefing feature
│   │   ├── Views/
│   │   │   ├── MorningBriefingScreen.swift
│   │   │   └── MorningBriefingSettingsView.swift
│   │   ├── MorningBriefingService.swift
│   │   ├── WeatherService.swift
│   │   └── MorningBriefing.swift
│   │
│   ├── PostMeeting/                # Post-meeting features (Phase 12 - ✅ ENABLED)
│   │   ├── Views/
│   │   │   ├── ActionItemsView.swift
│   │   │   ├── MeetingFollowUpView.swift
│   │   │   ├── MeetingPreparationView.swift
│   │   │   ├── PostMeetingSummaryView.swift
│   │   │   └── SmartReschedulingView.swift
│   │   ├── PostMeetingService.swift
│   │   ├── MeetingFollowUp.swift
│   │   ├── MeetingPreparation.swift
│   │   └── SmartRescheduling.swift
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
│   └── Tasks/                       # Task management feature
│       └── Views/
│           └── InboxView.swift
│
├── Models/                          # Shared data models
│   ├── AppError.swift
│   ├── NotificationPreferences.swift
│   └── WidgetSharedModels.swift
│
├── Services/                        # External services & APIs (40+ services)
│   ├── GoogleCalendarManager.swift
│   ├── OutlookCalendarManager.swift
│   ├── AnalyticsService.swift
│   ├── ConversationalAIService.swift
│   ├── ConversationContextManager.swift
│   ├── NaturalLanguageParser.swift
│   ├── SmartNotificationManager.swift
│   ├── CrashReporter.swift
│   ├── AppLaunchOptimizer.swift
│   ├── CacheManager.swift
│   ├── MeetingAnalyzer.swift
│   ├── OfflineModeManager.swift
│   ├── SmartConflictDetector.swift
│   ├── SmartSuggestionsService.swift
│   ├── SyncQueueManager.swift
│   ├── TravelTimeManager.swift
│   └── [30+ other services]
│
├── Utilities/                       # Helper utilities & extensions
│   ├── SecureStorage.swift
│   ├── DesignSystem.swift
│   ├── EventICSExporter.swift
│   ├── QRCodeGenerator.swift
│   ├── EventFilterService.swift
│   ├── PerformanceMonitor.swift
│   └── MemoryMonitor.swift
│
├── Views/                          # Shared/Common views
│   └── Common/
│       ├── EmptyStateView.swift
│       ├── ErrorBannerView.swift
│       ├── ErrorRecoveryView.swift
│       ├── LoadingSkeletonView.swift
│       ├── OnboardingView.swift
│       ├── InitializationView.swift
│       └── PerformanceOverlay.swift
│
├── Resources/                      # Assets & resources
│   ├── Assets.xcassets/
│   │   ├── AppIcon.appiconset
│   │   ├── AITabIcon.imageset
│   │   └── AccentColor.colorset
│   └── Preview Content/
│       └── Preview Assets.xcassets
│
├── SupportingFiles/               # Configuration files
│   ├── Info.plist
│   └── CalAI.entitlements
│
└── Tests/                         # Unit & UI tests
    ├── Helpers/
    ├── Managers/
    ├── Mocks/
    ├── EventFilterServiceTests.swift
    ├── DesignSystemTests.swift
    ├── CrashReporterTests.swift
    ├── AppErrorTests.swift
    ├── MeetingAnalyzerTests.swift
    └── NotificationPreferencesTests.swift
```

## Organization Principles

### 1. **Feature-Based Organization**
   - Each major feature has its own directory under `Features/`
   - Contains related views, view models, and feature-specific models
   - Currently implemented: AI, Calendar, Events, Focus, Insights, MorningBriefing, PostMeeting, Settings, Tasks
   - Promotes modularity and easier navigation

### 2. **Core Infrastructure in Root**
   - **Note:** Core managers and data files currently in root directory (not in `Core/`)
   - This is a known deviation from ideal structure but functional
   - 22 core files including managers, app lifecycle, and Core Data stack
   - Shared across all features

### 3. **Service Layer**
   - External services (Google, Outlook) in `Services/`
   - Platform services (Analytics, Notifications, AI) centralized
   - 40+ service files
   - Easy to mock for testing

### 4. **Shared Resources**
   - Common views in `Views/Common/`
   - Shared models in `Models/`
   - Utilities in `Utilities/` accessible to all features
   - Widget shared models for app-widget communication

### 5. **Dependencies**
   - Features depend on core managers (in root), not on each other
   - Services are injected via `@StateObject` and `@ObservedObject`
   - Models are shared but follow value semantics

## Current State

### ✅ Well Organized
- Feature modules cleanly separated
- Services layer properly isolated
- Shared utilities and views accessible
- Tests organized by category

### ⚠️ Needs Improvement
- 22 core files in root directory (should be in `App/`, `Core/Managers/`, `Core/Data/`)
- Some monster files: AIManager (4,785 lines), CalendarManager (4,059 lines)
- Test coverage at 8.6% (target: 70%+)

## Benefits of Current Structure

- **Working Build**: Zero compilation errors
- **Feature Isolation**: Easy to work on individual features
- **Service Abstraction**: External APIs cleanly separated
- **Widget Support**: Proper app group configuration for widget extension
- **Testability**: Test files organized with helpers and mocks

## Future Refactoring Considerations

If reorganizing core files from root to subdirectories:
1. Create `App/`, `Core/Managers/`, `Core/Data/` directories in Xcode
2. Move files via Xcode (not Finder) to maintain project references
3. Update all import statements if needed
4. Verify build targets and test memberships
5. Run full test suite after migration
6. **Risk:** High effort, low functional benefit - prioritize after production launch

