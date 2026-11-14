//
//  ParetlyRelease.swift
//  Paretly
//
//  Copyright (C) 2026 Paretly contributors
//
//  This file is part of Paretly, a GPL-3.0 fork of Squirrel (鼠须管).
//  See LICENSE.txt.

import CryptoKit
import Foundation

/// Version from a tag such as `v0.1.0` or a beta title `0.1.0-beta.12`.
///
/// Semver core is compared first. The build number is the tiebreaker: a beta's
/// number is the CI run number, and a stable release with no build number sorts
/// as build 0. A newer beta of the same core is therefore newer than that stable
/// release, which is what the beta channel offers. A higher core still wins, so
/// `0.2.0` is newer than `0.1.0-beta.100`.
struct ParetlyVersion: Equatable, Comparable {
  let components: [Int]
  /// Set for `0.1.0-beta.N`. Nil for a stable release.
  let betaBuild: Int?
  /// CFBundleVersion of this copy when it is a plain integer. Nil for a release parsed from GitHub.
  let ciBuild: Int?

  /// `1.2` and `1.2.0` are the same version.
  static func == (lhs: ParetlyVersion, rhs: ParetlyVersion) -> Bool {
    return !(lhs < rhs) && !(rhs < lhs)
  }

  static func parse(_ raw: String) -> ParetlyVersion? {
    var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if text.first == "v" || text.first == "V" {
      text.removeFirst()
    }
    let beta = splitBeta(&text)
    if case .rejected = beta {
      return nil
    }
    let parts = text.split(separator: ".", omittingEmptySubsequences: false)
    if parts.count < 2 || parts.count > 4 {
      return nil
    }
    var numbers: [Int] = []
    for part in parts {
      guard let value = strictInteger(part) else {
        return nil
      }
      numbers.append(value)
    }
    let betaBuild = beta.number
    return ParetlyVersion(components: numbers, betaBuild: betaBuild, ciBuild: nil)
  }

  /// The copy that is running. Beta builds fold `CFBundleVersion` into the beta number.
  static func installed(shortVersion: String, bundleVersion: String, channel: String?) -> ParetlyVersion? {
    guard let parsed = parse(shortVersion) else {
      return nil
    }
    let build = strictInteger(bundleVersion)
    if channel == "beta" {
      let beta = parsed.betaBuild ?? build ?? 0
      return ParetlyVersion(components: parsed.components, betaBuild: beta, ciBuild: build ?? beta)
    }
    if parsed.betaBuild != nil {
      return parsed
    }
    return ParetlyVersion(components: parsed.components, betaBuild: nil, ciBuild: build)
  }

  static func < (lhs: ParetlyVersion, rhs: ParetlyVersion) -> Bool {
    let count = max(lhs.components.count, rhs.components.count)
    for index in 0..<count {
      let left = index < lhs.components.count ? lhs.components[index] : 0
      let right = index < rhs.components.count ? rhs.components[index] : 0
      if left != right {
        return left < right
      }
    }
    return lhs.sortBuild < rhs.sortBuild
  }

  var display: String {
    let core = components.map(String.init).joined(separator: ".")
    if let betaBuild {
      return "\(core)-beta.\(betaBuild)"
    }
    return core
  }

  var sortBuild: Int {
    betaBuild ?? ciBuild ?? 0
  }

  private enum BetaSplit {
    case none
    case rejected
    case beta(Int)

    var number: Int? {
      if case .beta(let value) = self {
        return value
      }
      return nil
    }
  }

  private static func splitBeta(_ text: inout String) -> BetaSplit {
    guard let range = text.range(of: "-beta.") else {
      return text.contains("-") ? .rejected : .none
    }
    let suffix = text[range.upperBound...]
    guard let value = strictInteger(suffix) else {
      return .rejected
    }
    text = String(text[..<range.lowerBound])
    return .beta(value)
  }

