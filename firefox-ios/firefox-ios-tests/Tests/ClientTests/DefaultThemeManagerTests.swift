// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import XCTest
@testable import Common

final class DefaultThemeManagerTests: XCTestCase {
    // MARK: - Variables

    private var userDefaults: MockUserDefaults!

    // MARK: - Test lifecycle
    override func setUp() {
        super.setUp()
        userDefaults = MockUserDefaults()
    }

    override func tearDown() {
        super.tearDown()
        userDefaults = nil
    }

    // MARK: - Initialization tests
    func test_mockDefaultsInitializesEmpty() {
        XCTAssert(
            userDefaults.savedData.isEmpty,
            "savedData should be empty when initializing object"
        )

        XCTAssert(
            userDefaults.registrationDictionary.isEmpty,
            "registrationDictionary should be empty when initializing object"
        )
    }

    func test_sutInitializesWithExpectedRegisteredValues() {
        _ = createSubject(with: userDefaults)
        let expectedSystemResult = true
        let expectedNightModeResult = NSNumber(value: false)
        let expectedPrivateModeResult = false

        XCTAssertEqual(userDefaults.registrationDictionary.count, 3)

        guard let systemResult = userDefaults.registrationDictionary["prefKeySystemThemeSwitchOnOff"] as? Bool,
              let nightModeResult = userDefaults.registrationDictionary["profile.NightModeStatus"] as? NSNumber,
              let privateModeResult = userDefaults.registrationDictionary["profile.PrivateModeStatus"] as? Bool
        else {
            XCTFail("Failed to fetch one or more expected keys")
            return
        }

        XCTAssertEqual(systemResult, expectedSystemResult)
        XCTAssertEqual(nightModeResult, expectedNightModeResult)
        XCTAssertEqual(privateModeResult, expectedPrivateModeResult)
    }

    func testDTM_onInitialization_hasLightTheme() {
        let sut = createSubject(with: userDefaults)

        let expectedResult = ThemeType.light

        XCTAssertEqual(sut.currentTheme.type, expectedResult)
    }

    // MARK: - Changing current theme tests

    func testDTM_changeToDarkTheme_changesToDarkTheme() {
        let sut = createSubject(with: userDefaults)
        let expectedResult = ThemeType.dark

        sut.changeCurrentTheme(.dark)

        XCTAssertEqual(sut.currentTheme.type, expectedResult)
        XCTAssertEqual(
            userDefaults.string(forKey: DefaultThemeManager.ThemeKeys.themeName),
            expectedResult.rawValue
        )
    }

    func testDTM_changeToLightTheme_changesToLightTheme() {
        let sut = createSubject(with: userDefaults)
        let expectedResult = ThemeType.light

        sut.changeCurrentTheme(.dark)
        sut.changeCurrentTheme(.light)

        XCTAssertEqual(sut.currentTheme.type, expectedResult)
        XCTAssertEqual(
            userDefaults.string(forKey: DefaultThemeManager.ThemeKeys.themeName),
            expectedResult.rawValue
        )
    }

    // MARK: - System theme tests

    func testDTM_systemThemeTurnedOff_returnsDefaultTheme() {
        let sut = createSubject(with: userDefaults)
        let expectedResult = ThemeType.light

        sut.setSystemTheme(isOn: false)

        XCTAssertEqual(sut.currentTheme.type, expectedResult)
    }

    func testDTM_systemThemeTurnedOffThenOn_returnsDefaultTheme() {
        let sut = createSubject(with: userDefaults)
        let expectedResult = ThemeType.light

        sut.setSystemTheme(isOn: false)
        sut.setSystemTheme(isOn: true)

        XCTAssertEqual(sut.currentTheme.type, expectedResult)
    }

    // MARK: - Private theme tests

    func testDTM_privateModeEnabled_returnsPrivateTheme() {
        let sut = createSubject(with: userDefaults)
        let expectedResult = ThemeType.privateMode

        sut.setPrivateTheme(isOn: true)

        XCTAssertEqual(sut.currentTheme.type, expectedResult)
    }

    func testDTM_privateModeEnabledAndThenDisabled_returnsOriginalTheme() {
        let sut = createSubject(with: userDefaults)
        let expectedResult = ThemeType.light

        sut.setPrivateTheme(isOn: true)
        sut.setPrivateTheme(isOn: false)

        XCTAssertEqual(sut.currentTheme.type, expectedResult)
    }

    func testDTM_privateModeEnabled_originalThemeRemainsSaved() {
        let sut = createSubject(with: userDefaults)
        let expectedResult = ThemeType.dark.rawValue

        sut.changeCurrentTheme(.dark)
        sut.setPrivateTheme(isOn: true)

        XCTAssertEqual(
            userDefaults.string(forKey: DefaultThemeManager.ThemeKeys.themeName),
            expectedResult
        )
    }

