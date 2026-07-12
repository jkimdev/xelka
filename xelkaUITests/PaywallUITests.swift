//
//  PaywallUITests.swift
//  xelkaUITests
//
//  Verifies the free-tier gating actually routes to the paywall at runtime:
//  the crown entry point is present, and tapping a locked premium style opens
//  the upgrade sheet. (The purchase transaction itself is validated manually in
//  Xcode with the StoreKit configuration.)
//

import XCTest

final class PaywallUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLockedStyleAndCrownOpenPaywall() throws {
        let app = XCUIApplication()
        app.launch()

        // A free user sees the crown upgrade entry point.
        XCTAssertTrue(app.buttons["Pro"].waitForExistence(timeout: 10),
                      "Crown 'Pro' button should be visible for a free user")

        // Tapping a locked premium style opens the paywall.
        let lockedStyle = app.buttons["Sweetie 16"]
        XCTAssertTrue(lockedStyle.waitForExistence(timeout: 5),
                      "The Sweetie 16 style chip should exist")
        lockedStyle.tap()

        XCTAssertTrue(app.staticTexts["xelka Pro"].waitForExistence(timeout: 5),
                      "Tapping a locked style should present the xelka Pro paywall")

        let unlock = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Unlock Pro'")
        ).firstMatch
        XCTAssertTrue(unlock.waitForExistence(timeout: 5),
                      "Paywall should show the Unlock Pro purchase button")
    }
}
