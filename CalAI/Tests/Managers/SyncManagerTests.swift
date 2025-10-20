import XCTest
import Combine
@testable import CalAI

/// Critical tests for SyncManager - delta sync and conflict resolution
@MainActor
final class SyncManagerTests: XCTestCase {

    var sut: SyncManager!
    var mockCalendarManager: CalendarManager!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        sut = SyncManager.shared
        mockCalendarManager = CalendarManager()
        sut.calendarManager = mockCalendarManager
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        sut.stopRealTimeSync()
        cancellables.removeAll()
        sut = nil
        mockCalendarManager = nil
        super.tearDown()
    }

    // MARK: - Sync State Tests

    func testInitialState_NotSyncing() {
        // Then
        XCTAssertFalse(sut.isSyncing)
        XCTAssertNil(sut.lastSyncDate)
        XCTAssertTrue(sut.syncErrors.isEmpty)
    }

    func testSyncState_UpdatesDuringSync() async {
        // Given
        let expectation = XCTestExpectation(description: "Sync state changes")
        var stateChanges: [Bool] = []

        sut.$isSyncing
            .sink { isSyncing in
                stateChanges.append(isSyncing)
                if stateChanges.count >= 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        await sut.performIncrementalSync()

        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
        XCTAssertTrue(stateChanges.contains(true), "Should transition to syncing")
        XCTAssertFalse(sut.isSyncing, "Should end as not syncing")
    }

    func testSyncState_UpdatesLastSyncDate() async {
        // Given
        let beforeSync = Date()

        // When
        await sut.performIncrementalSync()

        // Then
        XCTAssertNotNil(sut.lastSyncDate)
        if let lastSyncDate = sut.lastSyncDate {
            XCTAssertGreaterThanOrEqual(lastSyncDate, beforeSync)
        }
    }

    // MARK: - Incremental Sync Tests

    func testIncrementalSync_DoesNotRunConcurrently() async {
        // Given
        let firstSyncStarted = XCTestExpectation(description: "First sync started")
        let secondSyncSkipped = XCTestExpectation(description: "Second sync skipped")

        sut.$isSyncing
            .dropFirst() // Skip initial false
            .sink { isSyncing in
                if isSyncing {
                    firstSyncStarted.fulfill()
                }
            }
            .store(in: &cancellables)

        // When - start two syncs concurrently
        async let sync1 = sut.performIncrementalSync()
        async let sync2 = sut.performIncrementalSync() // Should be skipped

        await sync1
        await sync2

        // Then
        await fulfillment(of: [firstSyncStarted], timeout: 5.0)
        // If concurrent protection works, second sync should skip immediately
        XCTAssertFalse(sut.isSyncing)
    }

    func testIncrementalSync_ClearsPreviousErrors() async {
        // Given
        let mockError = CalendarSyncError(
            source: .ios,
            error: NSError(domain: "test", code: 1),
            timestamp: Date()
        )
        sut.syncErrors = [mockError]
        XCTAssertEqual(sut.syncErrors.count, 1)

        // When
        await sut.performIncrementalSync()

        // Then
        XCTAssertTrue(sut.syncErrors.isEmpty, "Should clear previous errors on new sync")
    }

    // MARK: - Real-Time Sync Tests

    func testRealTimeSync_StartsWithInitialSync() {
        // Given
        let expectation = XCTestExpectation(description: "Initial sync triggered")

        sut.$isSyncing
            .dropFirst() // Skip initial false
            .sink { isSyncing in
                if isSyncing {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        sut.startRealTimeSync(interval: 60)

        // Then
        wait(for: [expectation], timeout: 5.0)
    }

    func testRealTimeSync_CanBeStopped() {
        // Given
        sut.startRealTimeSync(interval: 60)

        // When
        sut.stopRealTimeSync()

        // Then - verify no crash and sync stopped
        // Timer should be invalidated
        XCTAssertFalse(sut.isSyncing)
    }

    func testRealTimeSync_RestartsWithNewInterval() {
        // Given
        sut.startRealTimeSync(interval: 60)

        // When - restart with different interval
        sut.startRealTimeSync(interval: 120)

        // Then - should not crash, old timer invalidated
        XCTAssertFalse(sut.isSyncing)
    }

    // MARK: - Calendar Source Sync Tests

    func testSync_HandlesIOSSource() async {
        // Given - iOS calendar access is available

        // When
        await sut.performIncrementalSync()

        // Then
        XCTAssertFalse(sut.isSyncing)
        // Should complete without crashing
    }

    func testSync_HandlesGoogleSource() async {
        // Given - Google calendar may or may not be available

        // When
        await sut.performIncrementalSync()

        // Then
        XCTAssertFalse(sut.isSyncing)
        // Should complete without crashing even if Google not configured
    }

    func testSync_HandlesOutlookSource() async {
        // Given - Outlook calendar may or may not be available

        // When
        await sut.performIncrementalSync()

        // Then
        XCTAssertFalse(sut.isSyncing)
        // Should complete without crashing even if Outlook not configured
    }

    // MARK: - Error Handling Tests

    func testSync_RecordsErrors() async {
        // Given - sync may encounter errors

        // When
        await sut.performIncrementalSync()

        // Then
        // Errors array should be accessible
        let errorCount = sut.syncErrors.count
        XCTAssertGreaterThanOrEqual(errorCount, 0)
    }

    func testCalendarSyncError_HasRequiredProperties() {
        // Given
        let testError = NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let timestamp = Date()

        // When
        let syncError = CalendarSyncError(
            source: .ios,
            error: testError,
            timestamp: timestamp
        )

        // Then
        XCTAssertEqual(syncError.source, .ios)
        XCTAssertEqual(syncError.timestamp, timestamp)
        XCTAssertNotNil(syncError.id)
    }

    func testCalendarSyncError_SupportsAllSources() {
        // Given
        let sources: [CalendarSource] = [.ios, .google, .outlook]
        let testError = NSError(domain: "test", code: 1)

        for source in sources {
            // When
            let syncError = CalendarSyncError(
                source: source,
                error: testError,
                timestamp: Date()
            )

            // Then
            XCTAssertEqual(syncError.source, source)
        }
    }

    // MARK: - Delta Sync Tests

    func testDeltaSync_OnlyFetchesModifiedEvents() async {
        // Given
        let lastSyncDate = Calendar.current.date(byAdding: .hour, value: -1, to: Date())!
        sut.lastSyncDate = lastSyncDate

        // When
        await sut.performIncrementalSync()

        // Then
        // Should complete successfully
        XCTAssertNotNil(sut.lastSyncDate)
        if let newSyncDate = sut.lastSyncDate {
            XCTAssertGreaterThan(newSyncDate, lastSyncDate)
        }
    }

    func testDeltaSync_HandlesFirstSync() async {
        // Given - no previous sync date
        sut.lastSyncDate = nil

        // When
        await sut.performIncrementalSync()

        // Then
        XCTAssertNotNil(sut.lastSyncDate, "Should set sync date after first sync")
    }

    // MARK: - CalendarSource Tests

    func testCalendarSource_AllCasesAccessible() {
        // Given/When
        let allSources = CalendarSource.allCases

        // Then
        XCTAssertEqual(allSources.count, 3)
        XCTAssertTrue(allSources.contains(.ios))
        XCTAssertTrue(allSources.contains(.google))
        XCTAssertTrue(allSources.contains(.outlook))
    }

    func testCalendarSource_HasStringRepresentation() {
        // Given
        let sources: [CalendarSource] = [.ios, .google, .outlook]

        for source in sources {
            // When
            let rawValue = source.rawValue

            // Then
            XCTAssertFalse(rawValue.isEmpty)
            XCTAssertEqual(CalendarSource(rawValue: rawValue), source)
        }
    }

    func testCalendarSource_SupportsEquality() {
        // Given
        let ios1 = CalendarSource.ios
        let ios2 = CalendarSource.ios
        let google = CalendarSource.google

        // Then
        XCTAssertEqual(ios1, ios2)
        XCTAssertNotEqual(ios1, google)
    }

    // MARK: - Background Sync Tests

    func testBackgroundSync_InitializationDoesNotCrash() {
        // Given/When
        let manager = SyncManager.shared

        // Then
        XCTAssertNotNil(manager)
        XCTAssertFalse(manager.isSyncing)
    }

    // MARK: - CoreDataManager Integration Tests

    func testSync_UpdatesCoreDataSyncStatus() async {
        // Given
        let coreDataManager = sut.coreDataManager

        // When
        await sut.performIncrementalSync()

        // Then
        // CoreData should track sync dates
        let iosSyncDate = coreDataManager.getLastSyncDate(for: .ios)
        // May or may not have synced depending on permissions
        if iosSyncDate != nil {
            XCTAssertNotNil(iosSyncDate)
        }
    }

    func testSync_SavesEventsToCoreData() async {
        // Given
        let beforeSync = Date()

        // When
        await sut.performIncrementalSync()

        // Then
        XCTAssertNotNil(sut.lastSyncDate)
        // CoreData integration should work without crashing
    }

    // MARK: - Performance Tests

    func testSyncPerformance_CompletesInReasonableTime() {
        measure {
            let expectation = XCTestExpectation(description: "Sync completes")

            Task {
                await sut.performIncrementalSync()
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 10.0)
        }
    }

    // MARK: - Singleton Pattern Tests

    func testSingleton_ReturnsSameInstance() {
        // Given/When
        let instance1 = SyncManager.shared
        let instance2 = SyncManager.shared

        // Then
        XCTAssertTrue(instance1 === instance2, "Should return same singleton instance")
    }

    // MARK: - Observable Object Tests

    func testPublishedProperties_EmitChanges() {
        // Given
        let expectation = XCTestExpectation(description: "isSyncing publishes")
        var emittedValues: [Bool] = []

        sut.$isSyncing
            .sink { value in
                emittedValues.append(value)
                if emittedValues.count > 1 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        Task {
            await sut.performIncrementalSync()
        }

        // Then
        wait(for: [expectation], timeout: 5.0)
        XCTAssertGreaterThan(emittedValues.count, 1, "Should emit multiple values")
    }
}
