//
//  ParetlyTryTypingStub.swift
//  Paretly
//
//  Copyright (C) 2026 Paretly contributors
//
//  This file is part of Paretly, a GPL-3.0 fork of Squirrel (鼠须管).
//  See LICENSE.txt.
//
//  Stand-in for the app-target Rime session. Layout tests compile the try
//  field without librime; they never start a session.

import AppKit

final class ParetlyTryTyping {
  static let shared = ParetlyTryTyping()

  func begin(editor: NSTextView) {}

  func end() {}

  func handle(_ event: NSEvent, editor: NSTextView) -> Bool { false }

  func insertRaw(_ text: String) {}

  func replaceAll(_ text: String) {}
}