  private static func strictInteger<S: StringProtocol>(_ part: S) -> Int? {
    if part.isEmpty || (part.count > 1 && part.hasPrefix("0")) {
      return nil
    }
    guard part.allSatisfy(\.isNumber), let value = Int(part, radix: 10) else {
      return nil
    }
    return value
  }
}

struct ParetlyReleaseAsset: Equatable {
  var name: String
  var byteCount: Int
  var downloadURL: URL
}

struct ParetlyRelease: Equatable {
  var tag: String
  var version: ParetlyVersion
  var notes: String
  var installer: ParetlyReleaseAsset
  var checksum: ParetlyReleaseAsset?

  static let packageName = "Paretly-unsigned.pkg"
  static let checksumName = "Paretly-unsigned.pkg.sha256"
  static let releasesURL = URL(string: "https://api.github.com/repos/QiuZekun/paretly-ime/releases?per_page=20")!

  static func includesBetasByDefault(channel: String?) -> Bool {
    channel == "beta"
  }
}

enum ParetlyUpdateDecision: Equatable {
  case upToDate
  case available(ParetlyRelease)
  case noRelease
}

enum ParetlyReleaseError: Error, Equatable {
  case notAReleaseList
}

/// What a manual or automatic check should do with one GitHub response.
enum ParetlyManualResult: Equatable {
  /// A newer stable release with an installer package.
  case offer(ParetlyRelease)
  /// A stable release exists and it is not newer than this copy.
  case upToDate(version: String)
  /// No published stable release (empty list, only drafts, or HTTP 404).
  case nothingPublished(version: String)
  case failed(ParetlyReleaseFailure)
  case missingVersion
}

enum ParetlyReleaseFailure: Equatable {
  case transport(String)
  case http(status: Int, message: String)
  case unreadable
}

enum ParetlyReleaseFetch: Equatable {
  case catalog([ParetlyRelease])
  case noPublishedRelease
  case failed(ParetlyReleaseFailure)
}

enum ParetlyReleaseCatalog {
  static func releases(from data: Data, includeBetas: Bool = false) throws -> [ParetlyRelease] {
    let object = try JSONSerialization.jsonObject(with: data)
    guard let rows = object as? [[String: Any]] else {
      throw ParetlyReleaseError.notAReleaseList
    }
    return rows.compactMap { parseRelease($0, includeBetas: includeBetas) }
  }

  static func newestStable(in releases: [ParetlyRelease]) -> ParetlyRelease? {
    releases.max { $0.version < $1.version }
  }

  /// `manual` still offers a version the user previously skipped.
  static func decide(current: ParetlyVersion, newest: ParetlyRelease?, skipped: ParetlyVersion?, manual: Bool) -> ParetlyUpdateDecision {
    guard let newest else {
      return .noRelease
    }
    if newest.version <= current {
      return .upToDate
    }
    if !manual, let skipped, newest.version <= skipped {
      return .upToDate
    }
    return .available(newest)
  }

  /// 404 and GitHub's `{"message":"Not Found"}` body mean there is no published
  /// release (`/releases/latest` returns that before the first release). An
  /// empty list is a catalog the caller turns into `nothingPublished`.
  static func interpret(statusCode: Int?, data: Data?, transportError: String?, includeBetas: Bool = false) -> ParetlyReleaseFetch {
    if statusCode == 404 || githubMessage(in: data) == "Not Found" {
      return .noPublishedRelease
    }
    if let transportError {
      return .failed(.transport(transportError))
    }
    if let statusCode, !(200..<300).contains(statusCode) {
      return .failed(.http(status: statusCode, message: githubMessage(in: data)))
    }
    guard let data else {
      return .failed(.unreadable)
    }
    do {
      return .catalog(try releases(from: data, includeBetas: includeBetas))
    } catch {
      return .failed(.unreadable)
    }
  }

