//
//  main.swift
//  Paretly Launcher
//
//  Copyright (C) 2026 Paretly contributors
//
//  This file is part of Paretly, a GPL-3.0 fork of Squirrel (鼠须管).
//  See LICENSE.txt.
//
//  Launchpad indexes apps in /Applications. This process is an LSUIElement,
//  so the Dock never gives it a tile. It asks the running input method to
//  present Settings and exits. It does not launch a second copy of the
//  input-method bundle, and it does not change its own activation policy
//  on the way (that call waits on the Dock and leaves the tile in place).

import AppKit

private let inputMethodBundleID = "com.qiuzekun.inputmethod.Paretly"
private let showSettingsNotification = Notification.Name("ParetlyShowSettingsNotification")

private func inputMethodURL() -> URL? {
  let home = FileManager.default.homeDirectoryForCurrentUser
  let candidates = [
    URL(fileURLWithPath: "/Library/Input Methods/Paretly.app", isDirectory: true),
    home.appendingPathComponent("Library/Input Methods/Paretly.app", isDirectory: true)
  ]
  return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
}

private func fail(_ title: String, _ detail: String) -> Never {
  let app = NSApplication.shared
  app.setActivationPolicy(.regular)
  if #available(macOS 14.0, *) {
    app.activate()
  } else {
    app.activate(ignoringOtherApps: true)
  }
  let alert = NSAlert()
  alert.messageText = title
  alert.informativeText = detail
  alert.runModal()
  exit(1)
}

let title = NSLocalizedString("Paretly is not installed", comment: "Launcher alert")
let missing = NSLocalizedString(
  "Install Paretly from the package, then open this app again. The input method has to be in /Library/Input Methods or ~/Library/Input Methods.",
  comment: "Launcher alert"
)
let failed = NSLocalizedString("Could not open Paretly Settings.", comment: "Launcher alert")

guard let appURL = inputMethodURL() else {
  fail(title, missing)
}
let executable = appURL.appendingPathComponent("Contents/MacOS/Paretly")
guard FileManager.default.isExecutableFile(atPath: executable.path) else {
  fail(title, missing)
}

let alreadyRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: inputMethodBundleID).isEmpty
if alreadyRunning {
  // The running input method observes this name and presents Settings.
  // deliverImmediately sends it before this process exits. Spawning the
  // input-method binary here loads librime just to post the same name.
  DistributedNotificationCenter.default().post(
    name: showSettingsNotification,
    object: nil,
    userInfo: nil,
    deliverImmediately: true
  )
  exit(EXIT_SUCCESS)
}

// Nothing is serving the input method yet. Detach one server so exiting
// does not send SIGHUP. Launch Services' open would start another instance
// of this bundle and give that instance a Dock tile.
let process = Process()
process.executableURL = URL(fileURLWithPath: "/bin/sh")
process.arguments = [
  "-c",
  "/usr/bin/nohup \"$1\" --show-settings >/dev/null 2>&1 &",
  "sh",
  executable.path
]
process.standardOutput = FileHandle.nullDevice
process.standardError = FileHandle.nullDevice
do {
  try process.run()
  process.waitUntilExit()
} catch {
  fail(failed, error.localizedDescription)
}
if process.terminationStatus != 0 {
  fail(failed, "")
}
exit(EXIT_SUCCESS)
