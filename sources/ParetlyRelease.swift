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

/// Numeric version from a tag such as `v0.1.0` or a bundle version `0.1.0`.
struct ParetlyVersion: Equatable, Comparable {
  let components: [Int]

  /// `1.2` and `1.2.0` are the same version.
  static func == (lhs: ParetlyVersion, rhs: ParetlyVersion) -> Bool {
    return !(lhs < rhs) && !(rhs < lhs)
  }

  static func parse(_ raw: String) -> ParetlyVersion? {
    var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if text.first == "v" || text.first == "V" {
      text.removeFirst()
    }
    let parts = text.split(separator: ".", omittingEmptySubsequences: false)
    if parts.count < 2 || parts.count > 4 {
      return nil
    }
    var numbers: [Int] = []
    for part in parts {
      if part.isEmpty || (part.count > 1 && part.hasPrefix("0")) {
        return nil
      }
      guard part.allSatisfy(\.isNumber), let value = Int(part) else {
        return nil
      }
      numbers.append(value)
    }
    return ParetlyVersion(components: numbers)
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
    return false
  }

  var display: String {
    components.map(String.init).joined(separator: ".")
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
  var diskImage: ParetlyReleaseAsset
  var checksum: ParetlyReleaseAsset?

  static let diskImageName = "Paretly-unsigned.dmg"
  static let checksumName = "Paretly-unsigned.dmg.sha256"
  static let releasesURL = URL(string: "https://api.github.com/repos/QiuZekun/paretly-ime/releases?per_page=20")!
}

enum ParetlyUpdateDecision: Equatable {
  case upToDate
  case available(ParetlyRelease)
  case noRelease
}

enum ParetlyReleaseError: Error, Equatable {
  case notAReleaseList
}

enum ParetlyReleaseCatalog {
  static func releases(from data: Data) throws -> [ParetlyRelease] {
    let object = try JSONSerialization.jsonObject(with: data)
    guard let rows = object as? [[String: Any]] else {
      throw ParetlyReleaseError.notAReleaseList
    }
    return rows.compactMap(parseRelease)
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

  static func automaticCheckIsDue(automatic: Bool, lastCheck: Date?, now: Date, interval: TimeInterval = 24 * 60 * 60) -> Bool {
    guard automatic else {
      return false
    }
    guard let lastCheck else {
      return true
    }
    return now.timeIntervalSince(lastCheck) >= interval
  }

  private static func parseRelease(_ row: [String: Any]) -> ParetlyRelease? {
    if (row["draft"] as? Bool) == true || (row["prerelease"] as? Bool) == true {
      return nil
    }
    guard let tag = row["tag_name"] as? String, let version = ParetlyVersion.parse(tag) else {
      return nil
    }
    let assets = (row["assets"] as? [[String: Any]]) ?? []
    guard let disk = asset(named: ParetlyRelease.diskImageName, in: assets) else {
      return nil
    }
    let notes = (row["body"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return ParetlyRelease(
      tag: tag,
      version: version,
      notes: notes,
      diskImage: disk,
      checksum: asset(named: ParetlyRelease.checksumName, in: assets)
    )
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

private extension Character {
  var isHexDigit: Bool {
    return ("0"..."9").contains(self) || ("a"..."f").contains(self)
  }
}
