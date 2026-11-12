//
//  ParetlySettingsWindow.swift
//  Paretly
//
//  Copyright (C) 2026 Paretly contributors
//
//  This file is part of Paretly, a GPL-3.0 fork of Squirrel (鼠须管).
//  See LICENSE.txt.

import AppKit
import SwiftUI

enum ThemeSlot: Equatable {
  case light
  case dark
}

enum ThemeStatusKind: Equatable {
  case neutral
  case ok
  case warn
  case err
}

final class ParetlySettingsModel: ObservableObject {
  @Published var schemes: [ThemeScheme] = []
  @Published var colorScheme = ThemeSettings.fallback.colorScheme
  @Published var colorSchemeDark = ThemeSettings.fallback.colorSchemeDark
  @Published var candidateListLayout = ThemeSettings.fallback.candidateListLayout
  @Published var fontPoint = ThemeSettings.fallback.fontPoint
  @Published var labelFontPoint = ThemeSettings.fallback.labelFontPoint
  @Published var cornerRadius = ThemeSettings.fallback.cornerRadius
  @Published var activeSlot: ThemeSlot = .light
  @Published var previewDark = false {
    didSet {
      if previewDark != oldValue {
        onPreviewDarkChange?(previewDark)
      }
    }
  }
  @Published var statusText = ""
  @Published var statusKind: ThemeStatusKind = .neutral
  @Published var banner: String?
  @Published var applying = false
  @Published var automaticUpdateChecks = ParetlyUpdatePreferences.shared.automatic {
    didSet {
      ParetlyUpdatePreferences.shared.automatic = automaticUpdateChecks
    }
  }

  var onPreviewDarkChange: ((Bool) -> Void)?

  private var baseline = ThemeSettings.fallback
  private var loaded = ThemeSettings.fallback
  private var applyInFlight = false

  func reload() {
    guard let support = Bundle.main.sharedSupportPath else {
      showReadFailure()
      return
    }
    let bundledURL = URL(fileURLWithPath: support, isDirectory: true).appendingPathComponent(ParetlyThemeDocument.configFileName)
    guard let bundled = try? String(contentsOf: bundledURL, encoding: .utf8) else {
      showReadFailure()
      return
    }
    let userURL = SquirrelApp.userDir.appendingPathComponent(ParetlyThemeDocument.configFileName)
    let userText = readIfPresent(userURL)
    if FileManager.default.fileExists(atPath: userURL.path), userText == nil {
      banner = NSLocalizedString("Could not read the user theme file.", comment: "Settings")
    }
    let customURL = SquirrelApp.userDir.appendingPathComponent(ParetlyThemeDocument.customFileName)
    let result = ParetlyThemeDocument.load(
      bundledYAML: bundled,
      userYAML: userText,
      customYAML: readIfPresent(customURL)
    )
    schemes = result.schemes
    baseline = clamped(result.baseline)
    loaded = clamped(result.effective)
    colorScheme = loaded.colorScheme
    colorSchemeDark = loaded.colorSchemeDark
    candidateListLayout = loaded.candidateListLayout
    fontPoint = loaded.fontPoint
    labelFontPoint = loaded.labelFontPoint
    cornerRadius = loaded.cornerRadius
    if result.schemes.isEmpty {
      banner = NSLocalizedString("No color schemes found in paretly.yaml.", comment: "Settings")
    } else if banner == nil || userText != nil || !FileManager.default.fileExists(atPath: userURL.path) {
      banner = nil
    }
    statusText = ""
    statusKind = .neutral
  }

  func scheme(id schemeID: String) -> ThemeScheme? {
    schemes.first { $0.id == schemeID }
  }

  func paletteForPreview() -> ThemePalette {
    let schemeID = previewDark ? colorSchemeDark : colorScheme
    if let scheme = scheme(id: schemeID) {
      return scheme.palette(previewDark: previewDark)
    }
    return previewDark ? .nativeDark : .nativeLight
  }

  func activate(_ slot: ThemeSlot) {
    activeSlot = slot
    previewDark = slot == .dark
  }

  func setPreview(dark: Bool) {
    previewDark = dark
    activeSlot = dark ? .dark : .light
  }

  func chooseLight(_ schemeID: String) {
    colorScheme = schemeID
    activate(.light)
  }

  func chooseDark(_ schemeID: String) {
    colorSchemeDark = schemeID
    activate(.dark)
  }

  func assign(_ schemeID: String) {
    if activeSlot == .dark {
      colorSchemeDark = schemeID
    } else {
      colorScheme = schemeID
    }
  }

