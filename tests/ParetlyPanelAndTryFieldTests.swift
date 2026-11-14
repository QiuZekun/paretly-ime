//
//  ParetlyPanelAndTryFieldTests.swift
//  Paretly
//
//  Copyright (C) 2026 Paretly contributors
//
//  This file is part of Paretly, a GPL-3.0 fork of Squirrel (鼠须管).
//  See LICENSE.txt.

import AppKit
import SwiftUI
import XCTest

final class ParetlyCandidatePanelTests: XCTestCase {
  private var windows: [NSWindow] = []

  override func tearDown() {
    for window in windows {
      window.orderOut(nil)
    }
    windows.removeAll()
    super.tearDown()
  }

  func testPanelStaysOnScreenWhenTheAppIsInactive() {
    let panel = track(SquirrelPanel(position: NSRect(x: 80, y: 80, width: 40, height: 20)))
    assertReadyForAnotherApp(panel)

    let parent = track(NSWindow(
      contentRect: NSRect(x: 200, y: 200, width: 420, height: 280),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    ))
    panel.anchorAbove(parent)
    XCTAssertIdentical(panel.parent, parent)
    // A child window cannot use a level above its parent. AppKit clamps it
    // to the settings window's level; ordering above is what keeps it on top.
    XCTAssertEqual(panel.level, parent.level)
    XCTAssertFalse(panel.hidesOnDeactivate)
    XCTAssertFalse(panel.isFloatingPanel)
    XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllSpaces))
    XCTAssertTrue(panel.collectionBehavior.contains(.fullScreenAuxiliary))
    XCTAssertEqual(parent.childWindows?.filter { $0 === panel }.count, 1)

    panel.anchorAbove(parent)
    XCTAssertEqual(parent.childWindows?.filter { $0 === panel }.count, 1)
    XCTAssertFalse(panel.hidesOnDeactivate)

    panel.releaseAnchor()
    assertReadyForAnotherApp(panel)
    XCTAssertNil(panel.parent)
    XCTAssertFalse(parent.childWindows?.contains { $0 === panel } ?? false)

    panel.hide()
    assertReadyForAnotherApp(panel)
    XCTAssertFalse(panel.isVisible)

    if let screen = NSScreen.main {
      panel.position = NSRect(x: screen.frame.midX, y: screen.frame.midY, width: 1, height: 16)
    }
    panel.update(
      preedit: "ni",
      selRange: NSRange(location: 0, length: 2),
      caretPos: 2,
      candidates: ["你"],
      comments: [""],
      labels: ["1"],
      highlighted: 0,
      page: 0,
      lastPage: true,
      update: true
    )
    assertShownForAnotherApp(panel)
    XCTAssertNil(panel.parent)
    XCTAssertTrue(panel.isVisible)

    panel.show(status: "Paretly")
    assertShownForAnotherApp(panel)
    panel.hide()
    assertReadyForAnotherApp(panel)
    XCTAssertFalse(panel.isVisible)
  }

  func testTryFieldPanelReturnsAfterDeployAndKeepsARoundedBacking() {
    let settings = track(NSWindow(
      contentRect: NSRect(x: 200, y: 200, width: 420, height: 280),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    ))
    let panel = track(SquirrelPanel(position: NSRect(x: 80, y: 80, width: 40, height: 20)))

    // Apply & Deploy, and the input-menu Deploy, can run more than once.
    // Each pass orders the panel out while the try-field still needs it.
    for _ in 0..<2 {
      panel.orderOut(nil)
      XCTAssertFalse(panel.isVisible)
      panel.reclaimForTryField(above: settings)
      showCandidates(panel)
      XCTAssertTrue(panel.isVisible)
      XCTAssertIdentical(panel.parent, settings)
      XCTAssertEqual(panel.level, settings.level)
      XCTAssertFalse(panel.hidesOnDeactivate)
      XCTAssertFalse(panel.isFloatingPanel)
      XCTAssertEqual(settings.childWindows?.filter { $0 === panel }.count, 1)
      assertNoRectangularPlate(panel, anchored: true)
    }

    panel.releaseAnchor()
    showCandidates(panel)
    XCTAssertNil(panel.parent)
    XCTAssertFalse(settings.childWindows?.contains { $0 === panel } ?? false)
    XCTAssertTrue(panel.isVisible)
    XCTAssertFalse(panel.hasShadow)
    XCTAssertFalse(panel.hidesOnDeactivate)
    assertNoRectangularPlate(panel, anchored: false)

    panel.hide()
    assertReadyForAnotherApp(panel)
    XCTAssertFalse(panel.isVisible)
  }

  func testRoundedBubbleCornersAreTransparent() {
    let panel = track(SquirrelPanel(position: NSRect(x: 40, y: 40, width: 20, height: 20)))
    let config = RoundedBubbleConfig()
    panel.load(config: config, forDarkMode: false)
    panel.load(config: config, forDarkMode: true)
    showCandidates(panel)
    assertClearCorners(panel)

    let settings = track(NSWindow(
      contentRect: NSRect(x: 80, y: 80, width: 420, height: 280),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    ))
    panel.reclaimForTryField(above: settings)
    showCandidates(panel)
    XCTAssertIdentical(panel.parent, settings)
    assertClearCorners(panel)
    panel.hide()
  }

  func testDeployClearsTheTryFieldSessionWithoutClosingTheField() {
    let editing = ParetlyTryTypingDeployState(
      hasSession: true,
      schemaId: "luna_pinyin",
      inlinePreedit: false,
      active: true
    )
    XCTAssertEqual(
      editing.cleared(),
      ParetlyTryTypingDeployState(hasSession: false, schemaId: "", inlinePreedit: true, active: true)
    )

    let idle = ParetlyTryTypingDeployState(
      hasSession: true,
      schemaId: "luna_pinyin",
      inlinePreedit: true,
      active: false
    )
    let cleared = idle.cleared()
    XCTAssertFalse(cleared.hasSession)
    XCTAssertEqual(cleared.schemaId, "")
    XCTAssertFalse(cleared.active)
  }

  /// Level while the panel is not ordered in. A normal test host can drop
  /// `CGShieldingWindowLevel` once the window is on screen; the input method
  /// process does not. Hide-on-deactivate is checked either way.
  private func assertReadyForAnotherApp(_ panel: SquirrelPanel, file: StaticString = #filePath, line: UInt = #line) {
    assertShownForAnotherApp(panel, file: file, line: line)
    XCTAssertEqual(panel.level.rawValue, Int(CGShieldingWindowLevel()), file: file, line: line)
  }

  private func showCandidates(_ panel: SquirrelPanel) {
    if let screen = NSScreen.main {
      panel.position = NSRect(x: screen.frame.midX, y: screen.frame.midY, width: 1, height: 16)
    }
    panel.update(
      preedit: "ni",
      selRange: NSRange(location: 0, length: 2),
      caretPos: 2,
      candidates: ["你"],
      comments: [""],
      labels: ["1"],
      highlighted: 0,
      page: 0,
      lastPage: true,
      update: true
    )
  }

  private func assertNoRectangularPlate(_ panel: SquirrelPanel, anchored: Bool, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertFalse(panel.isOpaque, file: file, line: line)
    XCTAssertFalse(panel.styleMask.contains(.titled), file: file, line: line)
    XCTAssertFalse(panel.styleMask.contains(.hudWindow), file: file, line: line)
    let alpha = panel.backgroundColor?.alphaComponent ?? 1
    XCTAssertEqual(alpha, 0, accuracy: 0.001, file: file, line: line)
    let content = panel.contentView
    XCTAssertTrue(content?.wantsLayer ?? false, file: file, line: line)
    XCTAssertFalse(content?.layer?.isOpaque ?? true, file: file, line: line)
    XCTAssertFalse(panel.hasShadow, "the window shadow is a rectangle around the bubble", file: file, line: line)
    XCTAssertEqual(content?.layer?.shadowOpacity ?? 1, Float(0), file: file, line: line)
    XCTAssertNil(content?.layer?.shadowPath, file: file, line: line)
    XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel), file: file, line: line)
    XCTAssertFalse(panel.styleMask.contains(.utilityWindow), file: file, line: line)
    let effects = content?.subviews.compactMap { $0 as? NSVisualEffectView } ?? []
    XCTAssertTrue(effects.isEmpty, "the HUD plate is a rectangle behind the bubble", file: file, line: line)
    _ = anchored
  }

  private func assertClearCorners(_ panel: SquirrelPanel, file: StaticString = #filePath, line: UInt = #line) {
    guard let content = panel.contentView else {
      XCTFail("missing content view", file: file, line: line)
      return
    }
    content.layoutSubtreeIfNeeded()
    guard let image = bitmap(of: content) else {
      XCTFail("candidate bubble did not render", file: file, line: line)
      return
    }
    let width = image.pixelsWide
    let height = image.pixelsHigh
    XCTAssertGreaterThan(width, 8, file: file, line: line)
    XCTAssertGreaterThan(height, 8, file: file, line: line)
    guard width > 8, height > 8 else { return }
    for (x, y) in [(1, 1), (width - 2, 1), (1, height - 2), (width - 2, height - 2)] {
      let alpha = image.colorAt(x: x, y: y)?.alphaComponent ?? 0
      XCTAssertEqual(alpha, 0, accuracy: 0.05, "corner \(x),\(y) is a square frame", file: file, line: line)
    }
    let center = image.colorAt(x: width / 2, y: height / 2)
    XCTAssertGreaterThan(center?.alphaComponent ?? 0, 0.5, "the rounded fill should still be visible", file: file, line: line)
  }

  private func bitmap(of view: NSView) -> NSBitmapImageRep? {
    let bounds = view.bounds
    guard bounds.width > 2, bounds.height > 2 else { return nil }
    let scale = view.window?.backingScaleFactor ?? 2
    let pixelsWide = max(1, Int((bounds.width * scale).rounded()))
    let pixelsHigh = max(1, Int((bounds.height * scale).rounded()))
    guard let rep = NSBitmapImageRep(
      bitmapDataPlanes: nil,
      pixelsWide: pixelsWide,
      pixelsHigh: pixelsHigh,
      bitsPerSample: 8,
      samplesPerPixel: 4,
      hasAlpha: true,
      isPlanar: false,
      colorSpaceName: .deviceRGB,
      bytesPerRow: 0,
      bitsPerPixel: 0
    ) else { return nil }
    rep.size = bounds.size
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    guard let graphics = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    NSGraphicsContext.current = graphics
    graphics.cgContext.clear(CGRect(x: 0, y: 0, width: CGFloat(pixelsWide), height: CGFloat(pixelsHigh)))
    graphics.cgContext.scaleBy(x: scale, y: scale)
    view.layoutSubtreeIfNeeded()
    view.layer?.render(in: graphics.cgContext)
    return rep
  }

  private func assertShownForAnotherApp(_ panel: SquirrelPanel, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertFalse(panel.hidesOnDeactivate, "candidates hide whenever Paretly is not the active app", file: file, line: line)
    XCTAssertFalse(panel.isFloatingPanel, file: file, line: line)
    XCTAssertNil(panel.parent, file: file, line: line)
    XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllSpaces), file: file, line: line)
    XCTAssertTrue(panel.collectionBehavior.contains(.fullScreenAuxiliary), file: file, line: line)
    XCTAssertFalse(panel.collectionBehavior.contains(.moveToActiveSpace), file: file, line: line)
  }

  private func track<Window: NSWindow>(_ window: Window) -> Window {
    windows.append(window)
    return window
  }
}

