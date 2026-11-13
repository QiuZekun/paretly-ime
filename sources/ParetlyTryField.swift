//
//  ParetlyTryField.swift
//  Paretly
//
//  Copyright (C) 2026 Paretly contributors
//
//  This file is part of Paretly, a GPL-3.0 fork of Squirrel (鼠须管).
//  See LICENSE.txt.
//
//  The settings window lives in this input-method process. macOS does not
//  deliver IMK keystrokes into an input method's own windows, and a SwiftUI
//  NSTextField often never installs the window field editor, so letters were
//  inserted as plain text. This view is an NSTextView (a real
//  NSTextInputClient) in the hierarchy. It runs its own Rime session and
//  anchors the shared candidate panel above the settings window: that panel
//  is created while the process is still an agent, and after
//  TransformProcessType, orderFront leaves it behind the key window.

import AppKit
import SwiftUI

struct ParetlyTryField: NSViewRepresentable {
  static let identifier = NSUserInterfaceItemIdentifier("ParetlyTryField")
  /// One regular single-line control. SwiftUI stretches an
  /// `NSViewRepresentable` to the proposed height unless `sizeThatFits`
  /// reports otherwise.
  static let preferredHeight: CGFloat = 24
  /// Fits "Type to try it~", "打字试试看效果~", and "打字試試看效果~"
  /// at the system font, and stays a short field beside the header icon.
  static let preferredWidth: CGFloat = 176

  func makeNSView(context: Context) -> ParetlyTryFieldBox {
    let box = ParetlyTryFieldBox()
    box.textView.identifier = Self.identifier
    box.textView.placeholderText = Self.placeholder
    box.textView.setAccessibilityLabel(Self.placeholder)
    return box
  }

  func updateNSView(_ box: ParetlyTryFieldBox, context: Context) {
    let placeholder = Self.placeholder
    if box.textView.placeholderText != placeholder {
      box.textView.placeholderText = placeholder
      box.textView.setAccessibilityLabel(placeholder)
    }
  }

  func sizeThatFits(_ proposal: ProposedViewSize, nsView: ParetlyTryFieldBox, context: Context) -> CGSize? {
    Self.fittingSize(for: proposal)
  }

  /// Height is always one line. An unspecified or unbounded width falls back
  /// to the compact field; a finite proposal (the header's frame) is kept.
  static func fittingSize(for proposal: ProposedViewSize) -> CGSize {
    CGSize(width: proposedWidth(proposal.width), height: preferredHeight)
  }

  private static func proposedWidth(_ width: CGFloat?) -> CGFloat {
    guard let width, width.isFinite, width > 0 else { return preferredWidth }
    return width
  }

  private static var placeholder: String {
    NSLocalizedString("Type to try it~", comment: "Settings")
  }
}

extension NSWindow {
  /// True while the settings try-typing view is the first responder.
  /// Escape cancels composition instead of closing the window.
  var paretlyTryFieldIsEditing: Bool {
    var view = firstResponder as? NSView
    while let current = view {
      if current.identifier == ParetlyTryField.identifier {
        return true
      }
      view = current.superview
    }
    return false
  }
}

final class ParetlyTryFieldBox: NSView {
  let textView = ParetlyTryTextView(frame: .zero)
  private let cell = NSTextFieldCell(textCell: "")
  private let focusRing = ParetlyTryFocusRing(frame: .zero)

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    cell.isBezeled = true
    cell.isBordered = true
    cell.bezelStyle = .roundedBezel
    cell.isEditable = false
    cell.isSelectable = false
    cell.font = .systemFont(ofSize: NSFont.systemFontSize)
    cell.drawsBackground = true
    cell.backgroundColor = .textBackgroundColor
    cell.controlView = self
    textView.drawsBackground = false
    textView.isEditable = true
    textView.isSelectable = true
    textView.isRichText = false
    textView.importsGraphics = false
    textView.isAutomaticQuoteSubstitutionEnabled = false
    textView.isAutomaticDashSubstitutionEnabled = false
    textView.isAutomaticDataDetectionEnabled = false
    textView.isAutomaticTextReplacementEnabled = false
    textView.isAutomaticSpellingCorrectionEnabled = false
    textView.isContinuousSpellCheckingEnabled = false
    textView.isGrammarCheckingEnabled = false
    textView.isAutomaticTextCompletionEnabled = false
    textView.usesFontPanel = false
    textView.usesFindPanel = false
    textView.font = .systemFont(ofSize: NSFont.systemFontSize)
    textView.textColor = .labelColor
    textView.insertionPointColor = .labelColor
    textView.textContainer?.lineFragmentPadding = 2
    textView.textContainer?.maximumNumberOfLines = 1
    textView.textContainer?.lineBreakMode = .byTruncatingHead
    textView.textContainer?.widthTracksTextView = true
    textView.isHorizontallyResizable = false
    textView.isVerticallyResizable = false
    textView.focusRingType = .none
    textView.autoresizingMask = []
    addSubview(textView)
    focusRing.autoresizingMask = [.width, .height]
    addSubview(focusRing)
    setContentHuggingPriority(.required, for: .vertical)
    setContentCompressionResistancePriority(.required, for: .vertical)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var intrinsicContentSize: NSSize {
    NSSize(width: ParetlyTryField.preferredWidth, height: ParetlyTryField.preferredHeight)
  }

