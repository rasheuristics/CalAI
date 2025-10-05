import XCTest
import SwiftUI
@testable import CalAI

final class DesignSystemTests: XCTestCase {

    // MARK: - Color Tests

    func testCalendarSourceColors() {
        // Test iOS calendar color
        let iosColor = DesignSystem.Colors.forCalendarSource(.ios)
        XCTAssertNotNil(iosColor)
        XCTAssertEqual(iosColor, DesignSystem.Colors.iOSCalendar)

        // Test Google calendar color
        let googleColor = DesignSystem.Colors.forCalendarSource(.google)
        XCTAssertNotNil(googleColor)
        XCTAssertEqual(googleColor, DesignSystem.Colors.googleCalendar)

        // Test Outlook calendar color
        let outlookColor = DesignSystem.Colors.forCalendarSource(.outlook)
        XCTAssertNotNil(outlookColor)
        XCTAssertEqual(outlookColor, DesignSystem.Colors.outlookCalendar)
    }

    func testColorsAreUnique() {
        // Verify each calendar source has a distinct color
        let iosColor = DesignSystem.Colors.iOSCalendar
        let googleColor = DesignSystem.Colors.googleCalendar
        let outlookColor = DesignSystem.Colors.outlookCalendar

        XCTAssertNotEqual(iosColor, googleColor)
        XCTAssertNotEqual(googleColor, outlookColor)
        XCTAssertNotEqual(iosColor, outlookColor)
    }

    // MARK: - Spacing Tests

    func testSpacingHierarchy() {
        // Verify spacing values are in ascending order
        XCTAssertLessThan(DesignSystem.Spacing.xxs, DesignSystem.Spacing.xs)
        XCTAssertLessThan(DesignSystem.Spacing.xs, DesignSystem.Spacing.sm)
        XCTAssertLessThan(DesignSystem.Spacing.sm, DesignSystem.Spacing.md)
        XCTAssertLessThan(DesignSystem.Spacing.md, DesignSystem.Spacing.lg)
        XCTAssertLessThan(DesignSystem.Spacing.lg, DesignSystem.Spacing.xl)
        XCTAssertLessThan(DesignSystem.Spacing.xl, DesignSystem.Spacing.xxl)
    }

    func testSpacingValues() {
        // Verify specific spacing values
        XCTAssertEqual(DesignSystem.Spacing.xxs, 4)
        XCTAssertEqual(DesignSystem.Spacing.xs, 8)
        XCTAssertEqual(DesignSystem.Spacing.sm, 12)
        XCTAssertEqual(DesignSystem.Spacing.md, 16)
        XCTAssertEqual(DesignSystem.Spacing.lg, 24)
        XCTAssertEqual(DesignSystem.Spacing.xl, 32)
        XCTAssertEqual(DesignSystem.Spacing.xxl, 48)
    }

    // MARK: - Corner Radius Tests

    func testCornerRadiusHierarchy() {
        // Verify corner radius values are in ascending order
        XCTAssertLessThan(DesignSystem.CornerRadius.xs, DesignSystem.CornerRadius.sm)
        XCTAssertLessThan(DesignSystem.CornerRadius.sm, DesignSystem.CornerRadius.md)
        XCTAssertLessThan(DesignSystem.CornerRadius.md, DesignSystem.CornerRadius.lg)
        XCTAssertLessThan(DesignSystem.CornerRadius.lg, DesignSystem.CornerRadius.xl)
        XCTAssertLessThan(DesignSystem.CornerRadius.xl, DesignSystem.CornerRadius.xxl)
    }

    func testRoundCornerRadius() {
        // Verify round corner radius is very large for circular elements
        XCTAssertEqual(DesignSystem.CornerRadius.round, 999)
    }

    // MARK: - Shadow Tests

    func testShadowStyles() {
        // Test small shadow
        let small = DesignSystem.Shadow.small
        XCTAssertEqual(small.radius, 4)
        XCTAssertEqual(small.y, 2)

        // Test medium shadow
        let medium = DesignSystem.Shadow.medium
        XCTAssertEqual(medium.radius, 8)
        XCTAssertEqual(medium.y, 4)

        // Test large shadow
        let large = DesignSystem.Shadow.large
        XCTAssertEqual(large.radius, 12)
        XCTAssertEqual(large.y, 6)

        // Test error shadow
        let error = DesignSystem.Shadow.error
        XCTAssertEqual(error.radius, 8)
        XCTAssertEqual(error.y, 4)
    }

    func testShadowIntensityProgression() {
        // Verify shadow radius increases with size
        let small = DesignSystem.Shadow.small
        let medium = DesignSystem.Shadow.medium
        let large = DesignSystem.Shadow.large

        XCTAssertLessThan(small.radius, medium.radius)
        XCTAssertLessThan(medium.radius, large.radius)
    }

    // MARK: - Animation Tests

    func testAnimationDurations() {
        // Note: SwiftUI animations can't be directly compared,
        // but we can verify they're defined
        let quick = DesignSystem.Animation.quick
        let standard = DesignSystem.Animation.standard
        let slow = DesignSystem.Animation.slow
        let spring = DesignSystem.Animation.spring

        XCTAssertNotNil(quick)
        XCTAssertNotNil(standard)
        XCTAssertNotNil(slow)
        XCTAssertNotNil(spring)
    }
}
