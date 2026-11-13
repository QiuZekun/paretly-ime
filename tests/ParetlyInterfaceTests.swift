//
//  ParetlyInterfaceTests.swift
//  Paretly
//
//  Copyright (C) 2026 Paretly contributors
//
//  This file is part of Paretly, a GPL-3.0 fork of Squirrel (鼠须管).
//  See LICENSE.txt.

import XCTest

final class ParetlyInterfaceTests: XCTestCase {
  func testSettingsSectionsFollowTheSingleWindowOrder() throws {
    XCTAssertEqual(
      ParetlySettingsSection.allCases.map(\.rawValue),
      ["appearance", "schemes", "schemesGrid", "layout", "update"]
    )
    XCTAssertEqual(
      ParetlySettingsSection.allCases.map(\.titleKey),
      ["Appearance", "Color Schemes", "All Schemes", "Candidate Window", "Software Update"]
    )
    XCTAssertEqual(
      ParetlySettingsSection.allCases.map(\.symbolName),
      ["circle.lefthalf.filled", "paintbrush", "square.grid.2x2", "slider.horizontal.3", "arrow.triangle.2.circlepath"]
    )
    XCTAssertEqual(Set(ParetlySettingsSection.allCases.map(\.symbolName)).count, ParetlySettingsSection.allCases.count)
    XCTAssertEqual(ParetlySettingsWindowCopy.titleKey, "Paretly Settings")
    let view = try settingsViewSource()
    XCTAssertTrue(view.contains("ForEach(ParetlySettingsSection.allCases, id: \\.self)"))
    XCTAssertTrue(view.contains("settingsText(\"Appearance\")"))
    XCTAssertFalse(view.contains("Light Preview"))
    XCTAssertFalse(view.contains("Dark Preview"))
    XCTAssertTrue(view.contains("sectionBody(section)"))
    XCTAssertTrue(view.contains("ScrollView {"))
    XCTAssertEqual(view.components(separatedBy: "Form {").count - 1, 1)
    XCTAssertTrue(view.contains(".formStyle(.grouped)"))
    XCTAssertFalse(view.contains("underPageBackgroundColor"))
    XCTAssertFalse(view.contains("Material.bar"))
    XCTAssertFalse(view.contains("func settingsGroup"))
  }

  func testSettingsUsesCardsPreviewAndAFixedWindow() throws {
    XCTAssertGreaterThanOrEqual(ParetlySettingsWindowMetrics.contentWidth, 760)
    XCTAssertLessThanOrEqual(ParetlySettingsWindowMetrics.contentWidth, 820)
    XCTAssertGreaterThan(ParetlySettingsWindowMetrics.contentHeight, 600)

    let view = try settingsViewSource()
    XCTAssertFalse(view.contains("SchemeMenu"))
    XCTAssertFalse(view.contains("Light Scheme"))
    XCTAssertFalse(view.contains("Dark Scheme"))
    XCTAssertFalse(view.contains("footer:"))
    XCTAssertFalse(view.contains("Click a card to fill the selected slot"))
    XCTAssertTrue(view.contains("schemeAndPreview"))
    XCTAssertTrue(view.contains("\"Light: %@\""))
    XCTAssertTrue(view.contains("\"Dark: %@\""))
    XCTAssertTrue(view.contains("checkmark"))
    XCTAssertTrue(view.contains("ParetlyTryField()"))
    XCTAssertTrue(view.contains(".scrollDisabled(false)"))
    XCTAssertTrue(view.contains("Beta releases are offered only when this is on."))
    XCTAssertTrue(view.contains(".help("))

    let window = try windowSource()
    XCTAssertTrue(window.contains("ParetlySettingsWindowMetrics.contentWidth"))
    XCTAssertTrue(window.contains("ParetlySettingsWindowMetrics.contentHeight"))
    XCTAssertTrue(window.contains("contentMinSize"))
    XCTAssertTrue(window.contains("contentMaxSize"))
    XCTAssertTrue(window.contains("standardWindowButton(.zoomButton)?.isEnabled = false"))
    XCTAssertTrue(window.contains(".fullScreenNone"))
    XCTAssertTrue(window.contains("sizingOptions = []"))
    XCTAssertFalse(window.contains(".resizable"))
    XCTAssertTrue(window.contains("ParetlyTryField.identifier"))
  }

  func testDockIconShowsForSettingsAboutOrUpdateUIOnly() {
    XCTAssertEqual(
      ParetlyDockIcon.visibility(settingsVisible: false, aboutVisible: false, updateUIVisible: false),
      .hidden
    )
    XCTAssertEqual(
      ParetlyDockIcon.visibility(settingsVisible: true, aboutVisible: false, updateUIVisible: false),
      .shown
    )
    XCTAssertEqual(
      ParetlyDockIcon.visibility(settingsVisible: false, aboutVisible: true, updateUIVisible: false),
      .shown
    )
    XCTAssertEqual(
      ParetlyDockIcon.visibility(settingsVisible: false, aboutVisible: false, updateUIVisible: true),
      .shown
    )
    XCTAssertEqual(
      ParetlyDockIcon.visibility(settingsVisible: true, aboutVisible: true, updateUIVisible: true),
      .shown
    )
  }

