//
//  Main.swift
//  Squirrel
//
//  Created by Leo Liu on 5/10/24.
//

import Foundation
import InputMethodKit

@main
struct SquirrelApp {
  /// Shared with Squirrel at `~/Library/Rime`. Frontend files are `paretly.yaml`
  /// and `paretly.custom.yaml`, `app_name` is `rime.paretly`, and logs go to
  /// `$TMPDIR/rime.paretly`. Do not move this without migrating existing users.
  static let userDir = if let pwuid = getpwuid(getuid()) {
    URL(fileURLWithFileSystemRepresentation: pwuid.pointee.pw_dir, isDirectory: true, relativeTo: nil).appending(components: "Library", "Rime")
  } else {
    try! FileManager.default.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent("Rime", isDirectory: true)
  }
  // Squirrel 1.1.2 hardcoded "/Library/Input Library/Squirrel.app", which is not
  // where macOS loads input methods. Prefer an installed copy in either
  // Input Methods directory, then the running bundle if it already lives there.
  static let appDir: URL = {
    let home = FileManager.default.homeDirectoryForCurrentUser
    let candidates = [
      URL(fileURLWithPath: "/Library/Input Methods/Paretly.app", isDirectory: true),
      home.appendingPathComponent("Library/Input Methods/Paretly.app", isDirectory: true)
    ]
    let fm = FileManager.default
    for candidate in candidates where fm.fileExists(atPath: candidate.path) {
      return candidate
    }
    let bundleURL = Bundle.main.bundleURL
    if bundleURL.lastPathComponent == "Paretly.app" && bundleURL.path.contains("/Input Methods/") {
      return bundleURL
    }
    return candidates[0]
  }()
  /// The bundle `TISRegisterInputSource` should record. Prefer the running
  /// app so an upgrade registers the copy that was just installed, not a
  /// different Paretly.app that happens to exist on disk.
  static var registrationBundleURL: URL {
    let bundleURL = Bundle.main.bundleURL
    if bundleURL.lastPathComponent == "Paretly.app" {
      return bundleURL
    }
    return appDir
  }
  static let logDir = FileManager.default.temporaryDirectory.appending(component: "rime.paretly", directoryHint: .isDirectory)
  // Set by `--show-settings` when this process is the one that will become the server.
  static var presentSettingsOnLaunch = false

