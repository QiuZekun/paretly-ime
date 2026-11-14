//
//  AppKitSupport.swift
//  Paretly
//
//  Copyright (C) 2026 Paretly contributors
//
//  This file is part of Paretly, a GPL-3.0 fork of Squirrel (鼠须管).
//  See LICENSE.txt.
//
//  Small AppKit helpers that used to live next to the librime bridging
//  code. The candidate-panel tests compile this file; they do not compile
//  librime.

import AppKit

infix operator ?= : AssignmentPrecedence
// swiftlint:disable:next operator_whitespace
func ?=<T>(left: inout T, right: T?) {
  if let right = right {
    left = right
  }
}
// swiftlint:disable:next operator_whitespace
func ?=<T>(left: inout T?, right: T?) {
  if let right = right {
    left = right
  }
}

extension NSRange {
  static let empty = NSRange(location: NSNotFound, length: 0)
}

/// What the settings try-field must drop when librime is redeployed.
///
/// `RimeFinalize` destroys every session. The old id can still pass
/// `find_session` (the id is reused, or the session is findable but has no
/// menu). A matching `schemaId` then skips the theme read that decides
/// inline preedit, and the candidate panel never opens again. `active` stays
/// as it was so a field that is still editing shows the panel on the next
/// key without another `becomeFirstResponder`.
struct ParetlyTryTypingDeployState: Equatable {
  var hasSession: Bool
  var schemaId: String
  var inlinePreedit: Bool
  var active: Bool

  func cleared() -> Self {
    var copy = self
    copy.hasSession = false
    copy.schemaId = ""
    copy.inlinePreedit = true
    return copy
  }
}

extension NSPoint {
  static func += (lhs: inout Self, rhs: Self) {
    lhs.x += rhs.x
    lhs.y += rhs.y
  }
  static func - (lhs: Self, rhs: Self) -> Self {
    Self.init(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
  }
  static func -= (lhs: inout Self, rhs: Self) {
    lhs.x -= rhs.x
    lhs.y -= rhs.y
  }
  static func * (lhs: Self, rhs: CGFloat) -> Self {
    Self.init(x: lhs.x * rhs, y: lhs.y * rhs)
  }
  static func / (lhs: Self, rhs: CGFloat) -> Self {
    Self.init(x: lhs.x / rhs, y: lhs.y / rhs)
  }
  var length: CGFloat {
    sqrt(pow(self.x, 2) + pow(self.y, 2))
  }
}
