import XCTest

final class CalendarFocusUITests: XCTestCase {
    func testSelectingHabitsFiltersTheMonth() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-hasCompletedOnboarding", "YES",
            "-seedPreviewData", "YES",
            "-bootTab", "calendar",
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Tap a habit to see your consistency."].waitForExistence(timeout: 8))

        let pill = app.buttons["Take morning pill"]
        let meds = app.buttons["Evening meds"]
        XCTAssertTrue(pill.waitForExistence(timeout: 4))
        XCTAssertTrue(meds.waitForExistence(timeout: 4))

        let yesterday = app.descendants(matching: .any)["day-\(dayKey(daysAgo: 1))"]
        XCTAssertTrue(yesterday.waitForExistence(timeout: 4))

        XCTAssertTrue(waitUntil(yesterday, contains: "#007AFF"))
        XCTAssertTrue(waitUntil(yesterday, contains: "#34C759"))

        pill.tap()
        XCTAssertTrue(pill.isSelected)
        XCTAssertTrue(waitUntil(yesterday, contains: "#007AFF", excludes: "#34C759"))

        meds.tap()
        XCTAssertTrue(pill.isSelected)
        XCTAssertTrue(meds.isSelected)
        XCTAssertTrue(waitUntil(yesterday, contains: "#007AFF", excludes: "#34C759"))

        pill.tap()
        XCTAssertFalse(pill.isSelected)
        XCTAssertTrue(meds.isSelected)
        XCTAssertTrue(waitUntil(yesterday, equals: ""))

        meds.tap()
        XCTAssertFalse(pill.isSelected)
        XCTAssertFalse(meds.isSelected)
        XCTAssertTrue(waitUntil(yesterday, contains: "#007AFF"))
        XCTAssertTrue(waitUntil(yesterday, contains: "#34C759"))
    }

    private func dayKey(daysAgo: Int) -> String {
        let day = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: day)
    }

    private func waitUntil(
        _ element: XCUIElement,
        contains: String? = nil,
        excludes: String? = nil,
        equals: String? = nil
    ) -> Bool {
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            let value = (element.value as? String) ?? ""
            let containsOK = contains.map { value.contains($0) } ?? true
            let excludesOK = excludes.map { !value.contains($0) } ?? true
            let equalsOK = equals.map { value == $0 } ?? true
            if containsOK && excludesOK && equalsOK { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        }
        return false
    }
}
