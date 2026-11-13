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
import Carbon
import SwiftUI

struct ParetlyTryField: NSViewRepresentable {
  static let identifier = NSUserInterfaceItemIdentifier("ParetlyTryField")

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
    textView.isOpaque = false
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
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var intrinsicContentSize: NSSize {
    NSSize(width: NSView.noIntrinsicMetric, height: 24)
  }

  override func layout() {
    super.layout()
    focusRing.frame = bounds
    var interior = cell.titleRect(forBounds: bounds)
    if interior.height < 14 || interior.width < 8 {
      interior = bounds.insetBy(dx: 6, dy: 3)
    }
    textView.frame = interior
    let font = textView.font ?? .systemFont(ofSize: NSFont.systemFontSize)
    let line = ceil(font.ascender - font.descender + font.leading)
    let extra = max(0, interior.height - line) / 2
    textView.textContainerInset = NSSize(width: 1, height: extra)
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

final class ParetlyTryTyping: SquirrelPanelInput {
  static let shared = ParetlyTryTyping()

  private var editor: NSTextView?
  private var committed = ""
  private var active = false
  private var session: RimeSessionId = 0
  private var schemaId = ""
  private var inlinePreedit = true

  private var rimeAPI: RimeApi_stdbool {
    NSApp.squirrelAppDelegate.rimeAPI
  }

  func begin(editor: NSTextView) {
    self.editor = editor
    if !active {
      committed = editor.string
      active = true
    }
  }

  func end() {
    guard active else { return }
    active = false
    editor?.string = committed
    hidePanelIfOurs()
    destroySession()
    editor = nil
  }

  /// True when the field consumed the key.
  func handle(_ event: NSEvent, editor: NSTextView) -> Bool {
    self.editor = editor
    guard ensureSession() else { return false }
    syncPanelOptions()
    let consumed = process(event)
    refresh()
    if consumed {
      return true
    }
    if event.modifierFlags.contains(.control) {
      return true
    }
    if event.keyCode == 53 {
      DispatchQueue.main.async { [weak editor] in
        editor?.window?.makeFirstResponder(nil)
      }
      return true
    }
    if event.keyCode == 36 || event.keyCode == 76 {
      return true
    }
    return insertUnhandled(event)
  }

  func insertRaw(_ text: String) {
    let clean = text.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\r", with: "")
    guard !clean.isEmpty else { return }
    if session != 0 {
      _ = rimeAPI.process_key(session, Int32(XK_Escape), 0)
      refresh()
    }
    committed += clean
    showField(preedit: "", caretInPreedit: 0, inline: false)
    hidePanelIfOurs()
  }

  func replaceAll(_ text: String) {
    if session != 0 {
      _ = rimeAPI.process_key(session, Int32(XK_Escape), 0)
    }
    committed = text.replacingOccurrences(of: "\n", with: "")
    showField(preedit: "", caretInPreedit: 0, inline: false)
    hidePanelIfOurs()
  }

  func selectCandidate(_ index: Int) -> Bool {
    guard session != 0 else { return false }
    let success = rimeAPI.select_candidate_on_current_page(session, index)
    if success {
      refresh()
    }
    return success
  }

  func page(up: Bool) -> Bool {
    guard session != 0 else { return false }
    let handled = rimeAPI.change_page(session, up)
    if handled {
      refresh()
    }
    return handled
  }

  func moveCaret(forward: Bool) -> Bool {
    guard session != 0, let input = rimeAPI.get_input(session) else { return false }
    let current = rimeAPI.get_caret_pos(session)
    if forward {
      if current <= 0 {
        return false
      }
      rimeAPI.set_caret_pos(session, current - 1)
    } else {
      let inputStr = String(cString: input)
      if current >= inputStr.utf8.count {
        return false
      }
      rimeAPI.set_caret_pos(session, current + 1)
    }
    refresh()
    return true
  }

  private func ensureSession() -> Bool {
    if session != 0, rimeAPI.find_session(session) {
      return true
    }
    session = rimeAPI.create_session()
    schemaId = ""
    guard session != 0 else { return false }
    let bundleID = Bundle.main.bundleIdentifier ?? ParetlyInputSource.bundleIdentifier
    if let appOptions = NSApp.squirrelAppDelegate.config?.getAppOptions(bundleID) {
      for (key, value) in appOptions {
        rimeAPI.set_option(session, key, value)
      }
    }
    return true
  }

  private func destroySession() {
    if session != 0 {
      _ = rimeAPI.destroy_session(session)
      session = 0
    }
    schemaId = ""
  }

  private func syncPanelOptions() {
    guard session != 0, let panel = NSApp.squirrelAppDelegate.panel else { return }
    if panel.linear != rimeAPI.get_option(session, "_linear") {
      rimeAPI.set_option(session, "_linear", panel.linear)
    }
    if panel.vertical != rimeAPI.get_option(session, "_vertical") {
      rimeAPI.set_option(session, "_vertical", panel.vertical)
    }
  }

  private func process(_ event: NSEvent) -> Bool {
    let modifiers = event.modifierFlags
    var keyChars = event.charactersIgnoringModifiers
    let capital = modifiers.isSubset(of: [.shift, .capsLock])
    if let code = keyChars?.first,
       (capital && !code.isLetter) || (!capital && !code.isASCII) {
      keyChars = event.characters
    }
    guard let char = keyChars?.first else { return false }
    let keycode = SquirrelKeycode.osxKeycodeToRime(
      keycode: event.keyCode,
      keychar: char,
      shift: modifiers.contains(.shift),
      caps: modifiers.contains(.capsLock)
    )
    guard keycode != 0, keycode != UInt32(XK_VoidSymbol) else { return false }
    let rimeModifiers = SquirrelKeycode.osxModifiersToRime(modifiers: modifiers)
    return rimeAPI.process_key(session, Int32(keycode), Int32(rimeModifiers))
  }

  private func refresh() {
    guard session != 0 else { return }
    consumeCommit()
    noteSchema()
    var ctx = RimeContext_stdbool.rimeStructInit()
    guard rimeAPI.get_context(session, &ctx) else {
      showField(preedit: "", caretInPreedit: 0, inline: inlinePreedit)
      hidePanelIfOurs()
      return
    }
    defer { _ = rimeAPI.free_context(&ctx) }
    let preedit = ctx.composition.preedit.map { String(cString: $0) } ?? ""
    let start = index(in: preedit, utf8: Int(ctx.composition.sel_start))
    let end = index(in: preedit, utf8: Int(ctx.composition.sel_end))
    let caret = index(in: preedit, utf8: Int(ctx.composition.cursor_pos))
    let selRange = NSRange(
      location: start.utf16Offset(in: preedit),
      length: preedit.utf16.distance(from: start, to: end)
    )
    let caretPos = caret.utf16Offset(in: preedit)
    let menu = readMenu(ctx)
    showField(preedit: preedit, caretInPreedit: caretPos, inline: inlinePreedit)
    showPanel(preedit: inlinePreedit ? "" : preedit, selRange: selRange, caret: caretPos, menu: menu)
  }

  private func consumeCommit() {
    var commitText = RimeCommit.rimeStructInit()
    guard rimeAPI.get_commit(session, &commitText) else { return }
    defer { _ = rimeAPI.free_commit(&commitText) }
    if let text = commitText.text {
      committed += String(cString: text)
    }
  }

  private func noteSchema() {
    var status = RimeStatus_stdbool.rimeStructInit()
    guard rimeAPI.get_status(session, &status) else { return }
    defer { _ = rimeAPI.free_status(&status) }
    guard let schema = status.schema_id else { return }
    let name = String(cString: schema)
    guard schemaId != name else { return }
    schemaId = name
    NSApp.squirrelAppDelegate.loadSettings(for: name)
    guard let panel = NSApp.squirrelAppDelegate.panel else { return }
    inlinePreedit = (panel.inlinePreedit && !rimeAPI.get_option(session, "no_inline")) || rimeAPI.get_option(session, "inline")
    rimeAPI.set_option(session, "soft_cursor", !inlinePreedit)
  }

  private struct MenuSnapshot {
    var candidates: [String] = []
    var comments: [String] = []
    var labels: [String] = []
    var highlighted = 0
    var page = 0
    var lastPage = true
  }

  private func readMenu(_ ctx: RimeContext_stdbool) -> MenuSnapshot {
    let count = Int(ctx.menu.num_candidates)
    var candidates = [String]()
    var comments = [String]()
    if count > 0 {
      for index in 0..<count {
        let candidate = ctx.menu.candidates[index]
        candidates.append(candidate.text.map { String(cString: $0) } ?? "")
        comments.append(candidate.comment.map { String(cString: $0) } ?? "")
      }
    }
    var labels = [String]()
    // swiftlint:disable identifier_name
    if let select_keys = ctx.menu.select_keys {
      labels = String(cString: select_keys).map { String($0) }
    } else if let select_labels = ctx.select_labels {
      let pageSize = Int(ctx.menu.page_size)
      for index in 0..<pageSize {
        labels.append(select_labels[index].map { String(cString: $0) } ?? "")
      }
    }
    // swiftlint:enable identifier_name
    var menu = MenuSnapshot()
    menu.candidates = candidates
    menu.comments = comments
    menu.labels = labels
    menu.highlighted = Int(ctx.menu.highlighted_candidate_index)
    menu.page = Int(ctx.menu.page_no)
    menu.lastPage = ctx.menu.is_last_page
    return menu
  }

  private func showField(preedit: String, caretInPreedit: Int, inline: Bool) {
    guard let editor else { return }
    let display = inline ? committed + preedit : committed
    let caret: Int
    if inline {
      caret = (committed as NSString).length + min(max(0, caretInPreedit), (preedit as NSString).length)
    } else {
      caret = (display as NSString).length
    }
    let font = editor.font ?? .systemFont(ofSize: NSFont.systemFontSize)
    if editor.string != display {
      editor.string = display
    }
    let total = (editor.string as NSString).length
    let base: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: NSColor.labelColor
    ]
    if total > 0 {
      editor.textStorage?.setAttributes(base, range: NSRange(location: 0, length: total))
    }
    if inline, !preedit.isEmpty {
      let start = (committed as NSString).length
      let length = (preedit as NSString).length
      if length > 0, start + length <= total {
        editor.textStorage?.addAttribute(
          .underlineStyle,
          value: NSUnderlineStyle.single.rawValue,
          range: NSRange(location: start, length: length)
        )
      }
    }
    let length = (editor.string as NSString).length
    let range = NSRange(location: min(caret, length), length: 0)
    editor.setSelectedRange(range)
    editor.scrollRangeToVisible(range)
  }

  private func showPanel(preedit: String, selRange: NSRange, caret: Int, menu: MenuSnapshot) {
    guard active, let panel = NSApp.squirrelAppDelegate.panel else { return }
    if preedit.isEmpty, menu.candidates.isEmpty {
      hidePanelIfOurs()
      return
    }
    panel.inputController = self
    panel.position = caretScreenRect()
    if let window = editor?.window {
      panel.anchorAbove(window)
    }
    panel.update(
      preedit: preedit,
      selRange: selRange,
      caretPos: caret,
      candidates: menu.candidates,
      comments: menu.comments,
      labels: menu.labels,
      highlighted: menu.highlighted,
      page: menu.page,
      lastPage: menu.lastPage,
      update: true
    )
  }

  private func hidePanelIfOurs() {
    guard let panel = NSApp.squirrelAppDelegate.panel, owns(panel) else { return }
    panel.inputController = nil
    panel.hide()
  }

  private func owns(_ panel: SquirrelPanel) -> Bool {
    panel.inputController === self
  }

  private func caretScreenRect() -> NSRect {
    guard let editor, let window = editor.window else { return .zero }
    if let container = editor.textContainer {
      editor.layoutManager?.ensureLayout(for: container)
    }
    var actual = NSRange(location: NSNotFound, length: 0)
    let rect = editor.firstRect(forCharacterRange: editor.selectedRange(), actualRange: &actual)
    if rect.height >= 1, NSScreen.screens.contains(where: { $0.frame.intersects(rect) }) {
      var caret = rect
      if caret.width < 1 {
        caret.size.width = 1
      }
      return caret
    }
    let local = editor.bounds.isEmpty ? editor.superview?.bounds ?? editor.bounds : editor.bounds
    let screen = window.convertToScreen(editor.convert(local, to: nil))
    if screen.height >= 1 {
      return screen
    }
    return window.frame
  }

  private func insertUnhandled(_ event: NSEvent) -> Bool {
    if event.keyCode == 51 || event.keyCode == 117 {
      guard !committed.isEmpty else { return true }
      committed.removeLast()
      showField(preedit: "", caretInPreedit: 0, inline: false)
      return true
    }
    guard let text = event.characters, !text.isEmpty else { return false }
    let printable = text.unicodeScalars.allSatisfy { $0.value >= 0x20 && $0.value < 0xF700 }
    guard printable else { return false }
    committed.append(contentsOf: text)
    showField(preedit: "", caretInPreedit: 0, inline: false)
    return true
  }

  private func index(in text: String, utf8 offset: Int) -> String.Index {
    let clamped = min(max(0, offset), text.utf8.count)
    let utf8Index = text.utf8.index(text.utf8.startIndex, offsetBy: clamped)
    return String.Index(utf8Index, within: text) ?? text.endIndex
  }
}