  func testInputMenuOrderWordingAndShortcut() {
    let entries = ParetlyInputMenu.entries
    XCTAssertEqual(entries.count, 10)
    XCTAssertEqual(entries[2], .separator)
    XCTAssertEqual(entries[5], .separator)
    XCTAssertEqual(entries[8], .separator)

    let specs = ParetlyInputMenu.itemSpecs
    XCTAssertEqual(specs.map(\.action), [
      .openSettings,
      .checkForUpdates,
      .deploy,
      .syncUserData,
      .openLogFolder,
      .openWiki,
      .openAbout
    ])
    XCTAssertEqual(specs.first?.titleKey, "Settings…")
    XCTAssertEqual(specs.last?.titleKey, "About Paretly")
    let deploy = specs.first { $0.action == .deploy }
    XCTAssertEqual(deploy?.keyEquivalent, "`")
    XCTAssertEqual(deploy?.usesControlOption, true)
    XCTAssertTrue(specs.filter { $0.action != .deploy }.allSatisfy { $0.keyEquivalent.isEmpty && !$0.usesControlOption })

    for spec in specs {
      XCTAssertFalse(spec.titleKey.contains("..."), spec.titleKey)
      XCTAssertTrue(isTitleCase(spec.titleKey), spec.titleKey)
      if spec.usesEllipsis {
        XCTAssertTrue(spec.titleKey.hasSuffix("\u{2026}"), spec.titleKey)
      } else {
        XCTAssertFalse(spec.titleKey.hasSuffix("\u{2026}"), spec.titleKey)
      }
    }
    XCTAssertEqual(specs.filter(\.usesEllipsis).map(\.action), [.openSettings, .checkForUpdates, .openLogFolder, .openWiki])
  }

  func testAboutCreditsLicenseAndVersion() {
    XCTAssertEqual(ParetlyAbout.licenseName, "GPL-3.0")
    XCTAssertTrue(ParetlyInterfaceStrings.proseKeys.contains { $0.contains(ParetlyAbout.licenseName) })
    XCTAssertEqual(ParetlyAbout.credits.map(\.name), ["Squirrel", "librime", "Rime ICE", "Paretly"])
    XCTAssertEqual(
      ParetlyAbout.credits.map(\.url.absoluteString),
      [
        "https://github.com/rime/squirrel",
        "https://github.com/rime/librime",
        "https://github.com/iDvel/rime-ice",
        "https://github.com/QiuZekun/paretly-ime"
      ]
    )
    let labeled = ParetlyAbout.versionLabel(marketingVersion: "0.1.0")
    XCTAssertTrue(labeled.contains("0.1.0"))
    XCTAssertFalse(labeled.contains("$("))
    let unavailable = ParetlyAbout.versionLabel(marketingVersion: nil)
    XCTAssertFalse(unavailable.contains("0.1.0"))
    XCTAssertEqual(unavailable, ParetlyAbout.versionLabel(marketingVersion: ""))
    XCTAssertEqual(unavailable, ParetlyAbout.versionLabel(marketingVersion: "$(MARKETING_VERSION)"))
    XCTAssertEqual(unavailable, ParetlyAbout.versionLabel(marketingVersion: "   "))
    XCTAssertEqual(ParetlyInputMenu.settingsFrameAutosaveName, "ParetlySettings")
  }

  func testAlertButtonsAndTitlePunctuation() {
    XCTAssertEqual(
      ParetlyAlertCopy.offerButtonTitleKeys(),
      ["Update Now", "Later", "Skip This Version"]
    )
    XCTAssertEqual(ParetlyAlertCopy.offerButtonTitleKeys()[1], ParetlyAlertCopy.laterButton)
    for title in ParetlyAlertCopy.offerButtonTitleKeys() + [ParetlyAlertCopy.okButton] {
      XCTAssertTrue(isTitleCase(title), title)
      XCTAssertFalse(title.hasSuffix("."))
    }
    XCTAssertEqual(ParetlyAlertCopy.displayTitle("Could not check for updates."), "Could not check for updates")
    XCTAssertEqual(ParetlyAlertCopy.displayTitle("Paretly is up to date."), "Paretly is up to date")
    XCTAssertEqual(ParetlyAlertCopy.displayTitle("无法检查更新。"), "无法检查更新")
    XCTAssertEqual(ParetlyAlertCopy.displayTitle("You're up to date"), "You're up to date")
    XCTAssertEqual(ParetlyAlertCopy.displayTitle("Paretly %@ is available"), "Paretly %@ is available")
    XCTAssertEqual(ParetlyAlertCopy.displayTitle("  The disk image is open.  "), "The disk image is open")
  }