  func apply() {
    if applyInFlight { return }
    let edited = editedSettings()
    var known = Set(schemes.map(\.id))
    known.insert(loaded.colorScheme)
    known.insert(loaded.colorSchemeDark)
    if let problem = ParetlyThemeDocument.validate(edited, knownSchemeIDs: known) {
      statusText = NSLocalizedString(problem, comment: "Settings")
      statusKind = .err
      return
    }
    let edits = ParetlyThemeDocument.changedPatchEdits(baseline: baseline, loaded: loaded, edited: edited)
    if edits.isEmpty {
      statusText = NSLocalizedString("No changes to write.", comment: "Settings")
      statusKind = .neutral
      return
    }
    applyInFlight = true
    applying = true
    statusText = NSLocalizedString("Writing…", comment: "Settings")
    statusKind = .neutral
    do {
      let wrote = try ParetlyThemeDocument.writeCustomFile(edits: edits, userDirectory: SquirrelApp.userDir)
      if wrote {
        NSApp.squirrelAppDelegate.deploy()
        loaded = edited
        statusText = NSLocalizedString("Saved and redeployed.", comment: "Settings")
        statusKind = .ok
      } else {
        statusText = NSLocalizedString("No changes to write.", comment: "Settings")
        statusKind = .neutral
      }
    } catch {
      statusText = NSLocalizedString("Could not write paretly.custom.yaml.", comment: "Settings")
      statusKind = .err
    }
    applying = false
    applyInFlight = false
  }

  func redeploy() {
    if applyInFlight { return }
    NSApp.squirrelAppDelegate.deploy()
    statusText = NSLocalizedString("Redeployed.", comment: "Settings")
    statusKind = .ok
  }

  private func editedSettings() -> ThemeSettings {
    ThemeSettings(
      colorScheme: colorScheme,
      colorSchemeDark: colorSchemeDark,
      candidateListLayout: candidateListLayout,
      fontPoint: fontPoint,
      labelFontPoint: labelFontPoint,
      cornerRadius: cornerRadius
    )
  }

  private func clamped(_ settings: ThemeSettings) -> ThemeSettings {
    var copy = settings
    copy.fontPoint = min(28, max(12, copy.fontPoint))
    copy.labelFontPoint = min(24, max(10, copy.labelFontPoint))
    copy.cornerRadius = min(20, max(0, copy.cornerRadius))
    if copy.candidateListLayout != "linear" && copy.candidateListLayout != "stacked" {
      copy.candidateListLayout = "stacked"
    }
    return copy
  }

  private func readIfPresent(_ url: URL) -> String? {
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    return try? String(contentsOf: url, encoding: .utf8)
  }

  private func showReadFailure() {
    schemes = []
    banner = NSLocalizedString("Could not read the bundled theme file.", comment: "Settings")
  }
}

final class ParetlySettingsController: NSWindowController, NSWindowDelegate {
  static let shared = ParetlySettingsController()
  private let model = ParetlySettingsModel()

  func present() {
    if window == nil {
      installWindow()
    }
    if window?.isVisible != true {
      model.reload()
      let dark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
      model.setPreview(dark: dark)
    }
    applyChrome(dark: model.previewDark)
    NSApp.setActivationPolicy(.regular)
    window?.makeKeyAndOrderFront(nil)
    window?.orderFrontRegardless()
    activateApp()
  }

  func windowWillClose(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
  }

  private func installWindow() {
    let host = NSHostingController(rootView: ParetlySettingsView(model: model))
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 1120, height: 800),
      styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    window.title = NSLocalizedString("Paretly Settings", comment: "Window title")
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.isReleasedWhenClosed = false
    window.minSize = NSSize(width: 1000, height: 680)
    window.delegate = self
    window.contentViewController = host
    window.center()
    self.window = window
    model.onPreviewDarkChange = { [weak self] dark in
      self?.applyChrome(dark: dark)
    }
  }

  private func applyChrome(dark: Bool) {
    let background = dark
      ? NSColor(srgbRed: 29.0 / 255.0, green: 29.0 / 255.0, blue: 31.0 / 255.0, alpha: 1)
      : NSColor(srgbRed: 232.0 / 255.0, green: 232.0 / 255.0, blue: 237.0 / 255.0, alpha: 1)
    window?.backgroundColor = background
    window?.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
  }

  private func activateApp() {
    if #available(macOS 14.0, *) {
      NSApp.activate()
    } else {
      NSApp.activate(ignoringOtherApps: true)
    }
  }
}
