//
//  ParetlySettingsWindow.swift
//  Paretly
//
//  Copyright (C) 2026 Paretly contributors
//
//  This file is part of Paretly, a GPL-3.0 fork of Squirrel (鼠须管).
//  See LICENSE.txt.

import AppKit
import Carbon
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
    if let scheme = scheme(id: schemeID) {
      return scheme.name.isEmpty ? scheme.id : scheme.name
    }
    if schemeID.isEmpty {
      return "—"
    }
    let missing = NSLocalizedString("Not in the theme file", comment: "Settings")
    return "\(schemeID) \(missing)"
  }

  func paletteForPreview() -> ThemePalette {
    palette(for: previewDark ? .dark : .light)
  }

  /// Swatch for the scheme stored in one appearance slot.
  func palette(for slot: ThemeSlot) -> ThemePalette {
    let dark = slot == .dark
    let schemeID = dark ? colorSchemeDark : colorScheme
    if let scheme = scheme(id: schemeID) {
      return scheme.palette(previewDark: dark)
    }
    return dark ? .nativeDark : .nativeLight
  }

  func activate(_ slot: ThemeSlot) {
    activeSlot = slot
    previewDark = slot == .dark
  }

  func setPreview(dark: Bool) {
    activate(dark ? .dark : .light)
  }

  /// Stores the scheme used when the system appearance is light.
  /// The Appearance control is what changes the preview and the card target.
  func chooseLight(_ schemeID: String) {
    colorScheme = schemeID
  }

  /// Stores the scheme used when the system appearance is dark.
  func chooseDark(_ schemeID: String) {
    colorSchemeDark = schemeID
  }

  func assign(_ schemeID: String) {
    if activeSlot == .dark {
      colorSchemeDark = schemeID
    } else {
      colorScheme = schemeID
    }
  }

  /// Writes paretly.custom.yaml when this window has changes, then deploys.
  /// With no changes, only deploys, so hand-edited Rime files are picked up.
  /// A validation error blocks the write and does not deploy.
  func applyAndDeploy() {
    if applyInFlight { return }
    let edited = editedSettings()
    let edits = ParetlyThemeDocument.changedPatchEdits(baseline: baseline, loaded: loaded, edited: edited)
    var known = Set(schemes.map(\.id))
    known.insert(loaded.colorScheme)
    known.insert(loaded.colorSchemeDark)
    let problem = edits.isEmpty ? nil : ParetlyThemeDocument.validate(edited, knownSchemeIDs: known)
    switch ParetlyApplyDeploy.plan(validationProblem: problem, hasEdits: !edits.isEmpty) {
    case .rejected(let key):
      statusText = NSLocalizedString(key, comment: "Settings")
      statusKind = .err
    case .deployOnly:
      beginApply()
      NSApp.squirrelAppDelegate.deploy()
      statusText = NSLocalizedString("Redeployed.", comment: "Settings")
      statusKind = .ok
      endApply()
    case .saveThenDeploy:
      beginApply()
      statusText = NSLocalizedString("Writing…", comment: "Settings")
      statusKind = .neutral
      do {
        let wrote = try ParetlyThemeDocument.writeCustomFile(edits: edits, userDirectory: SquirrelApp.userDir)
        if wrote {
          loaded = edited
          NSApp.squirrelAppDelegate.deploy()
          statusText = NSLocalizedString("Saved and redeployed.", comment: "Settings")
          statusKind = .ok
        } else {
          NSApp.squirrelAppDelegate.deploy()
          statusText = NSLocalizedString("Redeployed.", comment: "Settings")
          statusKind = .ok
        }
      } catch {
        statusText = NSLocalizedString("Could not write paretly.custom.yaml.", comment: "Settings")
        statusKind = .err
      }
      endApply()
    }
  }

  private func beginApply() {
    applyInFlight = true
    applying = true
  }

  private func endApply() {
    applying = false
    applyInFlight = false
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
  /// True after this process has been transformed to a foreground app.
  /// `setActivationPolicy` is not used: on an `LSUIElement` process it keeps
  /// the agent tile and adds a regular tile beside it.
  private static var foreground = false

  static func show(_ window: NSWindow?) {
    promote()
    // TransformProcessType is applied by the window server after this turn.
    // A single makeKeyAndOrderFront before that lands behind the app that
    // opened the launcher. Repeat once the type has changed, and once more
    // after the launcher has exited and yielded the activation.
    let generation = nextShow()
    bringToFront(window, requireVisible: false)
    DispatchQueue.main.async {
      guard generation == showGeneration else { return }
      bringToFront(window, requireVisible: true)
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      guard generation == showGeneration else { return }
      bringToFront(window, requireVisible: true)
    }
  }

  private static var showGeneration = 0

  private static func nextShow() -> Int {
    showGeneration += 1
    return showGeneration
  }

  /// One Dock tile while a window or update panel is on screen.
  /// Call this before the window is created. A window created while the
  /// process is still an agent registers a tile of its own.
  static func promote() {
    apply(.shown)
  }

  /// The closing window is still visible from `windowWillClose`, so callers
  /// pass it and it is left out of the count. Hide on the next turn so the
  /// transform does not overlap the Dock's show animation.
  static func sync(ignoring closing: NSWindow? = nil) {
    apply(ParetlyDockIcon.visibility(
      settingsVisible: occupiesDock(ParetlySettingsController.shared.window, ignoring: closing),
      aboutVisible: occupiesDock(ParetlyAboutController.shared.window, ignoring: closing),
      updateUIVisible: ParetlyUpdatePresenter.shared.hasVisibleUI
    ))
  }

  private static func occupiesDock(_ window: NSWindow?, ignoring: NSWindow?) -> Bool {
    guard let window, window !== ignoring else { return false }
    return window.isVisible || window.isMiniaturized
  }

  private static func apply(_ icon: ParetlyDockIcon) {
    let showDock = icon == .shown
    guard foreground != showDock else { return }
    var psn = ProcessSerialNumber(highLongOfPSN: 0, lowLongOfPSN: UInt32(kCurrentProcess))
    let state = ProcessApplicationTransformState(
      showDock ? kProcessTransformToForegroundApplication : kProcessTransformToUIElementApplication
    )
    // Replaces the process type. A second call with the same type is skipped
    // above; repeating a policy change is what leaves the extra tile.
    guard TransformProcessType(&psn, state) == 0 else { return }
    foreground = showDock
  }

  private static func bringToFront(_ window: NSWindow?, requireVisible: Bool) {
    guard let window else { return }
    // A follow-up pass must not reopen a window the user already closed.
    // Miniaturized windows are not visible; only the first pass restores them.
    if requireVisible && !window.isVisible {
      return
    }
    activateIgnoringOtherApps()
    if window.isMiniaturized {
      window.deminiaturize(nil)
    }
    window.makeKeyAndOrderFront(nil)
  }

  /// `NSApp.activate()` on macOS 14+ does not come forward while another app
  /// is active (`activate(options:)` is not the replacement; the no-argument
  /// method only requests activation). `ignoringOtherApps` still raises the
  /// process. The launcher also calls `activate(from:)` so the request is
  /// allowed.
  static func activateIgnoringOtherApps() {
    _ = NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    NSApp.activate(ignoringOtherApps: true)
  }
}

