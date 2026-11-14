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
    XCTAssertEqual(plist["CFBundleShortVersionString"] as? String, "$(MARKETING_VERSION)")
    XCTAssertEqual(plist["CFBundleVersion"] as? String, "$(CURRENT_PROJECT_VERSION)")
    XCTAssertEqual(
      plist["NSHumanReadableCopyright"] as? String,
      "Copyright © 2026 Paretly contributors. Licensed under GPL-3.0."
    )
    XCTAssertEqual(plist["ParetlyCommit"] as? String, "$(PARETLY_COMMIT)")
    XCTAssertFalse((plist["NSHumanReadableCopyright"] as? String ?? "").isEmpty)
    XCTAssertEqual(plist["tsInputMethodIconFileKey"] as? String, ParetlyInputSource.menuIconFile)
    XCTAssertEqual(plist["LSBackgroundOnly"] as? Bool, false)
    XCTAssertEqual(plist["LSUIElement"] as? Bool, true)
    XCTAssertFalse(serialized(plist).contains("im.rime.inputmethod.Squirrel"))
    try assertNoSquirrelIdentifier(plist["InputMethodConnectionName"] as? String, label: "InputMethodConnectionName")
    try assertNoSquirrelIdentifier(plist["InputMethodServerControllerClass"] as? String, label: "InputMethodServerControllerClass")
    try assertNoSquirrelIdentifier(plist["InputMethodServerDelegateClass"] as? String, label: "InputMethodServerDelegateClass")
    try assertNoSquirrelIdentifier(plist["TISInputSourceID"] as? String, label: "TISInputSourceID")
    try assertNoSquirrelIdentifier(plist["tsInputMethodIconFileKey"] as? String, label: "tsInputMethodIconFileKey")

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
    // -f on the input method bundle, in the console user's GUI session, before
    // TIS registration. The launcher registration uses "${dest}", not app_root.
    let refresh = try XCTUnwrap(postinstall.range(of: "run_as_console_user \"${reg}\" -f \"${app_root}\""))
    XCTAssertLessThan(refresh.lowerBound, register.lowerBound)

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
    XCTAssertFalse(postinstall.localizedCaseInsensitiveContains("squirrel"))
    XCTAssertFalse(preinstall.localizedCaseInsensitiveContains("squirrel"))
    XCTAssertFalse(postinstall.contains("Squirrel.app"))
    XCTAssertFalse(postinstall.contains("im.rime"))
  }

  func testUpgradeEnablesAStaleSourceWithoutRegisteringAgain() throws {
    let hans = ParetlyInputSource.modeHans
    let missing = ParetlyInputModeState(id: hans, registered: false, enabled: false, selectable: false)
    XCTAssertEqual(ParetlyInputInstall.action(modes: [missing]), .registerAndEnable)

    let disabled = ParetlyInputModeState(id: hans, registered: true, enabled: false, selectable: false)
    XCTAssertEqual(ParetlyInputInstall.action(modes: [disabled]), .enableWithoutRegister)

    // Enabled but missing from the input menu: the running process still
    // types, and enabling again must not register a second source.
    let stale = ParetlyInputModeState(id: hans, registered: true, enabled: true, selectable: false)
    XCTAssertEqual(ParetlyInputInstall.action(modes: [stale]), .enableWithoutRegister)

    let ready = ParetlyInputModeState(id: hans, registered: true, enabled: true, selectable: true)
    XCTAssertEqual(ParetlyInputInstall.action(modes: [ready]), .leaveAlone)

    let mixed = [
      ready,
      ParetlyInputModeState(id: ParetlyInputSource.modeHant, registered: true, enabled: true, selectable: false)
    ]
    XCTAssertEqual(ParetlyInputInstall.action(modes: mixed), .enableWithoutRegister)

    let installer = try text("sources/InputSource.swift")
    XCTAssertTrue(installer.contains("ParetlyInputInstall.action"))
    XCTAssertTrue(installer.contains("kTISPropertyInputSourceIsSelectCapable"))
    XCTAssertTrue(installer.contains("not registering again"))
    XCTAssertTrue(installer.contains("not enabling again"))
  }

  func testUpdateDownloadsThePackageInsteadOfInstallingIt() throws {
    XCTAssertEqual(ParetlyManualUpdate.handoff(), .revealAndOpen)
    let source = try text("sources/ParetlyUpdateController.swift")
    XCTAssertFalse(source.contains("administrator privileges"))
    XCTAssertFalse(source.contains("installWithAdministratorPrivileges"))
    XCTAssertFalse(source.contains("/usr/sbin/installer"))
    XCTAssertFalse(source.contains("NSAppleScript"))
    XCTAssertTrue(source.contains("activateFileViewerSelecting"))
    XCTAssertTrue(source.contains("NSWorkspace.shared.open"))
    XCTAssertTrue(source.contains("ParetlyManualUpdate.handoff()"))
  }

  func testInfoPlistKeysDoNotReuseSquirrelIdentifiers() throws {
    let plist = try propertyList("resources/Info.plist")
    XCTAssertEqual(plist["InputMethodConnectionName"] as? String, "Paretly_Connection")
    XCTAssertNotEqual(plist["InputMethodConnectionName"] as? String, "Squirrel_Connection")
    XCTAssertNotEqual(plist["InputMethodConnectionName"] as? String, "Squirrel_1_Connection")
    XCTAssertEqual(plist["InputMethodServerControllerClass"] as? String, "ParetlyInputController")
    XCTAssertEqual(plist["InputMethodServerDelegateClass"] as? String, "ParetlyInputController")

    let controller = try text("sources/SquirrelInputController.swift")
    XCTAssertTrue(controller.contains("@objc(ParetlyInputController)"))
    let delegate = try text("sources/SquirrelApplicationDelegate.swift")
    XCTAssertTrue(delegate.contains("@objc(ParetlyApplicationDelegate)"))
    let panel = try text("sources/SquirrelPanel.swift")
    XCTAssertTrue(panel.contains("@objc(ParetlyCandidatePanel)"))
    let view = try text("sources/SquirrelView.swift")
    XCTAssertTrue(view.contains("@objc(ParetlyCandidateView)"))
    XCTAssertTrue(view.contains("@objc(ParetlyTextLayoutDelegate)"))

    let component = try XCTUnwrap(plist["ComponentInputModeDict"] as? [String: Any])
    let modes = try XCTUnwrap(component["tsInputModeListKey"] as? [String: Any])
    let iconKeys = [
      "tsInputModeMenuIconFileKey",
      "tsInputModePaletteIconFileKey",
      "tsInputModeAlternateMenuIconFileKey"
    ]
    for (modeID, raw) in modes {
      try assertNoSquirrelIdentifier(modeID, label: "mode id")
      let mode = try XCTUnwrap(raw as? [String: Any])
      try assertNoSquirrelIdentifier(mode["TISInputSourceID"] as? String, label: "\(modeID) TISInputSourceID")
      for key in iconKeys {
        let icon = try XCTUnwrap(mode[key] as? String, "\(modeID) \(key)")
        try assertNoSquirrelIdentifier(icon, label: "\(modeID) \(key)")
        XCTAssertNotEqual(icon, "rime.pdf")
        XCTAssertNotEqual(icon, "squirrel.tiff")
        XCTAssertTrue(FileManager.default.fileExists(atPath: repoFile("resources/\(icon)").path), icon)
      }
    }
    let methodIcon = try XCTUnwrap(plist["tsInputMethodIconFileKey"] as? String)
    XCTAssertTrue(FileManager.default.fileExists(atPath: repoFile("resources/\(methodIcon)").path))

    let main = try text("sources/Main.swift")
    XCTAssertTrue(main.contains("\"Library\", \"Rime\""))
    XCTAssertTrue(main.contains("rime.paretly"))
    XCTAssertFalse(main.contains("rime.squirrel"))
    XCTAssertFalse(main.contains("Squirrel_Connection"))
    XCTAssertFalse(main.contains("SquirrelReloadNotification"))
    XCTAssertTrue(main.contains("ParetlyReloadNotification"))
    XCTAssertTrue(delegate.contains("ParetlyReloadNotification"))
    XCTAssertTrue(delegate.contains("\"rime.paretly\""))
    XCTAssertTrue(delegate.contains("paretly.yaml"))
    XCTAssertFalse(delegate.contains("SquirrelReloadNotification"))
    XCTAssertFalse(delegate.contains("SquirrelSyncNotification"))
    XCTAssertFalse(delegate.contains("squirrel.yaml"))
  }

  func testInputMethodStartsHiddenAndPromotesOnce() throws {
    let plist = try propertyList("resources/Info.plist")
    XCTAssertEqual(plist["LSUIElement"] as? Bool, true)
    XCTAssertEqual(plist["LSBackgroundOnly"] as? Bool, false)

    let main = try text("sources/Main.swift")
    XCTAssertFalse(main.contains("setActivationPolicy("))
    let show = try XCTUnwrap(main.range(of: "case \"--show-settings\":"))
    let help = try XCTUnwrap(main.range(of: "case \"--help\":"))
    let showBody = main[show.upperBound..<help.lowerBound]
    XCTAssertFalse(showBody.contains("rime_get_api_stdbool()"))
    XCTAssertTrue(String(showBody).contains("deliverImmediately: true"))
    let handled = try XCTUnwrap(main.range(of: "if handled {"))
    XCTAssertTrue(main[handled.upperBound...].contains("rime_get_api_stdbool()"))

    let window = try text("sources/ParetlySettingsWindow.swift")
    XCTAssertTrue(window.contains("TransformProcessType"))
    XCTAssertTrue(window.contains("kProcessTransformToForegroundApplication"))
    XCTAssertTrue(window.contains("kProcessTransformToUIElementApplication"))
    XCTAssertTrue(window.contains("ParetlyActivationChoice.forVisibleUI"))
    XCTAssertTrue(window.contains("setActivationPolicy(choice.policy)"))
    XCTAssertTrue(window.contains("ParetlyMainMenu.install()"))
    XCTAssertFalse(window.contains("orderFrontRegardless"))
    let promote = try XCTUnwrap(window.range(of: "ParetlyWindowActivation.promote()"))
    let install = try XCTUnwrap(window.range(of: "installWindow()"))
    XCTAssertLessThan(promote.lowerBound, install.lowerBound)

    for path in [
      "sources/ParetlyUpdateController.swift",
      "sources/SquirrelApplicationDelegate.swift",
      "sources/ParetlySettingsView.swift"
    ] {
      let source = try text(path)
      XCTAssertFalse(source.contains("setActivationPolicy("), path)
    }
  }

  func testLauncherMessagesTheRunningInputMethodAndDoesNotShowATile() throws {
    let source = try text("launcher/main.swift")
    let posted = try XCTUnwrap(source.range(of: "deliverImmediately: true"))
    let done = try XCTUnwrap(source.range(of: "exit(EXIT_SUCCESS)"))
    XCTAssertLessThan(posted.lowerBound, done.lowerBound)
    XCTAssertTrue(source.contains("ParetlyShowSettingsNotification"))
    XCTAssertTrue(source.contains("activate(from:"))
    XCTAssertTrue(source.contains("activateIgnoringOtherApps"))
    XCTAssertFalse(source.contains("setActivationPolicy(.accessory)"))
    XCTAssertFalse(source.contains("NSWorkspace"))
    XCTAssertFalse(source.contains("/usr/bin/open"))
    XCTAssertFalse(source.contains("process.executableURL = executable"))
    XCTAssertFalse(source.contains("app.run("))
    XCTAssertFalse(source.contains("NSApp.run("))
    // A missing install can still present an alert.
    XCTAssertTrue(source.contains("setActivationPolicy(.regular)"))

    let builder = try text("tools/build-launcher.sh")
    let key = try XCTUnwrap(builder.range(of: "<key>LSUIElement</key>"))
    XCTAssertTrue(builder[key.upperBound...].contains("<true/>"))
    XCTAssertTrue(builder.contains("Launcher must set LSUIElement"))
    XCTAssertFalse(builder.contains("Launcher must not set LSUIElement"))
  }

  private func assertNoSquirrelIdentifier(_ value: String?, label: String) throws {
    let text = try XCTUnwrap(value, label)
    XCTAssertNil(
      text.range(of: "squirrel", options: .caseInsensitive),
      "\(label) still uses a Squirrel identifier: \(text)"
    )
    XCTAssertFalse(text.contains("im.rime"), label)
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
