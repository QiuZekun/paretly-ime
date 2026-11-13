//
//  ParetlyTryField.swift
//  Paretly
//
//  Copyright (C) 2026 Paretly contributors
//
//  This file is part of Paretly, a GPL-3.0 fork of Squirrel (鼠须管).
//  See LICENSE.txt.
//
//  The settings window lives in the input method process, so macOS will not
//  deliver Paretly keystrokes into it. This field runs its own Rime session
//  and shows the real candidate panel beside the insertion point.

import AppKit
import Carbon
import SwiftUI

struct ParetlyTryField: NSViewRepresentable {
  static let identifier = NSUserInterfaceItemIdentifier("ParetlyTryField")

  func makeNSView(context: Context) -> NSTextField {
    let field = NSTextField(string: "")
    field.identifier = Self.identifier
    field.isEditable = true
    field.isSelectable = true
    field.isBezeled = true
    field.bezelStyle = .roundedBezel
    field.font = .systemFont(ofSize: NSFont.systemFontSize)
    field.placeholderString = Self.placeholder
    field.cell?.lineBreakMode = .byTruncatingHead
    field.setAccessibilityLabel(Self.placeholder)
    return field
  }

  func updateNSView(_ field: NSTextField, context: Context) {
    let placeholder = Self.placeholder
    if field.placeholderString != placeholder {
      field.placeholderString = placeholder
      field.setAccessibilityLabel(placeholder)
    }
  }

  private static var placeholder: String {
    NSLocalizedString("Type to try it~", comment: "Settings")
  }
}

final class ParetlyTryFieldEditor: NSTextView {
  static let shared: ParetlyTryFieldEditor = {
    let editor = ParetlyTryFieldEditor()
    editor.isFieldEditor = true
    editor.isRichText = false
    editor.importsGraphics = false
    editor.isAutomaticQuoteSubstitutionEnabled = false
    editor.isAutomaticDashSubstitutionEnabled = false
    editor.isAutomaticDataDetectionEnabled = false
    editor.isAutomaticTextReplacementEnabled = false
    editor.isAutomaticSpellingCorrectionEnabled = false
    editor.isContinuousSpellCheckingEnabled = false
    editor.isGrammarCheckingEnabled = false
    editor.font = .systemFont(ofSize: NSFont.systemFontSize)
    return editor
  }()

  override func becomeFirstResponder() -> Bool {
    let ok = super.becomeFirstResponder()
    if ok {
      ParetlyTryTyping.shared.begin(editor: self)
    }
    return ok
  }

  override func resignFirstResponder() -> Bool {
    ParetlyTryTyping.shared.end()
    return super.resignFirstResponder()
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
        editor?.window?.endEditing(for: nil)
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
    if editor.string != display {
      editor.string = display
    }
    let length = (editor.string as NSString).length
    editor.setSelectedRange(NSRange(location: min(caret, length), length: 0))
  }

  private func showPanel(preedit: String, selRange: NSRange, caret: Int, menu: MenuSnapshot) {
    guard active, let panel = NSApp.squirrelAppDelegate.panel else { return }
    if preedit.isEmpty, menu.candidates.isEmpty {
      hidePanelIfOurs()
      return
    }
    panel.inputController = self
    panel.position = caretScreenRect()
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
    if rect.width > 0 || rect.height > 0 {
      return rect
    }
    return window.convertToScreen(editor.convert(editor.bounds, to: nil))
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
