//
//  ParetlyInputSourceTests.swift
//  Paretly
//
//  Copyright (C) 2026 Paretly contributors
//
//  This file is part of Paretly, a GPL-3.0 fork of Squirrel (鼠须管).
//  See LICENSE.txt.

import XCTest

final class ParetlyInputSourceTests: XCTestCase {
  func testModeIDsMatchInfoPlistAndStayOffTheSquirrelIDs() throws {
    let plist = try propertyList("resources/Info.plist")
    XCTAssertEqual(plist["TISInputSourceID"] as? String, ParetlyInputSource.bundleIdentifier)
    XCTAssertEqual(plist["InputMethodConnectionName"] as? String, ParetlyInputSource.connectionName)
    XCTAssertEqual(plist["InputMethodServerControllerClass"] as? String, ParetlyInputSource.serverControllerClass)
    XCTAssertEqual(plist["InputMethodServerDelegateClass"] as? String, ParetlyInputSource.serverControllerClass)
    XCTAssertEqual(plist["CFBundleIdentifier"] as? String, "$(PRODUCT_BUNDLE_IDENTIFIER)")
    XCTAssertEqual(plist["tsInputMethodIconFileKey"] as? String, ParetlyInputSource.menuIconFile)
    XCTAssertEqual(plist["LSBackgroundOnly"] as? Bool, false)
    XCTAssertNil(plist["LSUIElement"])
    XCTAssertFalse(serialized(plist).contains("im.rime.inputmethod.Squirrel"))

    let component = try XCTUnwrap(plist["ComponentInputModeDict"] as? [String: Any])
    let modes = try XCTUnwrap(component["tsInputModeListKey"] as? [String: Any])
    XCTAssertEqual(Set(modes.keys), Set(ParetlyInputSource.modes))
    let ordered = try XCTUnwrap(component["tsVisibleInputModeOrderedArrayKey"] as? [String])
    XCTAssertEqual(ordered, ParetlyInputSource.modes)

    let hans = try XCTUnwrap(modes[ParetlyInputSource.modeHans] as? [String: Any])
    let hant = try XCTUnwrap(modes[ParetlyInputSource.modeHant] as? [String: Any])
    assertMode(hans, id: ParetlyInputSource.modeHans, language: "zh-Hans", isDefault: true)
    assertMode(hant, id: ParetlyInputSource.modeHant, language: "zh-Hant", isDefault: false)
  }

  func testProjectBundleIdentifierMatchesTheInputSource() throws {
    let project = try text("Squirrel.xcodeproj/project.pbxproj")
    let bundleLines = project
      .split(separator: "\n")
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { $0.hasPrefix("PRODUCT_BUNDLE_IDENTIFIER = ") }
    XCTAssertTrue(bundleLines.contains("PRODUCT_BUNDLE_IDENTIFIER = \(ParetlyInputSource.bundleIdentifier);"))
    XCTAssertFalse(project.contains("im.rime.inputmethod.Squirrel"))
  }

  func testInstallerRegistersEveryModeForTheConsoleUser() throws {
    let postinstall = try text("scripts/postinstall")
    let preinstall = try text("scripts/preinstall")
    let installer = try text("sources/InputSource.swift")

    XCTAssertFalse(postinstall.contains("killall"), "postinstall must not kill Paretly after registration")
    XCTAssertTrue(postinstall.contains("launchctl asuser"))
    XCTAssertTrue(postinstall.contains("/Library/Input Methods/Paretly.app"))
    XCTAssertTrue(postinstall.contains("--register-input-source"))
    XCTAssertTrue(postinstall.contains("--enable-input-source"))
    XCTAssertTrue(postinstall.contains("--select-input-source"))
    for mode in ParetlyInputSource.modes {
      XCTAssertTrue(postinstall.contains(mode), mode)
    }
    let register = try XCTUnwrap(postinstall.range(of: "--register-input-source"))
    let enable = try XCTUnwrap(postinstall.range(of: "--enable-input-source"))
    let select = try XCTUnwrap(postinstall.range(of: "--select-input-source"))
    XCTAssertLessThan(register.lowerBound, enable.lowerBound)
    XCTAssertLessThan(enable.lowerBound, select.lowerBound)

    let quit = try XCTUnwrap(preinstall.range(of: "--quit"))
    let force = try XCTUnwrap(preinstall.range(of: "killall -KILL"))
    XCTAssertLessThan(quit.lowerBound, force.lowerBound)
    XCTAssertTrue(preinstall.contains("launchctl asuser"))

    XCTAssertTrue(installer.contains("ParetlyInputSource.modeHans"))
    XCTAssertTrue(installer.contains("ParetlyInputSource.modeHant"))
    XCTAssertTrue(installer.contains("ParetlyInputSource.bundleIdentifier"))
    XCTAssertTrue(installer.contains("geteuid()"))
    XCTAssertTrue(installer.contains("TISRegisterInputSource"))
    XCTAssertTrue(installer.contains("TISEnableInputSource"))
    XCTAssertFalse(installer.contains("im.rime.inputmethod.Squirrel"))
  }