final class ParetlyAuxiliaryWindow: NSWindow {
  override func addChildWindow(_ childWin: NSWindow, ordered place: NSWindow.OrderingMode) {
    // Parenting the candidate panel to this titled window otherwise gives
    // the child a rectangular frame and an opaque backing.
    childWin.isOpaque = false
    childWin.backgroundColor = .clear
    super.addChildWindow(childWin, ordered: place)
    childWin.isOpaque = false
    childWin.backgroundColor = .clear
  }

  override func fieldEditor(_ createFlag: Bool, for object: Any?) -> NSText? {
    // The try field is the NSTextView itself (ParetlyTryField.identifier), not
    // a field editor attached to an NSTextField. Returning that view keeps
    // AppKit from inserting a second editor that would commit raw letters.
    if let view = object as? NSView, view.identifier == ParetlyTryField.identifier {
      return nil
    }
    return super.fieldEditor(createFlag, for: object)
  }

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    let flags = event.modifierFlags.intersection([.shift, .control, .option, .command])
    if flags == .command, event.charactersIgnoringModifiers?.lowercased() == "w" {
      performClose(nil)
      return true
    }
    // Escape while trying a phrase stays in the field (cancel composition or
    // end editing). The settings shortcuts must not close the window first.
    if flags.isEmpty, event.keyCode == 53, paretlyTryFieldIsEditing,
       let view = firstResponder as? NSTextView {
      view.keyDown(with: event)
      return true
    }
    return super.performKeyEquivalent(with: event)
  }

  override func cancelOperation(_ sender: Any?) {
    if paretlyTryFieldIsEditing {
      makeFirstResponder(nil)
      return
    }
    performClose(nil)
  }
}

