//
//  ParetlyUpdateController.swift
//  Paretly
//
//  Copyright (C) 2026 Paretly contributors
//
//  This file is part of Paretly, a GPL-3.0 fork of Squirrel (鼠须管).
//  See LICENSE.txt.
//
//  Updates come from the public GitHub Releases API. The package is
//  unsigned. A verified download is installed in place with administrator
//  privileges; if that fails, Installer opens the package.

import AppKit

struct ParetlyUpdatePreferences {
  static let automaticKey = "ParetlyAutomaticUpdateChecks"
  static let betaKey = "ParetlyIncludeBetaUpdates"
  static let lastCheckKey = "ParetlyLastUpdateCheck"
  static let skippedKey = "ParetlySkippedUpdateVersion"

  var defaults: UserDefaults

  static let shared = ParetlyUpdatePreferences(defaults: .standard)

  var automatic: Bool {
    get {
      if defaults.object(forKey: Self.automaticKey) == nil {
        return true
      }
      return defaults.bool(forKey: Self.automaticKey)
    }
    nonmutating set {
      defaults.set(newValue, forKey: Self.automaticKey)
    }
  }

  /// Off unless this copy was built as a beta, until the user chooses.
  var includeBetas: Bool {
    get {
      if defaults.object(forKey: Self.betaKey) == nil {
        let channel = Bundle.main.object(forInfoDictionaryKey: "ParetlyUpdateChannel") as? String
        return ParetlyRelease.includesBetasByDefault(channel: channel)
      }
      return defaults.bool(forKey: Self.betaKey)
    }
    nonmutating set {
      defaults.set(newValue, forKey: Self.betaKey)
    }
  }

  var lastCheck: Date? {
    get { defaults.object(forKey: Self.lastCheckKey) as? Date }
    nonmutating set { defaults.set(newValue, forKey: Self.lastCheckKey) }
  }

  var skippedVersion: String? {
    get { defaults.string(forKey: Self.skippedKey) }
    nonmutating set { defaults.set(newValue, forKey: Self.skippedKey) }
  }
}

final class ParetlyUpdatePresenter: NSObject, URLSessionDownloadDelegate {
  static let shared = ParetlyUpdatePresenter()

  private var session: URLSession?
  private var expectedAsset: ParetlyReleaseAsset?
  private var checksumAsset: ParetlyReleaseAsset?
  private var finishedDownload = false
  private var progressPanel: NSPanel?

  /// True while the download panel is on screen. Modal alerts cover this
  /// themselves for the length of `runModal`.
  var hasVisibleUI: Bool {
    progressPanel != nil
  }
  private var progressIndicator: NSProgressIndicator?
  private var progressLabel: NSTextField?

  func checkAutomaticallyIfDue() {
    let preferences = ParetlyUpdatePreferences.shared
    guard ParetlyReleaseCatalog.automaticCheckIsDue(
      automatic: preferences.automatic,
      lastCheck: preferences.lastCheck,
      now: Date()
    ) else {
      return
    }
    fetchReleases(manual: false)
  }

  func checkManually() {
    activateForAlert()
    fetchReleases(manual: true)
  }

  private func currentVersion() -> ParetlyVersion? {
    let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    let bundle = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    let channel = Bundle.main.object(forInfoDictionaryKey: "ParetlyUpdateChannel") as? String
    guard let short else {
      return nil
    }
    return ParetlyVersion.installed(shortVersion: short, bundleVersion: bundle ?? "", channel: channel)
  }

