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
    XCTAssertEqual(panel.level, .floating)
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
    assertReadyForAnotherApp(panel)
    XCTAssertNil(panel.parent)
    XCTAssertTrue(panel.isVisible)

    panel.show(status: "Paretly")
    assertReadyForAnotherApp(panel)
    panel.hide()
    assertReadyForAnotherApp(panel)
    XCTAssertFalse(panel.isVisible)
  }

  private func assertReadyForAnotherApp(_ panel: SquirrelPanel, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertFalse(panel.hidesOnDeactivate, "candidates hide whenever Paretly is not the active app", file: file, line: line)
    XCTAssertFalse(panel.isFloatingPanel, file: file, line: line)
    XCTAssertEqual(panel.level.rawValue, Int(CGShieldingWindowLevel()), file: file, line: line)
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