  static func outcome(
    fetch: ParetlyReleaseFetch,
    current: ParetlyVersion?,
    skipped: ParetlyVersion?,
    manual: Bool
  ) -> ParetlyManualResult {
    switch fetch {
    case .failed(let failure):
      return .failed(failure)
    case .noPublishedRelease:
      guard let current else {
        return .missingVersion
      }
      return .nothingPublished(version: current.display)
    case .catalog(let releases):
      guard let current else {
        return .missingVersion
      }
      switch decide(current: current, newest: newestStable(in: releases), skipped: skipped, manual: manual) {
      case .available(let release):
        return .offer(release)
      case .upToDate:
        return .upToDate(version: current.display)
      case .noRelease:
        return .nothingPublished(version: current.display)
      }
    }
  }

  static func automaticCheckIsDue(automatic: Bool, lastCheck: Date?, now: Date, interval: TimeInterval = 24 * 60 * 60) -> Bool {
    guard automatic else {
      return false
    }
    guard let lastCheck else {
      return true
    }
    return now.timeIntervalSince(lastCheck) >= interval
  }

  private static func githubMessage(in data: Data?) -> String {
    guard let data,
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let message = object["message"] as? String else {
      return ""
    }
    return message.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func parseRelease(_ row: [String: Any], includeBetas: Bool) -> ParetlyRelease? {
    if (row["draft"] as? Bool) == true {
      return nil
    }
    let prerelease = (row["prerelease"] as? Bool) == true
    guard let tag = row["tag_name"] as? String, let version = version(in: row) else {
      return nil
    }
    if prerelease {
      guard includeBetas, version.betaBuild != nil else {
        return nil
      }
    } else if version.betaBuild != nil {
      return nil
    }
    let assets = (row["assets"] as? [[String: Any]]) ?? []
    guard let installer = asset(named: ParetlyRelease.packageName, in: assets) else {
      return nil
    }
    let notes = (row["body"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return ParetlyRelease(
      tag: tag,
      version: version,
      notes: notes,
      installer: installer,
      checksum: asset(named: ParetlyRelease.checksumName, in: assets)
    )
  }

  /// Beta releases are titled `0.1.0-beta.N` and tagged `beta-N`, so the title is tried first.
  private static func version(in row: [String: Any]) -> ParetlyVersion? {
    if let name = row["name"] as? String, let version = ParetlyVersion.parse(name) {
      return version
    }
    if let tag = row["tag_name"] as? String, let version = ParetlyVersion.parse(tag) {
      return version
    }
    return nil
  }

  private static func asset(named name: String, in rows: [[String: Any]]) -> ParetlyReleaseAsset? {
    for row in rows {
      guard (row["name"] as? String) == name else {
        continue
      }
      guard let urlString = row["browser_download_url"] as? String, let url = URL(string: urlString) else {
        return nil
      }
      let size = row["size"] as? Int ?? 0
      return ParetlyReleaseAsset(name: name, byteCount: size, downloadURL: url)
    }
    return nil
  }
}

enum ParetlyChecksum {
  static func sha256Hex(of data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }

  /// Accepts a bare hex digest or a `sha256sum` line (`hex  filename`).
  static func parsePublishedDigest(_ text: String) -> String? {
    let token = text.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? ""
    let hex = token.lowercased()
    guard hex.count == 64, hex.allSatisfy({ $0.isHexDigit }) else {
      return nil
    }
    return hex
  }

  static func matches(data: Data, publishedDigest: String) -> Bool {
    guard let expected = parsePublishedDigest(publishedDigest) else {
      return false
    }
    return sha256Hex(of: data) == expected
  }
}

/// In-app update never runs the installer. The user installs the downloaded
/// package themselves.
enum ParetlyManualUpdate: Equatable {
  case revealAndOpen

  static func handoff() -> Self {
    .revealAndOpen
  }
}

private extension Character {
  var isHexDigit: Bool {
    return ("0"..."9").contains(self) || ("a"..."f").contains(self)
  }
}