final class ParetlyTryFieldLayoutTests: XCTestCase {
  func testPreferredSizeIsACompactSingleLine() {
    XCTAssertEqual(ParetlyTryField.preferredHeight, 24)
    XCTAssertGreaterThanOrEqual(ParetlyTryField.preferredWidth, 172)
    XCTAssertLessThanOrEqual(ParetlyTryField.preferredWidth, 180)
  }

  func testFittingSizeRejectsATallProposal() {
    let proposed = ParetlyTryField.fittingSize(for: ProposedViewSize(width: 176, height: 360))
    XCTAssertEqual(proposed, CGSize(width: 176, height: 24))

    let unspecified = ParetlyTryField.fittingSize(for: .unspecified)
    XCTAssertEqual(unspecified, CGSize(width: ParetlyTryField.preferredWidth, height: 24))

    let unbounded = ParetlyTryField.fittingSize(for: ProposedViewSize(width: .infinity, height: .infinity))
    XCTAssertEqual(unbounded, CGSize(width: ParetlyTryField.preferredWidth, height: 24))
  }

  func testBoxKeepsASingleLineAndDoesNotClipText() throws {
    let box = ParetlyTryFieldBox(frame: .zero)
    XCTAssertEqual(box.intrinsicContentSize.height, 24)
    XCTAssertEqual(box.intrinsicContentSize.width, ParetlyTryField.preferredWidth)
    XCTAssertEqual(box.contentHuggingPriority(for: .vertical), .required)
    XCTAssertEqual(box.contentCompressionResistancePriority(for: .vertical), .required)
    XCTAssertEqual(box.textView.textContainer?.maximumNumberOfLines, 1)

    box.frame = NSRect(x: 0, y: 0, width: ParetlyTryField.preferredWidth, height: ParetlyTryField.preferredHeight)
    box.layoutSubtreeIfNeeded()

    let font = try XCTUnwrap(box.textView.font)
    let line = ceil(font.ascender - font.descender + font.leading)
    let inset = box.textView.textContainerInset
    let usable = box.textView.bounds.height - inset.height * 2
    XCTAssertGreaterThanOrEqual(usable, line)
    XCTAssertTrue(box.bounds.contains(box.textView.frame))
    XCTAssertGreaterThan(box.textView.frame.height, 0)
    XCTAssertLessThanOrEqual(box.textView.frame.maxY, box.bounds.maxY + 0.5)

    let padding = (box.textView.textContainer?.lineFragmentPadding ?? 0) + inset.width
    let contentWidth = box.textView.bounds.width - padding * 2
    for placeholder in ["Type to try it~", "打字试试看效果~", "打字試試看效果~"] {
      let width = (placeholder as NSString).size(withAttributes: [.font: font]).width
      XCTAssertLessThan(width, contentWidth, placeholder)
    }
  }

