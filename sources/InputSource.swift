//
//  InputSource.swift
//  Squirrel
//
//  Created by Leo Liu on 5/10/24.
//

import Foundation
import InputMethodKit

final class SquirrelInstaller {
  enum InputMode: CaseIterable, RawRepresentable {
    static let primary = Self.hans
    case hans
    case hant

    var rawValue: String {
      switch self {
      case .hans: return ParetlyInputSource.modeHans
      case .hant: return ParetlyInputSource.modeHant
      }
    }

    init?(rawValue: String) {
      switch rawValue {
      case ParetlyInputSource.modeHans: self = .hans
      case ParetlyInputSource.modeHant: self = .hant
      default: return nil
      }
    }
  }

  private lazy var inputSources: [String: TISInputSource] = Self.loadInputSources()

  @discardableResult
  func register() -> Bool {
    guard assertConsoleUser(action: "register") else { return false }
    let counts = registrationCounts()
    switch ParetlyInputInstall.step(registeredSourceCount: counts.registered, enabledSourceCount: counts.enabled) {
    case .leaveEnabledSourceAlone, .enableOnly:
      print("Input source already registered; not registering again.")
      return true
    case .registerAndEnable:
      break
    }
    let url = SquirrelApp.registrationBundleURL
    guard FileManager.default.fileExists(atPath: url.path) else {
      print("Input method bundle is missing at \(url.path)")
      return false
    }
    let status = TISRegisterInputSource(url as CFURL)
    print("Register \(status == noErr ? "succeeds" : "fails (\(status))") for \(url.path)")
    return status == noErr
  }

  /// Enables every requested mode. When `modes` is empty and the user already
  /// enabled a subset, that subset is enabled again (a crash or bundle
  /// replacement can leave a mode "enabled" but not selectable). When nothing
  /// is enabled, both Hans and Hant are enabled.
  @discardableResult
  func enable(modes: [InputMode] = []) -> Bool {
    guard assertConsoleUser(action: "enable") else { return false }
    let counts = registrationCounts()
    if ParetlyInputInstall.step(registeredSourceCount: counts.registered, enabledSourceCount: counts.enabled) == .leaveEnabledSourceAlone {
      print("Input source already enabled; not enabling again.")
      return true
    }
    let already = enabledModes()
    let modesToEnable = modes.isEmpty ? (already.isEmpty ? InputMode.allCases : already) : modes
    _ = enableParent()
    var enabledAll = true
    for mode in modesToEnable {
      if !enableSource(id: mode.rawValue) {
        enabledAll = false
      }
    }
    return enabledAll && !modesToEnable.isEmpty
  }

  @discardableResult
  func select(mode: InputMode? = nil) -> Bool {
    guard assertConsoleUser(action: "select") else { return false }
    let modeToSelect = mode ?? .primary
    if !enabledModes().contains(modeToSelect) {
      _ = enable(modes: [modeToSelect])
    }
    guard let inputSource = inputSources[modeToSelect.rawValue] else {
      print("Input source not found: \(modeToSelect.rawValue)")
      return false
    }
    let enabled = getBool(for: inputSource, key: kTISPropertyInputSourceIsEnabled) ?? false
    let selectable = getBool(for: inputSource, key: kTISPropertyInputSourceIsSelectCapable) ?? false
    let selected = getBool(for: inputSource, key: kTISPropertyInputSourceIsSelected) ?? false
    if !enabled {
      print("Cannot select \(modeToSelect.rawValue): not enabled")
      return false
    }
    if !selectable {
      print("Cannot select \(modeToSelect.rawValue): not selectable")
      return false
    }
    if selected {
      print("Already selected \(modeToSelect.rawValue)")
      return true
    }
    let error = TISSelectInputSource(inputSource)
    print("Selection \(error == noErr ? "succeeds" : "fails (\(error))") for input source: \(modeToSelect.rawValue)")
    return error == noErr
  }

  @discardableResult
  func disable(modes: [InputMode] = []) -> Bool {
    guard assertConsoleUser(action: "disable") else { return false }
    let modesToDisable = modes.isEmpty ? InputMode.allCases : modes
    var sawOne = false
    for mode in modesToDisable {
      guard let inputSource = inputSources[mode.rawValue] else {
        print("Input source not found: \(mode.rawValue)")
        continue
      }
      sawOne = true
      if getBool(for: inputSource, key: kTISPropertyInputSourceIsEnabled) == true {
        let error = TISDisableInputSource(inputSource)
        print("Disable \(error == noErr ? "succeeds" : "fails (\(error))") for input source: \(mode.rawValue)")
      }
    }
    return sawOne || modesToDisable.isEmpty
  }

  func enabledModes() -> [InputMode] {
    var enabledModes = Set<InputMode>()
    for mode in InputMode.allCases {
      guard let inputSource = inputSources[mode.rawValue] else { continue }
      if getBool(for: inputSource, key: kTISPropertyInputSourceIsEnabled) == true {
        enabledModes.insert(mode)
      }
    }
    return Array(enabledModes)
  }

  private func registrationCounts() -> (registered: Int, enabled: Int) {
    let ids = ParetlyInputSource.modes + [ParetlyInputSource.bundleIdentifier]
    let registered = ids.reduce(into: 0) { count, id in
      if inputSources[id] != nil {
        count += 1
      }
    }
    return (registered, enabledModes().count)
  }

  private func enableParent() -> Bool {
    enableSource(id: ParetlyInputSource.bundleIdentifier)
  }

  private func enableSource(id: String) -> Bool {
    guard let inputSource = inputSources[id] else {
      print("Input source not found: \(id). Run --register-input-source as the logged-in user first.")
      return false
    }
    // Call even when the enabled bit is already set. After a forced quit the
    // bit can stay true while the menu bar will not offer the source.
    let error = TISEnableInputSource(inputSource)
    print("Enable \(error == noErr ? "succeeds" : "fails (\(error))") for input source: \(id)")
    return error == noErr
  }

  private func assertConsoleUser(action: String) -> Bool {
    if geteuid() == 0 {
      print("Refusing to \(action) the input source as root. TIS updates the current user, and root is not the logged-in console user. Run this command in that user's GUI session, without sudo.")
      return false
    }
    return true
  }

  private func getBool(for inputSource: TISInputSource, key: CFString!) -> Bool? {
    let enabledRef = TISGetInputSourceProperty(inputSource, key)
    guard let enabled = unsafeBitCast(enabledRef, to: CFBoolean?.self) else { return nil }
    return CFBooleanGetValue(enabled)
  }

  private static func loadInputSources() -> [String: TISInputSource] {
    var inputSources = [String: TISInputSource]()
    let sourceList = TISCreateInputSourceList(nil, true).takeRetainedValue() as! [TISInputSource]
    for inputSource in sourceList {
      let sourceIDRef = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID)
      guard let sourceID = unsafeBitCast(sourceIDRef, to: CFString?.self) as String? else { continue }
      inputSources[sourceID] = inputSource
    }
    return inputSources
  }
}