  func testInterfaceStringsHaveChinese() throws {
    let catalog = try stringCatalog()
    for key in ParetlyInterfaceStrings.requiredKeys {
      XCTAssertNotNil(catalog[key], "Missing string \(key)")
      XCTAssertFalse(key.contains("..."), key)
      XCTAssertEqual(translated(key, language: "zh-Hans", catalog: catalog).isEmpty, false, key)
      XCTAssertEqual(translated(key, language: "zh-Hant", catalog: catalog).isEmpty, false, key)
    }
    XCTAssertEqual(translated("Settings…", language: "zh-Hans", catalog: catalog), "设置…")
    XCTAssertEqual(translated("Settings…", language: "zh-Hant", catalog: catalog), "設定…")
    XCTAssertEqual(translated("Check for Updates…", language: "zh-Hans", catalog: catalog), "检查更新…")
    XCTAssertEqual(translated("Check for Updates…", language: "zh-Hant", catalog: catalog), "檢查更新…")
    XCTAssertEqual(translated("About Paretly", language: "zh-Hans", catalog: catalog), "关于 Paretly")
    XCTAssertEqual(translated("Paretly Settings", language: "zh-Hans", catalog: catalog), "Paretly 设置")
    XCTAssertEqual(translated("Paretly Settings", language: "zh-Hant", catalog: catalog), "Paretly 設定")
    XCTAssertEqual(translated("Software Update", language: "zh-Hans", catalog: catalog), "软件更新")
    XCTAssertEqual(translated("Color Schemes", language: "zh-Hans", catalog: catalog), "配色")
    XCTAssertEqual(translated("Appearance", language: "zh-Hans", catalog: catalog), "外观")
    XCTAssertEqual(translated("Appearance", language: "zh-Hant", catalog: catalog), "外觀")
    XCTAssertEqual(translated("All Schemes", language: "zh-Hans", catalog: catalog), "全部配色")
    XCTAssertEqual(translated("Candidate Window", language: "zh-Hans", catalog: catalog), "候选窗")
    XCTAssertEqual(translated("Skip This Version", language: "zh-Hans", catalog: catalog), "跳过此版本")
    XCTAssertEqual(translated("Update Now", language: "zh-Hans", catalog: catalog), "一键更新")
    XCTAssertEqual(translated("Update Now", language: "zh-Hant", catalog: catalog), "一鍵更新")
    XCTAssertEqual(translated("Receive beta updates", language: "zh-Hans", catalog: catalog), "接收测试版（Beta）")
    XCTAssertEqual(translated("Receive beta updates", language: "zh-Hant", catalog: catalog), "接收測試版（Beta）")
    XCTAssertEqual(translated("Sync User Data", language: "zh-Hans", catalog: catalog), "同步用户数据")
    XCTAssertEqual(translated("Logs…", language: "zh-Hans", catalog: catalog), "日志…")
    XCTAssertEqual(translated("Rime Wiki…", language: "zh-Hans", catalog: catalog), "在线文档…")
    XCTAssertEqual(translated("Type to try it~", language: "zh-Hans", catalog: catalog), "打字试试看效果~")
    XCTAssertEqual(translated("Type to try it~", language: "zh-Hant", catalog: catalog), "打字試試看效果~")
    XCTAssertEqual(translated("Light: %@", language: "zh-Hans", catalog: catalog), "浅色：%@")
    XCTAssertEqual(translated("Light: %@", language: "zh-Hant", catalog: catalog), "淺色：%@")
    XCTAssertEqual(translated("Dark: %@", language: "zh-Hans", catalog: catalog), "深色：%@")
    XCTAssertEqual(translated("Dark: %@", language: "zh-Hant", catalog: catalog), "深色：%@")
  }

  private func isTitleCase(_ title: String) -> Bool {
    var words = title
    if words.hasSuffix("\u{2026}") {
      words.removeLast()
    }
    let small: Set<String> = ["for", "of", "the", "a", "an", "and", "to", "in", "on"]
    let parts = words.split(separator: " ").map(String.init)
    guard !parts.isEmpty else { return false }
    for (index, word) in parts.enumerated() {
      let token = word.trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.symbols))
      guard let first = token.first else { continue }
      if index > 0, small.contains(token) { continue }
      if first.isLetter && !first.isUppercase { return false }
    }
    return true
  }

  private func settingsViewSource() throws -> String {
    try source("sources/ParetlySettingsView.swift")
  }

  private func windowSource() throws -> String {
    try source("sources/ParetlySettingsWindow.swift")
  }

  private func source(_ relativePath: String) throws -> String {
    let url = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent(relativePath)
    return try String(contentsOf: url, encoding: .utf8)
  }

  private func stringCatalog() throws -> [String: Any] {
    let url = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("resources/Localizable.xcstrings")
    let data = try Data(contentsOf: url)
    let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    return try XCTUnwrap(root["strings"] as? [String: Any])
  }

  private func translated(_ key: String, language: String, catalog: [String: Any]) -> String {
    let entry = catalog[key] as? [String: Any]
    let localizations = entry?["localizations"] as? [String: Any]
    let languageEntry = localizations?[language] as? [String: Any]
    let unit = languageEntry?["stringUnit"] as? [String: Any]
    return unit?["value"] as? String ?? ""
  }
}