  func testHostingViewDoesNotStretchTheFieldVertically() throws {
    let host = NSHostingView(rootView: TryFieldHeightProbe())
    host.frame = NSRect(x: 0, y: 0, width: 800, height: 360)
    let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    defer { window.orderOut(nil) }
    window.contentView = host
    host.autoresizingMask = [.width, .height]
    window.layoutIfNeeded()
    host.layoutSubtreeIfNeeded()
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    host.layoutSubtreeIfNeeded()

    let box = try XCTUnwrap(findBox(in: host))
    XCTAssertEqual(box.frame.height, 24, accuracy: 0.5)
    XCTAssertEqual(box.frame.width, ParetlyTryField.preferredWidth, accuracy: 0.5)
    let placed = box.convert(box.bounds, to: host)
    XCTAssertEqual(placed.midY, host.bounds.midY, accuracy: 2)
  }

  private func findBox(in view: NSView) -> ParetlyTryFieldBox? {
    if let box = view as? ParetlyTryFieldBox {
      return box
    }
    for child in view.subviews {
      if let found = findBox(in: child) {
        return found
      }
    }
    return nil
  }
}

final class ParetlyMenuBarTests: XCTestCase {
  func testSettingsMenuHasAppEditAndWindowMenus() throws {
    let menu = ParetlyMainMenu.make()
    XCTAssertEqual(menu.items.map(\.title), ["Paretly", "Edit", "Window"])

    let app = try XCTUnwrap(menu.items[0].submenu)
    XCTAssertEqual(title(app, "About Paretly")?.action, #selector(ParetlyMenuActions.showAbout(_:)))
    let settings = try XCTUnwrap(title(app, "Settings…"))
    XCTAssertEqual(settings.keyEquivalent, ",")
    XCTAssertTrue(settings.keyEquivalentModifierMask.contains(.command))
    XCTAssertEqual(settings.action, #selector(ParetlyMenuActions.showSettings(_:)))
    XCTAssertEqual(title(app, "Check for Updates…")?.action, #selector(ParetlyMenuActions.checkForUpdates(_:)))
    XCTAssertEqual(title(app, "Hide Paretly")?.action, #selector(NSApplication.hide(_:)))
    let closeSettings = try XCTUnwrap(title(app, "Close Settings"))
    XCTAssertEqual(closeSettings.keyEquivalent, "q")
    XCTAssertEqual(closeSettings.action, #selector(ParetlyMenuActions.closeSettings(_:)))
    XCTAssertNotEqual(closeSettings.action, #selector(NSApplication.terminate(_:)))

    let edit = try XCTUnwrap(menu.items[1].submenu)
    XCTAssertEqual(title(edit, "Undo")?.action, Selector(("undo:")))
    XCTAssertEqual(title(edit, "Redo")?.action, Selector(("redo:")))
    XCTAssertEqual(title(edit, "Cut")?.action, Selector(("cut:")))
    XCTAssertEqual(title(edit, "Copy")?.action, Selector(("copy:")))
    XCTAssertEqual(title(edit, "Paste")?.action, Selector(("paste:")))
    XCTAssertEqual(title(edit, "Select All")?.action, Selector(("selectAll:")))
    XCTAssertNil(title(edit, "Copy")?.target)

    let window = try XCTUnwrap(menu.items[2].submenu)
    let minimize = try XCTUnwrap(title(window, "Minimize"))
    XCTAssertEqual(minimize.keyEquivalent, "m")
    XCTAssertEqual(minimize.action, #selector(NSWindow.performMiniaturize(_:)))
    let close = try XCTUnwrap(title(window, "Close"))
    XCTAssertEqual(close.keyEquivalent, "w")
    XCTAssertEqual(close.action, #selector(NSWindow.performClose(_:)))
  }

  func testActivationPolicyIsRegularWhileUIIsOpenAndAccessoryAfterClose() {
    XCTAssertEqual(ParetlyActivationChoice.forVisibleUI(settings: true, about: false, update: false), .regular)
    XCTAssertEqual(ParetlyActivationChoice.forVisibleUI(settings: false, about: true, update: false), .regular)
    XCTAssertEqual(ParetlyActivationChoice.forVisibleUI(settings: false, about: false, update: true), .regular)
    XCTAssertEqual(
      ParetlyActivationChoice.forVisibleUI(settings: true, about: true, update: true),
      .regular
    )
    let closed = ParetlyActivationChoice.forVisibleUI(settings: false, about: false, update: false)
    XCTAssertEqual(closed, .accessory)
    XCTAssertEqual(closed.policy, .accessory)
    XCTAssertEqual(ParetlyActivationChoice.regular.policy, .regular)
  }

  private func title(_ menu: NSMenu, _ name: String) -> NSMenuItem? {
    menu.items.first { $0.title == name }
  }
}

private struct RoundedBubbleConfig: SquirrelThemeConfig {
  func getBool(_ option: String) -> Bool? {
    option == "style/translucency" ? false : nil
  }

  func getDouble(_ option: String) -> CGFloat? {
    switch option {
    case "style/corner_radius":
      return 16
    case "style/border_height", "style/border_width":
      return 6
    case "style/alpha":
      return 1
    default:
      return nil
    }
  }

  func getString(_ option: String) -> String? {
    switch option {
    case "style/color_scheme", "style/color_scheme_dark":
      return "solid"
    case "style/candidate_list_layout":
      return "stacked"
    default:
      return nil
    }
  }

  func getColor(_ option: String, inSpace colorSpace: SquirrelTheme.RimeColorSpace) -> NSColor? {
    if option.hasSuffix("/back_color") {
      return NSColor(srgbRed: 0.12, green: 0.13, blue: 0.16, alpha: 1)
    }
    if option.hasSuffix("text_color") {
      return .white
    }
    return nil
  }
}

private struct TryFieldHeightProbe: View {
  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      Color.clear.frame(width: 32, height: 32)
      ParetlyTryField()
        .frame(width: ParetlyTryField.preferredWidth)
      Text("Ready")
        .lineLimit(1)
      Button("Apply & Deploy") {}
    }
    .frame(width: 800, height: 360, alignment: .center)
  }
}
