//
//  ParetlyInterface.swift
//  Paretly
//
//  Copyright (C) 2026 Paretly contributors
//
//  This file is part of Paretly, a GPL-3.0 fork of Squirrel (鼠须管).
//  See LICENSE.txt.
//
//  Names and order for the single settings window, the input-method menu,
//  the input-source ids, the About credits, and update-alert buttons. The app
//  localizes these keys. Tests lock the order and the Human Interface
//  Guidelines wording.

import Foundation

/// Bundle id and input-mode ids shared by Info.plist, the installer, and
/// `SquirrelInstaller`. A mismatch here is what drops Paretly out of the
/// menu-bar input menu.
enum ParetlyInputSource {
  static let bundleIdentifier = "com.qiuzekun.inputmethod.Paretly"
  static let connectionName = "Paretly_Connection"
  /// IMK resolves this with NSClassFromString. It matches `@objc(ParetlyInputController)`
  /// and must not be `SquirrelInputController` or `Paretly.SquirrelInputController`.
  static let serverControllerClass = "ParetlyInputController"
  static let installedAppPath = "/Library/Input Methods/Paretly.app"
  static let modeHans = "com.qiuzekun.inputmethod.Paretly.Hans"
  static let modeHant = "com.qiuzekun.inputmethod.Paretly.Hant"
  /// Menu order. Matches `tsVisibleInputModeOrderedArrayKey`.
  static let modes = [modeHans, modeHant]
  static let menuIconFile = "paretly.tiff"
}

/// Whether an install should register or enable the input source.
///
/// `TISRegisterInputSource` on every upgrade of this unsigned bundle makes
/// macOS treat the new cdhash as another third-party input method. It asks
/// to enable Paretly and adds a second row under Keyboard > Input Sources.
/// A first install still registers and enables. An upgrade that is already
/// enabled does neither, so there is no second row and no enable prompt.
enum ParetlyInputInstallStep: Equatable {
  case registerAndEnable
  case enableOnly
  case leaveEnabledSourceAlone
}

enum ParetlyInputInstall {
  static func step(registeredSourceCount: Int, enabledSourceCount: Int) -> ParetlyInputInstallStep {
    if enabledSourceCount > 0 {
      return .leaveEnabledSourceAlone
    }
    if registeredSourceCount > 0 {
      return .enableOnly
    }
    return .registerAndEnable
  }
}

/// Top-to-bottom sections of the single settings window.
/// `ParetlySettingsView` iterates `allCases`, so this order is the layout.
enum ParetlySettingsSection: String, CaseIterable, Equatable {
  case appearance
  case schemes
  case schemesGrid
  case layout
  case update

  var titleKey: String {
    switch self {
    case .appearance: return "Appearance"
    case .schemes: return "Color Schemes"
    case .schemesGrid: return "All Schemes"
    case .layout: return "Candidate Window"
    case .update: return "Software Update"
    }
  }

  /// SF Symbols available on macOS 13.
  var symbolName: String {
    switch self {
    case .appearance: return "circle.lefthalf.filled"
    case .schemes: return "paintbrush"
    case .schemesGrid: return "square.grid.2x2"
    case .layout: return "slider.horizontal.3"
    case .update: return "arrow.triangle.2.circlepath"
    }
  }
}

/// Whether the input method shows a Dock icon.
///
/// Info.plist sets `LSUIElement`, so the process is an agent and the Dock has
/// no tile while Settings is closed. `TransformProcessType` changes that
/// process into a foreground app for a visible Settings window, About window,
/// or update panel, which is one tile. The menu bar uses
/// `ParetlyActivationChoice`: `.regular` while that UI is visible, and
/// `.accessory` when it closes so the Dock tile does not stay.
enum ParetlyDockIcon: Equatable {
  case hidden
  case shown

  static func visibility(settingsVisible: Bool, aboutVisible: Bool, updateUIVisible: Bool) -> ParetlyDockIcon {
    if settingsVisible || aboutVisible || updateUIVisible {
      return .shown
    }
    return .hidden
  }
}

enum ParetlySettingsWindowCopy {
  static let titleKey = "Paretly Settings"
}

/// Fixed content size of the settings window. It does not resize or zoom.
/// Width stays in the 760–820 pt range so the scheme cards and the candidate
/// preview can sit side by side.
enum ParetlySettingsWindowMetrics {
  static let contentWidth: CGFloat = 800
  static let contentHeight: CGFloat = 760
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

/// One settings action: write paretly.custom.yaml when the window changed,
/// then deploy. No edits still deploys, so files edited outside the window
/// are reloaded. Validation failure does not write and does not deploy.
enum ParetlyApplyDeployPlan: Equatable {
  case rejected(String)
  case saveThenDeploy
  case deployOnly
}

enum ParetlyApplyDeploy {
  static let buttonTitleKey = "Apply & Deploy"
  static let helpKey = "Saves changes in this window to paretly.custom.yaml and redeploys Rime. Also picks up hand-edited Rime files."

  static func plan(validationProblem: String?, hasEdits: Bool) -> ParetlyApplyDeployPlan {
    if hasEdits, let validationProblem, !validationProblem.isEmpty {
      return .rejected(validationProblem)
    }
    if hasEdits {
      return .saveThenDeploy
    }
    return .deployOnly
  }
}

enum ParetlyInterfaceStrings {
  static let proseKeys = [
    "Settings File",
    ParetlyApplyDeploy.helpKey,
    "Current Appearance",
    "Scheme cards and the candidate preview use this appearance. A card fills this appearance's scheme.",
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
    "Update Now downloads the package and opens it in Installer for you to install.",
    "Version %@",
    "Version unavailable",
    "Copyright © 2026 Paretly contributors",
    "Licensed under GPL-3.0.",
    "Paretly is a GPL-3.0 fork of Squirrel. It uses librime and ships Rime ICE.",
    "Credits",
    "Fills the selected appearance.",
    "Light: %@",
    "Dark: %@",
    "Type to try it~"
  ]

  static var requiredKeys: [String] {
    var keys = ParetlySettingsSection.allCases.map(\.titleKey)
    keys.append(ParetlySettingsWindowCopy.titleKey)
    keys.append(contentsOf: ParetlyInputMenu.itemSpecs.map(\.titleKey))
    keys.append(contentsOf: proseKeys)
    keys.append(ParetlyAlertCopy.updateButton)
    keys.append(ParetlyAlertCopy.skipButton)
    keys.append(ParetlyApplyDeploy.buttonTitleKey)
    return keys
  }
}

private func paretlyURL(_ string: String) -> URL {
  guard let url = URL(string: string) else {
    preconditionFailure("Invalid Paretly URL")
  }
  return url
}
