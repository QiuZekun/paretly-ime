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

enum ThemeSlot: Hashable {
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
  @Published var previewDark = false
  @Published var selectedTab: ParetlySettingsTab = .general {
    didSet {
      if selectedTab != oldValue {
        onTabChange?(selectedTab)
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
  @Published var includeBetaUpdates = ParetlyUpdatePreferences.shared.includeBetas {
    didSet {
      ParetlyUpdatePreferences.shared.includeBetas = includeBetaUpdates
    }
  }

  var onTabChange: ((ParetlySettingsTab) -> Void)?

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

  func schemeTitle(_ schemeID: String) -> String {
    if let scheme = scheme(id: schemeID), !scheme.name.isEmpty {
      return scheme.name
    }
    return schemeID.isEmpty ? "—" : schemeID
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

enum ParetlyAppIcon {
  static var image: NSImage? {
    if let icon = NSApp.applicationIconImage, icon.size.width > 1, icon.size.height > 1 {
      return icon
    }
    return NSImage(named: NSImage.applicationIconName)
  }
}

enum ParetlyWindowActivation {
  static func show(_ window: NSWindow?) {
    NSApp.setActivationPolicy(.regular)
    window?.makeKeyAndOrderFront(nil)
    window?.orderFrontRegardless()
    if #available(macOS 14.0, *) {
      NSApp.activate()
    } else {
      NSApp.activate(ignoringOtherApps: true)
    }
  }
}

final class ParetlyAuxiliaryWindow: NSWindow {
  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    let flags = event.modifierFlags.intersection([.shift, .control, .option, .command])
    if flags == .command, event.charactersIgnoringModifiers?.lowercased() == "w" {
      performClose(nil)
      return true
    }
    return super.performKeyEquivalent(with: event)
  }

  override func cancelOperation(_ sender: Any?) {
    if let editor = fieldEditor(false, for: nil), firstResponder === editor {
      endEditing(for: nil)
      return
    }
    performClose(nil)
  }
}

final class ParetlySettingsController: NSWindowController, NSWindowDelegate, NSToolbarDelegate {
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
    show(model.selectedTab)
    ParetlyWindowActivation.show(window)
  }

  func windowWillClose(_ notification: Notification) {
    if ParetlyAboutController.shared.window?.isVisible != true {
      NSApp.setActivationPolicy(.accessory)
    }
  }

  func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    ParetlySettingsTab.allCases.map(\.toolbarIdentifier)
  }

  func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    toolbarDefaultItemIdentifiers(toolbar)
  }

  func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    toolbarDefaultItemIdentifiers(toolbar)
  }

  func toolbar(
    _ toolbar: NSToolbar,
    itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
    willBeInsertedIntoToolbar flag: Bool
  ) -> NSToolbarItem? {
    guard let tab = ParetlySettingsTab.allCases.first(where: { $0.toolbarIdentifier == itemIdentifier }) else {
      return nil
    }
    let label = tab.toolbarLabel
    let item = NSToolbarItem(itemIdentifier: itemIdentifier)
    item.label = label
    item.paletteLabel = label
    item.toolTip = label
    item.target = self
    item.action = #selector(selectTab(_:))
    let image = NSImage(systemSymbolName: tab.symbolName, accessibilityDescription: label)
    image?.isTemplate = true
    item.image = image
    return item
  }

  @objc private func selectTab(_ sender: NSToolbarItem) {
    guard let tab = ParetlySettingsTab.allCases.first(where: { $0.toolbarIdentifier == sender.itemIdentifier }) else {
      return
    }
    model.selectedTab = tab
  }

  private func installWindow() {
    let host = NSHostingController(rootView: ParetlySettingsView(model: model))
    host.sizingOptions = [.standardBounds]
    let window = ParetlyAuxiliaryWindow(
      contentRect: NSRect(x: 0, y: 0, width: 860, height: 680),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.titleVisibility = .visible
    window.titlebarAppearsTransparent = false
    window.titlebarSeparatorStyle = .automatic
    window.toolbarStyle = .preference
    window.isReleasedWhenClosed = false
    window.isRestorable = false
    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    window.minSize = NSSize(width: 760, height: 580)
    window.delegate = self
    window.contentViewController = host
    let toolbar = NSToolbar(identifier: "ParetlySettings")
    toolbar.displayMode = .iconAndLabel
    toolbar.allowsUserCustomization = false
    toolbar.autosavesConfiguration = false
    toolbar.delegate = self
    window.toolbar = toolbar
    self.window = window
    model.onTabChange = { [weak self] tab in
      self?.show(tab)
    }
    let restored = window.setFrameAutosaveName(ParetlyInputMenu.settingsFrameAutosaveName)
    if !restored {
      window.center()
    }
    show(model.selectedTab)
  }

  private func show(_ tab: ParetlySettingsTab) {
    window?.title = tab.windowTitle
    window?.toolbar?.selectedItemIdentifier = tab.toolbarIdentifier
  }
}

final class ParetlyAboutController: NSWindowController, NSWindowDelegate {
  static let shared = ParetlyAboutController()

  func present() {
    if window == nil {
      installWindow()
      window?.center()
    }
    ParetlyWindowActivation.show(window)
  }

  func windowWillClose(_ notification: Notification) {
    if ParetlySettingsController.shared.window?.isVisible != true {
      NSApp.setActivationPolicy(.accessory)
    }
  }

  private func installWindow() {
    let host = NSHostingController(rootView: ParetlyAboutPanelView())
    host.sizingOptions = [.standardBounds]
    let window = ParetlyAuxiliaryWindow(
      contentRect: NSRect(x: 0, y: 0, width: 460, height: 540),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    window.title = NSLocalizedString("About Paretly", comment: "About")
    window.titleVisibility = .visible
    window.titlebarAppearsTransparent = false
    window.isReleasedWhenClosed = false
    window.isRestorable = false
    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    let size = NSSize(width: 460, height: 540)
    window.contentMinSize = size
    window.contentMaxSize = size
    window.setContentSize(size)
    window.delegate = self
    window.contentViewController = host
    self.window = window
  }
}

extension ParetlySettingsTab {
  var toolbarIdentifier: NSToolbarItem.Identifier {
    NSToolbarItem.Identifier("ParetlySettingsTab.\(rawValue)")
  }

  var toolbarLabel: String {
    NSLocalizedString(titleKey, comment: "Settings")
  }

  var windowTitle: String {
    String(
      format: NSLocalizedString("Paretly — %@", comment: "Window title"),
      toolbarLabel
    )
  }
}
