//
//  ParetlyInterface.swift
//  Paretly
//
//  Copyright (C) 2026 Paretly contributors
//
//  This file is part of Paretly, a GPL-3.0 fork of Squirrel (鼠须管).
//  See LICENSE.txt.
//
//  Names and order for the settings tabs, the input-method menu, the About
//  credits, and update-alert buttons. The app localizes these keys. Tests
//  lock the order and the Human Interface Guidelines wording.

import Foundation

enum ParetlySettingsTab: String, CaseIterable, Equatable {
  case general
  case appearance
  case input
  case updates
  case about

  var titleKey: String {
    switch self {
    case .general: return "General"
    case .appearance: return "Appearance"
    case .input: return "Input"
    case .updates: return "Updates"
    case .about: return "About"
    }
  }

  /// SF Symbols available on macOS 13.
  var symbolName: String {
    switch self {
    case .general: return "gearshape"
    case .appearance: return "paintbrush"
    case .input: return "keyboard"
    case .updates: return "arrow.triangle.2.circlepath"
    case .about: return "info.circle"
    }
  }

  /// Command-1 through Command-5, in tab order.
  var shortcut: Character {
    switch self {
    case .general: return "1"
    case .appearance: return "2"
    case .input: return "3"
    case .updates: return "4"
    case .about: return "5"
    }
  }
}

enum ParetlyMenuAction: String, Equatable {
  case openSettings
  case checkForUpdates
  case deploy
  case syncUserData
  case openLogFolder
  case openWiki
  case openAbout
}

struct ParetlyMenuItemSpec: Equatable {
  var titleKey: String
  var action: ParetlyMenuAction
  var keyEquivalent: String = ""
  var usesControlOption: Bool = false
  /// Windows, folders, and web pages use an ellipsis. About follows the app menu and does not.
  var usesEllipsis: Bool = false
}

enum ParetlyMenuEntry: Equatable {
  case item(ParetlyMenuItemSpec)
  case separator
}

enum ParetlyInputMenu {
  static let settingsFrameAutosaveName = "ParetlySettings"

  static let entries: [ParetlyMenuEntry] = [
    .item(ParetlyMenuItemSpec(titleKey: "Settings…", action: .openSettings, usesEllipsis: true)),
    .item(ParetlyMenuItemSpec(titleKey: "Check for Updates…", action: .checkForUpdates, usesEllipsis: true)),
    .separator,
    .item(ParetlyMenuItemSpec(
      titleKey: "Deploy",
      action: .deploy,
      keyEquivalent: "`",
      usesControlOption: true
    )),
    .item(ParetlyMenuItemSpec(titleKey: "Sync User Data", action: .syncUserData)),
    .separator,
    .item(ParetlyMenuItemSpec(titleKey: "Logs…", action: .openLogFolder, usesEllipsis: true)),
    .item(ParetlyMenuItemSpec(titleKey: "Rime Wiki…", action: .openWiki, usesEllipsis: true)),
    .separator,
    .item(ParetlyMenuItemSpec(titleKey: "About Paretly", action: .openAbout))
  ]

  static var itemSpecs: [ParetlyMenuItemSpec] {
    entries.compactMap { entry in
      if case .item(let spec) = entry { return spec }
      return nil
    }
  }
}

enum ParetlyAbout {
  struct Credit: Equatable {
    var name: String
    var url: URL
  }

  static let licenseName = "GPL-3.0"

  static let credits: [Credit] = [
    Credit(name: "Squirrel", url: paretlyURL("https://github.com/rime/squirrel")),
    Credit(name: "librime", url: paretlyURL("https://github.com/rime/librime")),
    Credit(name: "Rime ICE", url: paretlyURL("https://github.com/iDvel/rime-ice")),
    Credit(name: "Paretly", url: paretlyURL("https://github.com/QiuZekun/paretly-ime"))
  ]

  static func marketingVersion(in bundle: Bundle = .main) -> String? {
    bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
  }

  static func versionLabel(marketingVersion: String?) -> String {
    let trimmed = marketingVersion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if trimmed.isEmpty || trimmed.contains("$(") {
      return NSLocalizedString("Version unavailable", comment: "About")
    }
    return String(format: NSLocalizedString("Version %@", comment: "About"), trimmed)
  }
}

enum ParetlyAlertCopy {
  static let updateButton = "Update Now"
  static let laterButton = "Later"
  static let skipButton = "Skip This Version"
  static let okButton = "OK"

  /// Primary (install in place), secondary (Escape), then the version to skip.
  static func offerButtonTitleKeys() -> [String] {
    [updateButton, laterButton, skipButton]
  }

  /// Alert titles are sentence case without ending punctuation.
  static func displayTitle(_ title: String) -> String {
    var text = title.trimmingCharacters(in: .whitespacesAndNewlines)
    let endings: Set<Character> = [".", "。", "．"]
    while let last = text.last, endings.contains(last) {
      text.removeLast()
      text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return text
  }
}

enum ParetlyInterfaceStrings {
  static let proseKeys = [
    "Paretly — %@",
    "Settings File",
    "Apply writes changed colors, layout, and sizes to ~/Library/Rime/paretly.custom.yaml, keeps other patches, and redeploys Rime.",
    "Current Appearance",
    "The light scheme is used when the system appearance is light. The dark scheme is used when the system appearance is dark. Dark defaults to 简约黑 (clean_black).",
    "Color Schemes",
    "Light Scheme",
    "Dark Scheme",
    "All Schemes",
    "Assign Cards To",
    "Preview",
    "Candidate preview",
    "Sample candidate window for the selected appearance.",
    "Candidate Window",
    "Layout",
    "Horizontal candidates sit on one line. Vertical candidates are stacked.",
    "Candidate size is 12 to 28 points. Label size is 10 to 24 points.",
    "Corner radius is 0 to 20 points.",
    "Software Update",
    "Receive beta updates",
    "Beta releases are offered only when this is on. A beta build turns it on until you change it.",
    "Update Now asks for an administrator password, installs the package in place, and opens Paretly again. If that fails, the package opens in Installer.",
    "Redeploy reloads Rime. It does not change the choices in this window.",
    "Version %@",
    "Version unavailable",
    "Licensed under GPL-3.0.",
    "Paretly is a GPL-3.0 fork of Squirrel. It uses librime and ships Rime ICE.",
    "Credits",
    "Fills the selected appearance."
  ]

  static var requiredKeys: [String] {
    var keys = ParetlySettingsTab.allCases.map(\.titleKey)
    keys.append(contentsOf: ParetlyInputMenu.itemSpecs.map(\.titleKey))
    keys.append(contentsOf: proseKeys)
    keys.append(ParetlyAlertCopy.updateButton)
    keys.append(ParetlyAlertCopy.skipButton)
    return keys
  }
}

private func paretlyURL(_ string: String) -> URL {
  guard let url = URL(string: string) else {
    preconditionFailure("Invalid Paretly URL")
  }
  return url
}