  // swiftlint:disable:next cyclomatic_complexity
  static func main() {
    // librime stays unloaded until this process is actually the server or a
    // --build. --show-settings only posts a notification when a server is
    // already running, and loading the library first is what made that path slow.
    let handled = autoreleasepool {
      let installer = SquirrelInstaller()
      let args = CommandLine.arguments
      if args.count > 1 {
        switch args[1] {
        case "--quit":
          // A menu Quit only closes Settings. This notification is the
          // installer's request to actually exit.
          DistributedNotificationCenter.default().postNotificationName(
            ParetlyTermination.notificationName,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
          )
          return true
        case "--reload":
          DistributedNotificationCenter.default().postNotificationName(.init("ParetlyReloadNotification"), object: nil)
          return true
        case "--register-input-source", "--install":
          if !installer.register() {
            exit(EXIT_FAILURE)
          }
          return true
        case "--enable-input-source":
          if args.count > 2 {
            let modes = args[2...].map { SquirrelInstaller.InputMode(rawValue: $0) }.compactMap { $0 }
            if !modes.isEmpty {
              if !installer.enable(modes: modes) {
                exit(EXIT_FAILURE)
              }
              return true
            }
          }
          if !installer.enable() {
            exit(EXIT_FAILURE)
          }
          return true
        case "--disable-input-source":
          if args.count > 2 {
            let modes = args[2...].map { SquirrelInstaller.InputMode(rawValue: $0) }.compactMap { $0 }
            if !modes.isEmpty {
              if !installer.disable(modes: modes) {
                exit(EXIT_FAILURE)
              }
              return true
            }
          }
          if !installer.disable() {
            exit(EXIT_FAILURE)
          }
          return true
        case "--select-input-source":
          let selected: Bool
          if args.count > 2, let mode = SquirrelInstaller.InputMode(rawValue: args[2]) {
            selected = installer.select(mode: mode)
          } else {
            selected = installer.select()
          }
          if !selected {
            exit(EXIT_FAILURE)
          }
          return true
        case "--build":
          // Notification
          SquirrelApplicationDelegate.showMessage(msgText: NSLocalizedString("deploy_update", comment: ""))
          // Build all schemas in current directory
          let rimeAPI: RimeApi_stdbool = rime_get_api_stdbool().pointee
          var builderTraits = RimeTraits.rimeStructInit()
          builderTraits.setCString("rime.paretly-builder", to: \.app_name)
          rimeAPI.setup(&builderTraits)
          rimeAPI.deployer_initialize(nil)
          _ = rimeAPI.deploy()
          rimeAPI.finalize()
          return true
        case "--sync":
          DistributedNotificationCenter.default().postNotificationName(.init("ParetlySyncNotification"), object: nil)
          return true
        case "--show-settings":
          let bundleId = Bundle.main.bundleIdentifier!
          let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
          if !others.isEmpty {
            DistributedNotificationCenter.default().postNotificationName(
              .init("ParetlyShowSettingsNotification"),
              object: nil,
              userInfo: nil,
              deliverImmediately: true
            )
            return true
          }
          SquirrelApp.presentSettingsOnLaunch = true
          break
        case "--help":
          print(helpDoc)
          return true
        default:
          break
        }
      }
      return false
    }
    if handled {
      return
    }

    let rimeAPI: RimeApi_stdbool = rime_get_api_stdbool().pointee
    autoreleasepool {
      // find the bundle identifier and then initialize the input method server
      let main = Bundle.main
      let connectionName = main.object(forInfoDictionaryKey: "InputMethodConnectionName") as! String
      _ = IMKServer(name: connectionName, bundleIdentifier: main.bundleIdentifier!)
      // LSUIElement in Info.plist makes this an agent before main runs.
      // Do not call setActivationPolicy here. Switching an agent to .regular
      // later leaves the agent tile and adds a second Dock tile.
      let app = NSApplication.shared
      let delegate = SquirrelApplicationDelegate()
      app.delegate = delegate

      // opencc will be configured with relative dictionary paths
      FileManager.default.changeCurrentDirectoryPath(main.sharedSupportPath!)

      if NSApp.squirrelAppDelegate.problematicLaunchDetected() {
        print("Problematic launch detected!")
        let args = ["Problematic launch detected! Paretly may be suffering a crash due to improper configuration. Revert previous modifications to see if the problem recurs."]
        let task = Process()
        task.executableURL = "/usr/bin/say".withCString { dir in
          URL(fileURLWithFileSystemRepresentation: dir, isDirectory: false, relativeTo: nil)
        }
        task.arguments = args
        try? task.run()
      } else {
        NSApp.squirrelAppDelegate.setupRime()
        NSApp.squirrelAppDelegate.startRime(fullCheck: false)
        NSApp.squirrelAppDelegate.loadSettings()
        print("Paretly reporting!")
      }

      if SquirrelApp.presentSettingsOnLaunch {
        DispatchQueue.main.async {
          NSApp.squirrelAppDelegate.openSettings()
        }
      }
      DispatchQueue.main.async {
        ParetlyUpdatePresenter.shared.checkAutomaticallyIfDue()
      }

      // finally run everything
      app.run()
      print("Paretly is quitting...")
      rimeAPI.finalize()
    }
    return
  }

  static let helpDoc = """
Supported arguments:
Perform actions:
  --quit                     quit all Paretly processes
  --reload                   deploy
  --show-settings            open Paretly Settings
  --sync                     sync user data
  --build                    build all schemas in current directory
Install Paretly (run as the logged-in user, not sudo):
  --install, --register-input-source    register this app bundle
  --enable-input-source [source id...]  Hans and Hant when omitted and none are on
  --disable-input-source [source id...] input source list optional
  --select-input-source [source id]     defaults to Hans
Mode ids:
  com.qiuzekun.inputmethod.Paretly.Hans
  com.qiuzekun.inputmethod.Paretly.Hant
"""
}
