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
import CoreServices

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

/// Menu bar while Settings, About, or the update UI is on screen.
/// `.regular` is what puts Paretly's menus at the top left. `.accessory`
/// is the input method again: no Dock tile left behind after the window closes.
enum ParetlyActivationChoice: Equatable {
  case accessory
  case regular

  static func forVisibleUI(settings: Bool, about: Bool, update: Bool) -> Self {
    if settings || about || update {
      return .regular
    }
    return .accessory
  }

  var policy: NSApplication.ActivationPolicy {
    switch self {
    case .accessory:
      return .accessory
    case .regular:
      return .regular
    }
  }
}

/// Real process exit (installer `--quit`, logout). A menu Quit only closes
/// Settings and must not set this.
enum ParetlyTermination {
  static var allowExit = false

  static let notificationName = Notification.Name("ParetlyTerminateNotification")

  static func requestExit() {
    allowExit = true
    NSApp.terminate(nil)
  }

  /// Logout, restart, and shutdown must still quit the input method.
  static func systemIsEndingSession(_ event: NSAppleEventDescriptor?) -> Bool {
    guard let event else { return false }
    let reason = event.attributeDescriptor(forKeyword: AEKeyword(quitReason))?.enumCodeValue
    return reason == logOut || reason == reallyLogOut || reason == restart || reason == shutDown
  }

  // 'why?' 'logo' 'rlgo' 'rest' 'shut'
  private static let quitReason: OSType = 0x7768793F
  private static let logOut: OSType = 0x6C6F676F
  private static let reallyLogOut: OSType = 0x726C676F
  private static let restart: OSType = 0x72657374
  private static let shutDown: OSType = 0x73687574
}

/// Settings menu bar. Targets that need the app controllers are closures so
/// layout tests can build the menu without those types.
final class ParetlyMenuActions: NSObject {
  static let shared = ParetlyMenuActions()

  var onAbout: (() -> Void)?
  var onSettings: (() -> Void)?
  var onUpdates: (() -> Void)?
  var onCloseSettings: (() -> Void)?

  @objc func showAbout(_ sender: Any?) { onAbout?() }
  @objc func showSettings(_ sender: Any?) { onSettings?() }
  @objc func checkForUpdates(_ sender: Any?) { onUpdates?() }

  /// Closes Paretly's windows. Does not terminate the input method.
  @objc func closeSettings(_ sender: Any?) { onCloseSettings?() }
}

enum ParetlyMainMenu {
  static func install() {
    let menu = make()
    NSApp.mainMenu = menu
    NSApp.windowsMenu = menu.items.first { $0.submenu != nil && $0.title == menuTitle("Window") }?.submenu
  }

  static func make() -> NSMenu {
    let menu = NSMenu()
    menu.addItem(topItem("Paretly", submenu: appMenu()))
    menu.addItem(topItem("Edit", submenu: editMenu()))
    menu.addItem(topItem("Window", submenu: windowMenu()))
    return menu
  }

  private static func appMenu() -> NSMenu {
    let menu = NSMenu(title: menuTitle("Paretly"))
    menu.addItem(item("About Paretly", action: #selector(ParetlyMenuActions.showAbout(_:)), key: "", modifiers: []))
    menu.addItem(.separator())
    menu.addItem(item("Settings…", action: #selector(ParetlyMenuActions.showSettings(_:)), key: ",", modifiers: [.command]))
    menu.addItem(item("Check for Updates…", action: #selector(ParetlyMenuActions.checkForUpdates(_:)), key: "", modifiers: []))
    menu.addItem(.separator())
    menu.addItem(item("Hide Paretly", action: #selector(NSApplication.hide(_:)), key: "h", modifiers: [.command], target: NSApp))
    menu.addItem(item("Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), key: "h", modifiers: [.command, .option], target: NSApp))
    menu.addItem(item("Show All", action: #selector(NSApplication.unhideAllApplications(_:)), key: "", modifiers: [], target: NSApp))
    menu.addItem(.separator())
    let close = item("Close Settings", action: #selector(ParetlyMenuActions.closeSettings(_:)), key: "q", modifiers: [.command])
    menu.addItem(close)
    return menu
  }

  private static func editMenu() -> NSMenu {
    let menu = NSMenu(title: menuTitle("Edit"))
    menu.addItem(item("Undo", action: Selector(("undo:")), key: "z", modifiers: [.command], target: nil))
    menu.addItem(item("Redo", action: Selector(("redo:")), key: "z", modifiers: [.command, .shift], target: nil))
    menu.addItem(.separator())
    menu.addItem(item("Cut", action: Selector(("cut:")), key: "x", modifiers: [.command], target: nil))
    menu.addItem(item("Copy", action: Selector(("copy:")), key: "c", modifiers: [.command], target: nil))
    menu.addItem(item("Paste", action: Selector(("paste:")), key: "v", modifiers: [.command], target: nil))
    menu.addItem(item("Select All", action: Selector(("selectAll:")), key: "a", modifiers: [.command], target: nil))
    return menu
  }

  private static func windowMenu() -> NSMenu {
    let menu = NSMenu(title: menuTitle("Window"))
    menu.addItem(item("Minimize", action: #selector(NSWindow.performMiniaturize(_:)), key: "m", modifiers: [.command], target: nil))
    menu.addItem(item("Close", action: #selector(NSWindow.performClose(_:)), key: "w", modifiers: [.command], target: nil))
    return menu
  }

  private static func topItem(_ title: String, submenu: NSMenu) -> NSMenuItem {
    let item = NSMenuItem(title: menuTitle(title), action: nil, keyEquivalent: "")
    item.submenu = submenu
    return item
  }

  private static func item(
    _ title: String,
    action: Selector,
    key: String,
    modifiers: NSEvent.ModifierFlags,
    target: AnyObject? = ParetlyMenuActions.shared
  ) -> NSMenuItem {
    let item = NSMenuItem(title: menuTitle(title), action: action, keyEquivalent: key)
    item.keyEquivalentModifierMask = modifiers
    item.target = target
    return item
  }

  private static func menuTitle(_ key: String) -> String {
    NSLocalizedString(key, comment: "Menu")
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