  func testInputMethodStartsHiddenAndPromotesOnce() throws {
    let plist = try propertyList("resources/Info.plist")
    XCTAssertNil(plist["LSUIElement"])
    XCTAssertEqual(plist["LSBackgroundOnly"] as? Bool, false)

    let main = try text("sources/Main.swift")
    let accessory = try XCTUnwrap(main.range(of: "setActivationPolicy(.accessory)"))
    let run = try XCTUnwrap(main.range(of: "app.run()"))
    XCTAssertLessThan(accessory.lowerBound, run.lowerBound)
    XCTAssertFalse(main.contains("setActivationPolicy(.regular)"))

    let window = try text("sources/ParetlySettingsWindow.swift")
    XCTAssertTrue(window.contains("guard NSApp.activationPolicy() != policy else { return }"))
    XCTAssertTrue(window.contains("NSApp.setActivationPolicy(policy)"))
    XCTAssertTrue(window.contains("ParetlyDockIcon.visibility"))
    XCTAssertFalse(window.contains("setActivationPolicy(.regular)"))
    XCTAssertFalse(window.contains("setActivationPolicy(.accessory)"))

    for path in [
      "sources/ParetlyUpdateController.swift",
      "sources/SquirrelApplicationDelegate.swift",
      "sources/ParetlySettingsView.swift"
    ] {
      let source = try text(path)
      XCTAssertFalse(source.contains("setActivationPolicy("), path)
    }
  }

  func testLauncherHidesItsDockIconAndExits() throws {
    let source = try text("launcher/main.swift")
    let accessory = try XCTUnwrap(source.range(of: "setActivationPolicy(.accessory)"))
    let run = try XCTUnwrap(source.range(of: "process.run()"))
    let done = try XCTUnwrap(source.range(of: "exit(EXIT_SUCCESS)"))
    XCTAssertLessThan(accessory.lowerBound, run.lowerBound)
    XCTAssertLessThan(run.lowerBound, done.lowerBound)
    XCTAssertFalse(source.contains("app.run("))
    XCTAssertFalse(source.contains("NSApp.run("))
    XCTAssertTrue(source.contains("setActivationPolicy(.regular)"))
  }

  private func assertMode(_ mode: [String: Any], id: String, language: String, isDefault: Bool) {
    XCTAssertEqual(mode["TISInputSourceID"] as? String, id)
    XCTAssertEqual(mode["TISIntendedLanguage"] as? String, language)
    XCTAssertEqual(mode["tsInputModeIsVisibleKey"] as? Bool, true)
    XCTAssertEqual(mode["tsInputModePrimaryInScriptKey"] as? Bool, true)
    XCTAssertEqual(mode["tsInputModeDefaultStateKey"] as? Bool, isDefault)
    XCTAssertEqual(mode["tsInputModeMenuIconFileKey"] as? String, ParetlyInputSource.menuIconFile)
    XCTAssertEqual(mode["tsInputModeAlternateMenuIconFileKey"] as? String, ParetlyInputSource.menuIconFile)
    XCTAssertEqual(mode["tsInputModePaletteIconFileKey"] as? String, ParetlyInputSource.menuIconFile)
  }

  private func propertyList(_ relativePath: String) throws -> [String: Any] {
    let data = try Data(contentsOf: repoFile(relativePath))
    let root = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
    return try XCTUnwrap(root as? [String: Any])
  }

  private func text(_ relativePath: String) throws -> String {
    try String(contentsOf: repoFile(relativePath), encoding: .utf8)
  }

  private func serialized(_ plist: [String: Any]) -> String {
    guard let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0),
          let text = String(data: data, encoding: .utf8) else {
      return ""
    }
    return text
  }

  private func repoFile(_ relativePath: String) -> URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent(relativePath)
  }
}