  private func fetchReleases(manual: Bool) {
    var request = URLRequest(url: ParetlyRelease.releasesURL)
    request.setValue("Paretly", forHTTPHeaderField: "User-Agent")
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.timeoutInterval = 30
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
      let status = (response as? HTTPURLResponse)?.statusCode
      DispatchQueue.main.async {
        self.handleList(data: data, status: status, error: error, manual: manual)
      }
    }
    task.resume()
  }

  private func handleList(data: Data?, status: Int?, error: Error?, manual: Bool) {
    let fetch = ParetlyReleaseCatalog.interpret(
      statusCode: status,
      data: data,
      transportError: error?.localizedDescription,
      includeBetas: ParetlyUpdatePreferences.shared.includeBetas
    )
    let outcome = ParetlyReleaseCatalog.outcome(
      fetch: fetch,
      current: currentVersion(),
      skipped: ParetlyUpdatePreferences.shared.skippedVersion.flatMap(ParetlyVersion.parse),
      manual: manual
    )
    switch outcome {
    case .failed(let failure):
      if manual {
        inform(
          title: NSLocalizedString("Could not check for updates.", comment: "Update"),
          detail: failureDetail(failure)
        )
      }
    case .missingVersion:
      if manual {
        inform(
          title: NSLocalizedString("Could not check for updates.", comment: "Update"),
          detail: NSLocalizedString("This copy of Paretly has no version number.", comment: "Update")
        )
      }
    case .nothingPublished(let version):
      ParetlyUpdatePreferences.shared.lastCheck = Date()
      if manual {
        inform(
          title: NSLocalizedString("You're up to date", comment: "Update"),
          detail: String(
            format: NSLocalizedString("No newer version has been published yet (current version %@).", comment: "Update"),
            version
          ),
          informational: true
        )
      }
    case .upToDate(let version):
      ParetlyUpdatePreferences.shared.lastCheck = Date()
      if manual {
        inform(
          title: NSLocalizedString("Paretly is up to date.", comment: "Update"),
          detail: String(format: NSLocalizedString("You have version %@.", comment: "Update"), version),
          informational: true
        )
      }
    case .offer(let release):
      ParetlyUpdatePreferences.shared.lastCheck = Date()
      guard let current = currentVersion() else {
        restoreIfIdle()
        return
      }
      offer(release, current: current)
    }
  }

  private func failureDetail(_ failure: ParetlyReleaseFailure) -> String {
    switch failure {
    case .transport(let reason):
      if reason.isEmpty {
        return NSLocalizedString("Paretly could not reach GitHub. Check the network and try again.", comment: "Update")
      }
      return reason
    case .http(let status, let message):
      if message.isEmpty {
        return String(format: NSLocalizedString("GitHub returned HTTP %d.", comment: "Update"), status)
      }
      return String(format: NSLocalizedString("GitHub returned HTTP %d. %@", comment: "Update"), status, message)
    case .unreadable:
      return NSLocalizedString("GitHub returned a response Paretly could not read.", comment: "Update")
    }
  }

  private func offer(_ release: ParetlyRelease, current: ParetlyVersion) {
    let alert = NSAlert()
    alert.messageText = String(
      format: NSLocalizedString("Paretly %@ is available", comment: "Update"),
      release.version.display
    )
    let gatekeeper = NSLocalizedString(
      "Paretly is not signed or notarized, so it will not replace itself quietly. Update Now asks for an administrator password, installs the package in place, and opens the input method again. If that fails, the package opens in Installer. If macOS blocks it, right-click the package and choose Open, or open System Settings > Privacy & Security and choose Open Anyway.",
      comment: "Update"
    )
    let youHave = String(format: NSLocalizedString("You have version %@.", comment: "Update"), current.display)
    alert.informativeText = youHave + "\n\n" + gatekeeper
    if !release.notes.isEmpty {
      alert.accessoryView = notesView(release.notes)
    }
    for title in ParetlyAlertCopy.offerButtonTitleKeys() {
      alert.addButton(withTitle: NSLocalizedString(title, comment: "Update"))
    }
    switch present(alert) {
    case .alertFirstButtonReturn:
      download(release)
    case .alertThirdButtonReturn:
      ParetlyUpdatePreferences.shared.skippedVersion = release.version.display
    default:
      break
    }
    restoreIfIdle()
  }

  private func notesView(_ notes: String) -> NSView {
    let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 420, height: 140))
    let text = NSTextView(frame: NSRect(x: 0, y: 0, width: 420, height: 140))
    text.string = notes
    text.isEditable = false
    text.isSelectable = true
    text.drawsBackground = false
    text.font = NSFont.systemFont(ofSize: 12)
    text.textContainerInset = NSSize(width: 0, height: 4)
    scroll.documentView = text
    scroll.hasVerticalScroller = true
    scroll.autohidesScrollers = true
    scroll.drawsBackground = false
    return scroll
  }

  private func download(_ release: ParetlyRelease) {
    expectedAsset = release.installer
    checksumAsset = release.checksum
    finishedDownload = false
    showProgress(title: String(
      format: NSLocalizedString("Downloading Paretly %@…", comment: "Update"),
      release.version.display
    ))
    let configuration = URLSessionConfiguration.ephemeral
    let session = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
    self.session = session
    var request = URLRequest(url: release.installer.downloadURL)
    request.setValue("Paretly", forHTTPHeaderField: "User-Agent")
    session.downloadTask(with: request).resume()
  }

  private func showProgress(title: String) {
    let panel = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 360, height: 92),
      styleMask: [.titled],
      backing: .buffered,
      defer: false
    )
    panel.title = NSLocalizedString("Paretly", comment: "Menu title")
    let label = NSTextField(labelWithString: title)
    label.frame = NSRect(x: 20, y: 52, width: 320, height: 20)
    let indicator = NSProgressIndicator(frame: NSRect(x: 20, y: 24, width: 320, height: 16))
    indicator.isIndeterminate = true
    indicator.startAnimation(nil)
    panel.contentView?.addSubview(label)
    panel.contentView?.addSubview(indicator)
    panel.center()
    panel.makeKeyAndOrderFront(nil)
    progressPanel = panel
    progressIndicator = indicator
    progressLabel = label
  }

  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
    let expected = expectedAsset?.byteCount ?? 0
    let total = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : Int64(expected)
    guard total > 0, let indicator = progressIndicator else {
      return
    }
    indicator.isIndeterminate = false
    indicator.doubleValue = Double(totalBytesWritten) / Double(total) * 100
  }

  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    finishedDownload = true
    let asset = expectedAsset
    let checksum = checksumAsset
    if let response = downloadTask.response as? HTTPURLResponse, !(200..<300).contains(response.statusCode) {
      closeProgress()
      session.finishTasksAndInvalidate()
      self.session = nil
      inform(
        title: NSLocalizedString("Could not check for updates.", comment: "Update"),
        detail: NSLocalizedString("Paretly could not reach GitHub. Check the network and try again.", comment: "Update")
      )
      return
    }
    closeProgress()
    session.finishTasksAndInvalidate()
    self.session = nil
    guard let asset else {
      return
    }
    do {
      let data = try Data(contentsOf: location)
      if asset.byteCount > 0 && data.count != asset.byteCount {
        inform(
          title: NSLocalizedString("The download could not be verified.", comment: "Update"),
          detail: NSLocalizedString("The package size does not match the GitHub release.", comment: "Update")
        )
        return
      }
      if let checksum {
        try verifyChecksum(checksum, data: data)
      }
      let destination = try installDownload(data)
      if checksum != nil && installWithAdministratorPrivileges(destination) {
        relaunchInstalledCopy()
        inform(
          title: NSLocalizedString("Paretly was updated.", comment: "Update"),
          detail: NSLocalizedString("The input method is opening again.", comment: "Update"),
          informational: true
        )
        return
      }
      NSWorkspace.shared.open(destination)
      inform(
        title: NSLocalizedString("The installer is open.", comment: "Update"),
        detail: NSLocalizedString("Automatic install did not finish. Finish installing in Installer.", comment: "Update")
      )
    } catch let error as UpdateFailure {
      inform(title: error.title, detail: error.detail)
    } catch {
      inform(
        title: NSLocalizedString("The download could not be verified.", comment: "Update"),
        detail: error.localizedDescription
      )
    }
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    if finishedDownload {
      return
    }
    guard let error else {
      return
    }
    closeProgress()
    session.finishTasksAndInvalidate()
    self.session = nil
    inform(
      title: NSLocalizedString("Could not check for updates.", comment: "Update"),
      detail: error.localizedDescription
    )
  }

  private func verifyChecksum(_ asset: ParetlyReleaseAsset, data: Data) throws {
    var request = URLRequest(url: asset.downloadURL)
    request.setValue("Paretly", forHTTPHeaderField: "User-Agent")
    let semaphore = DispatchSemaphore(value: 0)
    var body: Data?
    var failed = false
    URLSession.shared.dataTask(with: request) { downloaded, _, error in
      body = downloaded
      failed = error != nil
      semaphore.signal()
    }.resume()
    semaphore.wait()
    if failed || body == nil {
      throw UpdateFailure(
        title: NSLocalizedString("The download could not be verified.", comment: "Update"),
        detail: NSLocalizedString("Paretly could not download the release checksum.", comment: "Update")
      )
    }
    let text = String(data: body ?? Data(), encoding: .utf8) ?? ""
    if !ParetlyChecksum.matches(data: data, publishedDigest: text) {
      throw UpdateFailure(
        title: NSLocalizedString("The download could not be verified.", comment: "Update"),
        detail: NSLocalizedString("The package does not match the published SHA-256 checksum.", comment: "Update")
      )
    }
  }

  private func installDownload(_ data: Data) throws -> URL {
    let downloads = try FileManager.default.url(
      for: .downloadsDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    let destination = downloads.appendingPathComponent(ParetlyRelease.packageName)
    if FileManager.default.fileExists(atPath: destination.path) {
      try FileManager.default.removeItem(at: destination)
    }
    try data.write(to: destination, options: .atomic)
    return destination
  }

  /// Standard macOS password dialog, then an in-place install. The package scripts stop Paretly and register the new copy.
  private func installWithAdministratorPrivileges(_ package: URL) -> Bool {
    let quoted = package.path
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
    let source = """
    do shell script "xattr -dr com.apple.quarantine \\"\(quoted)\\" && /usr/sbin/installer -pkg \\"\(quoted)\\" -target /" with administrator privileges
    """
    var error: NSDictionary?
    guard let script = NSAppleScript(source: source) else {
      return false
    }
    _ = script.executeAndReturnError(&error)
    return error == nil
  }

  private func relaunchInstalledCopy() {
    let app = URL(fileURLWithPath: "/Library/Input Methods/Paretly.app", isDirectory: true)
    guard FileManager.default.fileExists(atPath: app.path) else {
      return
    }
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.createsNewApplicationInstance = true
    NSWorkspace.shared.openApplication(at: app, configuration: configuration) { _, _ in
      DispatchQueue.main.async {
        NSApp.terminate(nil)
      }
    }
  }

  private func closeProgress() {
    progressPanel?.close()
    progressPanel = nil
    progressIndicator = nil
    progressLabel = nil
  }

  private func inform(title: String, detail: String, informational: Bool = false) {
    let alert = NSAlert()
    alert.alertStyle = informational ? .informational : .warning
    alert.messageText = title
    alert.informativeText = detail
    alert.addButton(withTitle: NSLocalizedString(ParetlyAlertCopy.okButton, comment: "Update"))
    _ = present(alert)
    restoreIfIdle()
  }

  @discardableResult
  private func present(_ alert: NSAlert) -> NSApplication.ModalResponse {
    alert.messageText = ParetlyAlertCopy.displayTitle(alert.messageText)
    if let icon = ParetlyAppIcon.image {
      alert.icon = icon
    }
    if alert.buttons.count >= 2 {
      alert.buttons[1].keyEquivalent = "\u{1b}"
    }
    activateForAlert()
    alert.window.level = .floating
    alert.window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    return alert.runModal()
  }

  private func activateForAlert() {
    ParetlyWindowActivation.promote()
    if #available(macOS 14.0, *) {
      NSApp.activate()
    } else {
      NSApp.activate(ignoringOtherApps: true)
    }
  }

  private func restoreIfIdle() {
    ParetlyWindowActivation.sync()
  }
}

private struct UpdateFailure: Error {
  var title: String
  var detail: String
}