final class ParetlySettingsController: NSWindowController, NSWindowDelegate {
  static let shared = ParetlySettingsController()
  private let model = ParetlySettingsModel()

  func present() {
    // Foreground before the window exists, so AppKit does not also register
    // an agent tile for a window created while this process is still an agent.
    ParetlyWindowActivation.promote()
    if window == nil {
      installWindow()
    }
    if window?.isVisible != true {
      model.reload()
      let dark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
      model.setPreview(dark: dark)
    }
    ParetlyWindowActivation.show(window)
  }

  func windowWillClose(_ notification: Notification) {
    ParetlyTryTyping.shared.end()
    let closing = notification.object as? NSWindow
    DispatchQueue.main.async {
      ParetlyWindowActivation.sync(ignoring: closing)
    }
  }

  private func installWindow() {
    let host = NSHostingController(rootView: ParetlySettingsView(model: model))
    // The form is taller than the window. Leave the size alone so the page scrolls.
    host.sizingOptions = []
    let size = NSSize(
      width: ParetlySettingsWindowMetrics.contentWidth,
      height: ParetlySettingsWindowMetrics.contentHeight
    )
    let window = ParetlyAuxiliaryWindow(
      contentRect: NSRect(origin: .zero, size: size),
      styleMask: [.titled, .closable, .miniaturizable],
      backing: .buffered,
      defer: false
    )
    window.title = NSLocalizedString(ParetlySettingsWindowCopy.titleKey, comment: "Window title")
    window.titleVisibility = .visible
    window.titlebarAppearsTransparent = false
    window.titlebarSeparatorStyle = .automatic
    window.isReleasedWhenClosed = false
    window.isRestorable = false
    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .fullScreenNone]
    window.contentMinSize = size
    window.contentMaxSize = size
    window.delegate = self
    window.contentViewController = host
    self.window = window
    let restored = window.setFrameAutosaveName(ParetlyInputMenu.settingsFrameAutosaveName)
    if restored {
      let origin = window.frame.origin
      window.setContentSize(size)
      window.setFrameOrigin(origin)
    } else {
      window.setContentSize(size)
      window.center()
    }
    window.standardWindowButton(.zoomButton)?.isEnabled = false
  }
}

final class ParetlyAboutController: NSWindowController, NSWindowDelegate {
  static let shared = ParetlyAboutController()

  func present() {
    ParetlyWindowActivation.promote()
    if window == nil {
      installWindow()
      window?.center()
    }
    ParetlyWindowActivation.show(window)
  }

  func windowWillClose(_ notification: Notification) {
    let closing = notification.object as? NSWindow
    DispatchQueue.main.async {
      ParetlyWindowActivation.sync(ignoring: closing)
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