  override func layout() {
    super.layout()
    focusRing.frame = bounds
    let font = textView.font ?? .systemFont(ofSize: NSFont.systemFontSize)
    let line = ceil(font.ascender - font.descender + font.leading)
    var interior = cell.titleRect(forBounds: bounds)
    let inside = bounds.insetBy(dx: 1, dy: 1)
    if interior.width < 8 || interior.height < line || !inside.contains(interior) {
      // The bezel's title rect is shorter than one line at 24pt. Center a
      // line plus a point of slack so the caret and placeholder aren't clipped.
      let padded = min(bounds.height, line + 2)
      let dy = max(0, (bounds.height - padded) / 2)
      interior = NSRect(
        x: bounds.minX + 7,
        y: bounds.minY + dy,
        width: max(0, bounds.width - 14),
        height: padded
      )
    }
    textView.frame = interior
    let slack = max(0, interior.height - line)
    textView.textContainerInset = NSSize(width: 1, height: slack / 2)
    focusRing.isFocused = window?.firstResponder === textView
  }

  override func draw(_ dirtyRect: NSRect) {
    cell.stringValue = ""
    cell.placeholderString = ""
    cell.draw(withFrame: bounds, in: self)
  }

  override func mouseDown(with event: NSEvent) {
    window?.makeFirstResponder(textView)
  }

  func noteFocusChange() {
    needsLayout = true
    focusRing.isFocused = window?.firstResponder === textView
  }
}

final class ParetlyTryFocusRing: NSView {
  var isFocused = false {
    didSet {
      if isFocused != oldValue { needsDisplay = true }
    }
  }

  override var isOpaque: Bool { false }

  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  override func draw(_ dirtyRect: NSRect) {
    guard isFocused else { return }
    NSColor.keyboardFocusIndicatorColor.setStroke()
    let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1.5, dy: 1.5), xRadius: 5, yRadius: 5)
    path.lineWidth = 2
    path.stroke()
  }
}

final class ParetlyTryTextView: NSTextView {
  var placeholderText = "" {
    didSet { needsDisplay = true }
  }

  /// `NSView.isOpaque` is read-only. A clear background lets the field bezel show through.
  override var isOpaque: Bool { false }

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

  override func becomeFirstResponder() -> Bool {
    let accepted = super.becomeFirstResponder()
    if accepted {
      ParetlyTryTyping.shared.begin(editor: self)
      (superview as? ParetlyTryFieldBox)?.noteFocusChange()
    }
    return accepted
  }

  override func resignFirstResponder() -> Bool {
    let accepted = super.resignFirstResponder()
    if accepted {
      ParetlyTryTyping.shared.end()
      (superview as? ParetlyTryFieldBox)?.noteFocusChange()
    }
    return accepted
  }

  override func keyDown(with event: NSEvent) {
    if event.modifierFlags.contains(.command) {
      super.keyDown(with: event)
      return
    }
    if ParetlyTryTyping.shared.handle(event, editor: self) {
      return
    }
    super.keyDown(with: event)
  }

  override func paste(_ sender: Any?) {
    let text = NSPasteboard.general.string(forType: .string) ?? ""
    ParetlyTryTyping.shared.insertRaw(text)
  }

  override func cut(_ sender: Any?) {
    copy(sender)
    ParetlyTryTyping.shared.replaceAll("")
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    guard string.isEmpty, !placeholderText.isEmpty else { return }
    let font = self.font ?? .systemFont(ofSize: NSFont.systemFontSize)
    let attributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: NSColor.placeholderTextColor
    ]
    let padding = (textContainer?.lineFragmentPadding ?? 0) + textContainerInset.width
    let rect = bounds.insetBy(dx: padding, dy: textContainerInset.height)
    (placeholderText as NSString).draw(in: rect, withAttributes: attributes)
  }
}