    // MARK: - Getting non-special themes

    func testDTM_privateModeEnabled_originalThemeRemainsAccessibleAfterChange() {
        let sut = createSubject(with: userDefaults)
        let expectedResult = ThemeType.light
        let currentThemeExpectedResult = ThemeType.privateMode

        sut.changeCurrentTheme(.dark)
        sut.setPrivateTheme(isOn: true)
        sut.changeCurrentTheme(.light)

        XCTAssertEqual(sut.currentTheme.type, currentThemeExpectedResult)
        XCTAssertEqual(sut.getNormalSavedTheme(), expectedResult)
    }

    // MARK: - Brightness Tests

    func testDTM_autoBrightnessIsOn_returnsExpectedThemeAndBrightness() {
        let sut = createSubject(with: userDefaults)
        let expectedBrightnessState = true
        let expectedBrightnessValue = Float(0.0)
        let expectedTheme = ThemeType.light

        sut.setSystemTheme(isOn: false)
        sut.setAutomaticBrightness(isOn: true)

        XCTAssertEqual(
            userDefaults.bool(forKey: DefaultThemeManager.ThemeKeys.AutomaticBrightness.isOn),
            expectedBrightnessState
        )
        XCTAssertEqual(
            userDefaults.float(forKey: DefaultThemeManager.ThemeKeys.AutomaticBrightness.thresholdValue),
            expectedBrightnessValue
        )
        XCTAssertEqual(sut.currentTheme.type, expectedTheme)
    }

    func testDTM_settingAutoBrightnessThresholdValue_changesToNewValue() {
        let sut = createSubject(with: userDefaults)
        let firstExpectedResult = Float(42.0)
        let secondExpectedResult = Float(68.0)

        sut.setAutomaticBrightnessValue(firstExpectedResult)
        XCTAssertEqual(
            userDefaults.float(forKey: DefaultThemeManager.ThemeKeys.AutomaticBrightness.thresholdValue),
            firstExpectedResult
        )

        sut.setAutomaticBrightnessValue(secondExpectedResult)
        XCTAssertEqual(
            userDefaults.float(forKey: DefaultThemeManager.ThemeKeys.AutomaticBrightness.thresholdValue),
            secondExpectedResult
        )
    }

    func testDTM_autoBrightnessOnThresholdLowerThanScreenBrigthness_returnsLightTheme() {
        let sut = createSubject(with: userDefaults)
        let expectedTheme = ThemeType.light

        testBrightnessWith(threshold: 0.25, in: sut)

        XCTAssertEqual(sut.currentTheme.type, expectedTheme)
    }

    func testDTM_autoBrightnessOnThresholdEqualToScreenBrigthness_returnsLightTheme() {
        let sut = createSubject(with: userDefaults)
        let expectedTheme = ThemeType.light

        testBrightnessWith(threshold: 0.50, in: sut)

        XCTAssertEqual(sut.currentTheme.type, expectedTheme)
    }

    func testDTM_autoBrightnessOnThresholdGreaterThanScreenBrigthness_returnsDarkTheme() {
        let sut = createSubject(with: userDefaults)
        let expectedTheme = ThemeType.dark

        testBrightnessWith(threshold: 0.75, in: sut)

        XCTAssertEqual(sut.currentTheme.type, expectedTheme)
    }

    func testDTM_autoBrightnessOn_changeValues_thenOff_returnsToExpectedSystemTheme() {
        let sut = createSubject(with: userDefaults)
        let expectedThemeInBrightnessMode = ThemeType.dark
        let expectedThemeInSystemMode = ThemeType.light

        testBrightnessWith(threshold: 0.75, in: sut)
        XCTAssertEqual(sut.currentTheme.type, expectedThemeInBrightnessMode)

        sut.setSystemTheme(isOn: true)
        XCTAssertEqual(sut.currentTheme.type, expectedThemeInSystemMode)
    }

    // MARK: - Helper methods

    private func createSubject(with userDefaults: UserDefaultsInterface,
                               file: StaticString = #file,
                               line: UInt = #line) -> DefaultThemeManager {
        let subject = DefaultThemeManager(
            userDefaults: userDefaults,
            sharedContainerIdentifier: "")
        trackForMemoryLeaks(subject, file: file, line: line)

        return subject
    }

    private func testBrightnessWith(
        threshold: Double,
        in sut: DefaultThemeManager
    ) {
        sut.setSystemTheme(isOn: false)
        sut.setAutomaticBrightness(isOn: true)
        UIScreen.main.brightness = 0.5
        sut.setAutomaticBrightnessValue(Float(threshold))
    }
}
