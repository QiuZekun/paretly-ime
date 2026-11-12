//
//  main.swift
//  Paretly Launcher
//
//  Copyright (C) 2026 Paretly contributors
//
//  This file is part of Paretly, a GPL-3.0 fork of Squirrel (鼠须管).
//  See LICENSE.txt.
//
//  Launchpad only indexes ordinary apps. The input method is an LSUIElement
//  bundle in /Library/Input Methods, so this process asks that bundle to
//  present Paretly Settings and then exits.

import AppKit

private let inputMethodBundleID = "com.qiuzekun.inputmethod.Paretly"

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
let process = Process()
if alreadyRunning {
  // The running input method observes ParetlyShowSettingsNotification and
  // presents its settings window. This process exits as soon as it posts.
  process.executableURL = executable
  process.arguments = ["--show-settings"]
} else {
  // This invocation becomes the input method server. Detach it so quitting
  // the launcher does not send SIGHUP to that server.
  process.executableURL = URL(fileURLWithPath: "/bin/sh")
  process.arguments = [
    "-c",
    "/usr/bin/nohup \"$1\" --show-settings >/dev/null 2>&1 &",
    "sh",
    executable.path
  ]
}
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
