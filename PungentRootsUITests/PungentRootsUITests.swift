//
//  PungentRootsUITests.swift
//  PungentRootsUITests
//
//  Created by Patrick Brown on 9/17/25.
//

import XCTest

final class PungentRootsUITests: XCTestCase {
    private func launchApp(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: arguments)
        app.launch()
        return app
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchArguments.append("--ui-test-disable-capture")
            app.launch()
        }
    }

    @MainActor
    func testSettingsSupportsDynamicType() throws {
        let app = launchApp(
            arguments: [
                "--ui-test-disable-capture",
                "--ui-test-open-settings",
                "-UIPreferredContentSizeCategoryName",
                "UICTContentSizeCategoryAccessibility3"
            ]
        )

        let navBar = app.navigationBars["Info & Settings"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 3))

        XCTAssertTrue(app.staticTexts["Scan Quality"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Full-label still capture"].exists)

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Settings-DynamicType-AX3"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testPreviewResultSupportsTranscriptDisclosure() throws {
        let app = launchApp(arguments: ["--ui-test-disable-capture", "--ui-test-preview-result"])

        let toggle = app.buttons["toggle-scanned-text"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        toggle.tap()

        XCTAssertTrue(app.staticTexts["Hide scanned text"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "onion powder")).firstMatch.exists)
    }

    @MainActor
    func testRetakeReturnsToFramingState() throws {
        let app = launchApp(arguments: ["--ui-test-disable-capture", "--ui-test-preview-result"])

        let retakeButton = app.buttons["retake-label-button"]
        XCTAssertTrue(retakeButton.waitForExistence(timeout: 3))
        retakeButton.tap()

        XCTAssertTrue(app.buttons["analyze-label-button"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["toggle-scanned-text"].exists)
        XCTAssertTrue(app.staticTexts["Capture the Whole Ingredient Panel"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testPartialResultShowsIncompleteWarning() throws {
        let app = launchApp(arguments: ["--ui-test-disable-capture", "--ui-test-preview-partial-result"])

        XCTAssertTrue(app.staticTexts["Only partial packaging text was read"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "Retake the photo")).firstMatch.exists)
        XCTAssertTrue(app.buttons["retake-label-button"].exists)
    }
}
