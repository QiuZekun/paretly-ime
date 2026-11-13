//
//  ParetlyReleaseTests.swift
//  Paretly
//
//  Copyright (C) 2026 Paretly contributors
//
//  This file is part of Paretly, a GPL-3.0 fork of Squirrel (鼠须管).
//  See LICENSE.txt.

import XCTest

final class ParetlyReleaseTests: XCTestCase {
  func testParsesBundleAndTagVersions() {
    XCTAssertEqual(ParetlyVersion.parse("0.1.0")?.components, [0, 1, 0])
    XCTAssertEqual(ParetlyVersion.parse("v1.2.3")?.display, "1.2.3")
    XCTAssertEqual(ParetlyVersion.parse("  v2.0  ")?.components, [2, 0])
    XCTAssertNil(ParetlyVersion.parse("v1.2.3-rc1"))
    XCTAssertNil(ParetlyVersion.parse("0.1.0-beta"))
    XCTAssertNil(ParetlyVersion.parse("0.1.0-beta.01"))
    XCTAssertEqual(ParetlyVersion.parse("0.1.0-beta.12")?.display, "0.1.0-beta.12")
    XCTAssertEqual(ParetlyVersion.parse("v0.1.0-beta.12")?.betaBuild, 12)
    XCTAssertNil(ParetlyVersion.parse("1"))
    XCTAssertNil(ParetlyVersion.parse("01.2"))
    XCTAssertNil(ParetlyVersion.parse(""))
  }

  func testComparesNumericComponents() {
    let older = ParetlyVersion.parse("0.1.0")!
    let same = ParetlyVersion.parse("v0.1.0")!
    let patch = ParetlyVersion.parse("0.1.1")!
    let minor = ParetlyVersion.parse("0.2")!
    let ten = ParetlyVersion.parse("1.10.0")!
    let nine = ParetlyVersion.parse("1.9.0")!
    XCTAssertFalse(older < same)
    XCTAssertFalse(same < older)
    XCTAssertTrue(older < patch)
    XCTAssertTrue(older < minor)
    XCTAssertTrue(nine < ten)
    XCTAssertEqual(ParetlyVersion.parse("1.2"), ParetlyVersion.parse("1.2.0"))
    let beta1 = ParetlyVersion.parse("0.1.0-beta.1")!
    let beta2 = ParetlyVersion.parse("0.1.0-beta.2")!
    let stable = ParetlyVersion.parse("0.1.0")!
    let next = ParetlyVersion.parse("0.2.0")!
    XCTAssertTrue(beta1 < beta2)
    XCTAssertTrue(stable < beta2)
    XCTAssertTrue(beta2 < next)
    XCTAssertFalse(next < beta2)
  }

  func testInstalledBuildNumberOrdersBetaAgainstStable() {
    let stableBuild = ParetlyVersion.installed(shortVersion: "0.1.0", bundleVersion: "10", channel: "stable")!
    let olderBeta = ParetlyVersion.parse("0.1.0-beta.4")!
    let newerBeta = ParetlyVersion.parse("0.1.0-beta.11")!
    let sameBeta = ParetlyVersion.installed(shortVersion: "0.1.0", bundleVersion: "11", channel: "beta")!
    XCTAssertEqual(stableBuild.display, "0.1.0")
    XCTAssertEqual(sameBeta.display, "0.1.0-beta.11")
    XCTAssertTrue(olderBeta < stableBuild)
    XCTAssertTrue(stableBuild < newerBeta)
    XCTAssertEqual(sameBeta, newerBeta)
    XCTAssertFalse(ParetlyRelease.includesBetasByDefault(channel: "stable"))
    XCTAssertFalse(ParetlyRelease.includesBetasByDefault(channel: nil))
    XCTAssertTrue(ParetlyRelease.includesBetasByDefault(channel: "beta"))
    XCTAssertNil(ParetlyVersion.installed(shortVersion: "nope", bundleVersion: "1", channel: "stable"))
  }

  func testBetaChannelOffersNewerBuildAndNotADowngrade() throws {
    let data = """
    [
      {"tag_name":"v0.1.0","name":"v0.1.0","draft":false,"prerelease":false,"body":"stable","assets":[{"name":"Paretly-unsigned.pkg","size":1,"browser_download_url":"https://example.com/stable.pkg"}]},
      {"tag_name":"beta-4","name":"0.1.0-beta.4","draft":false,"prerelease":true,"body":"old beta","assets":[{"name":"Paretly-unsigned.pkg","size":2,"browser_download_url":"https://example.com/b4.pkg"}]},
      {"tag_name":"beta-11","name":"0.1.0-beta.11","draft":false,"prerelease":true,"body":"new beta","assets":[{"name":"Paretly-unsigned.pkg","size":3,"browser_download_url":"https://example.com/b11.pkg"},{"name":"Paretly-unsigned.pkg.sha256","size":80,"browser_download_url":"https://example.com/b11.sha256"}]},
      {"tag_name":"v0.3.0-rc1","name":"v0.3.0-rc1","draft":false,"prerelease":true,"body":"rc","assets":[{"name":"Paretly-unsigned.pkg","size":4,"browser_download_url":"https://example.com/rc.pkg"}]}
    ]
    """.data(using: .utf8)!
    let stableOnly = try ParetlyReleaseCatalog.releases(from: data)
    XCTAssertEqual(stableOnly.map(\.version.display), ["0.1.0"])
    let withBetas = try ParetlyReleaseCatalog.releases(from: data, includeBetas: true)
    XCTAssertEqual(withBetas.map(\.tag), ["v0.1.0", "beta-4", "beta-11"])
    XCTAssertEqual(ParetlyReleaseCatalog.newestStable(in: withBetas)?.tag, "beta-11")
    XCTAssertEqual(withBetas[2].checksum?.name, "Paretly-unsigned.pkg.sha256")

    let onStable = ParetlyVersion.installed(shortVersion: "0.1.0", bundleVersion: "10", channel: "stable")!
    XCTAssertEqual(
      ParetlyReleaseCatalog.decide(
        current: onStable,
        newest: ParetlyReleaseCatalog.newestStable(in: withBetas),
        skipped: nil,
        manual: true
      ),
      .available(withBetas[2])
    )
    let onNewerBeta = ParetlyVersion.installed(shortVersion: "0.1.0", bundleVersion: "12", channel: "beta")!
    XCTAssertEqual(
      ParetlyReleaseCatalog.decide(
        current: onNewerBeta,
        newest: ParetlyReleaseCatalog.newestStable(in: withBetas),
        skipped: nil,
        manual: true
      ),
      .upToDate
    )
    let onOldBeta = ParetlyVersion.parse("0.1.0-beta.4")!
    XCTAssertEqual(
      ParetlyReleaseCatalog.decide(
        current: onOldBeta,
        newest: ParetlyReleaseCatalog.newestStable(in: stableOnly),
        skipped: nil,
        manual: true
      ),
      .upToDate
    )
    let laterStable = sampleRelease("0.2.0")
    XCTAssertEqual(
      ParetlyReleaseCatalog.decide(
        current: onNewerBeta,
        newest: laterStable,
        skipped: nil,
        manual: false
      ),
      .available(laterStable)
    )
  }

  func testParsesReleaseListAndSkipsUnstableOrIncomplete() throws {
    let data = """
    [
      {"tag_name":"v0.2.0","draft":true,"prerelease":false,"body":"draft","assets":[{"name":"Paretly-unsigned.pkg","size":10,"browser_download_url":"https://example.com/draft.pkg"}]},
      {"tag_name":"v0.3.0-rc1","draft":false,"prerelease":true,"body":"rc","assets":[{"name":"Paretly-unsigned.pkg","size":10,"browser_download_url":"https://example.com/rc.pkg"}]},
      {"tag_name":"v0.1.2","draft":false,"prerelease":false,"body":"dmg only","assets":[{"name":"Paretly-unsigned.dmg","size":9,"browser_download_url":"https://example.com/only.dmg"}]},
      {"tag_name":"v0.1.1","draft":false,"prerelease":false,"body":"notes","assets":[{"name":"Paretly-unsigned.pkg","size":42,"browser_download_url":"https://example.com/a.pkg"},{"name":"Paretly-unsigned.pkg.sha256","size":80,"browser_download_url":"https://example.com/a.sha256"}]},
      {"tag_name":"v0.1.0","draft":false,"prerelease":false,"body":null,"assets":[]},
      {"tag_name":"not-a-version","draft":false,"prerelease":false,"assets":[{"name":"Paretly-unsigned.pkg","size":1,"browser_download_url":"https://example.com/bad.pkg"}]}
    ]
    """.data(using: .utf8)!
    let releases = try ParetlyReleaseCatalog.releases(from: data)
    XCTAssertEqual(releases.map(\.version.display), ["0.1.1"])
    XCTAssertEqual(releases[0].notes, "notes")
    XCTAssertEqual(releases[0].installer.byteCount, 42)
    XCTAssertEqual(releases[0].installer.name, "Paretly-unsigned.pkg")
    XCTAssertEqual(releases[0].checksum?.name, "Paretly-unsigned.pkg.sha256")
    XCTAssertEqual(ParetlyReleaseCatalog.newestStable(in: releases)?.tag, "v0.1.1")
  }

  func testRejectsAGitHubErrorObject() {
    let data = #"{"message":"Not Found"}"#.data(using: .utf8)!
    XCTAssertThrowsError(try ParetlyReleaseCatalog.releases(from: data)) { error in
      XCTAssertEqual(error as? ParetlyReleaseError, .notAReleaseList)
    }
  }

  func testChoosesTheHighestStableRelease() throws {
    let data = """
    [
      {"tag_name":"v0.9.0","draft":false,"prerelease":false,"body":"","assets":[{"name":"Paretly-unsigned.pkg","size":1,"browser_download_url":"https://example.com/old.pkg"}]},
      {"tag_name":"v1.0.0","draft":false,"prerelease":false,"body":"newest","assets":[{"name":"Paretly-unsigned.pkg","size":2,"browser_download_url":"https://example.com/new.pkg"}]}
    ]
    """.data(using: .utf8)!
    let newest = ParetlyReleaseCatalog.newestStable(in: try ParetlyReleaseCatalog.releases(from: data))
    XCTAssertEqual(newest?.version.display, "1.0.0")
  }

  func testNoReleaseNewerReleaseAndSameVersion() {
    let current = ParetlyVersion.parse("0.1.0")!
    XCTAssertEqual(
      ParetlyReleaseCatalog.outcome(fetch: .catalog([]), current: current, skipped: nil, manual: true),
      .nothingPublished(version: "0.1.0")
    )
    XCTAssertEqual(
      ParetlyReleaseCatalog.outcome(fetch: .noPublishedRelease, current: current, skipped: nil, manual: true),
      .nothingPublished(version: "0.1.0")
    )
    let same = sampleRelease("0.1.0")
    XCTAssertEqual(
      ParetlyReleaseCatalog.outcome(fetch: .catalog([same]), current: current, skipped: nil, manual: true),
      .upToDate(version: "0.1.0")
    )
    let newer = sampleRelease("0.2.0")
    XCTAssertEqual(
      ParetlyReleaseCatalog.outcome(fetch: .catalog([newer]), current: current, skipped: nil, manual: true),
      .offer(newer)
    )
    let older = sampleRelease("0.0.9")
    XCTAssertEqual(
      ParetlyReleaseCatalog.outcome(fetch: .catalog([older]), current: current, skipped: nil, manual: true),
      .upToDate(version: "0.1.0")
    )
  }

  func testNotFoundIsNotAFailure() throws {
    let body = #"{"message":"Not Found","documentation_url":"https://docs.github.com"}"#.data(using: .utf8)!
    let current = ParetlyVersion.parse("0.1.0")!
    let statuses: [Int?] = [404, nil]
    for status in statuses {
      let fetch = ParetlyReleaseCatalog.interpret(statusCode: status, data: body, transportError: nil)
      XCTAssertEqual(fetch, .noPublishedRelease)
      XCTAssertEqual(
        ParetlyReleaseCatalog.outcome(fetch: fetch, current: current, skipped: nil, manual: true),
        .nothingPublished(version: "0.1.0")
      )
    }
    let empty = "[]".data(using: .utf8)!
    let listed = ParetlyReleaseCatalog.interpret(statusCode: 200, data: empty, transportError: nil)
    XCTAssertEqual(listed, .catalog([]))
    XCTAssertEqual(
      ParetlyReleaseCatalog.outcome(fetch: listed, current: current, skipped: nil, manual: true),
      .nothingPublished(version: "0.1.0")
    )
  }

  func testDraftsAndPrereleasesCountAsNothingPublished() throws {
    let data = """
    [
      {"tag_name":"v9.0.0","draft":true,"prerelease":false,"assets":[{"name":"Paretly-unsigned.pkg","size":1,"browser_download_url":"https://example.com/d.pkg"}]},
      {"tag_name":"v8.0.0","draft":false,"prerelease":true,"assets":[{"name":"Paretly-unsigned.pkg","size":1,"browser_download_url":"https://example.com/p.pkg"}]}
    ]
    """.data(using: .utf8)!
    let fetch = ParetlyReleaseCatalog.interpret(statusCode: 200, data: data, transportError: nil)
    XCTAssertEqual(
      ParetlyReleaseCatalog.outcome(
        fetch: fetch,
        current: ParetlyVersion.parse("0.1.0"),
        skipped: nil,
        manual: true
      ),
      .nothingPublished(version: "0.1.0")
    )
  }

  func testHttpAndTransportFailuresKeepTheReason() {
    let limited = #"{"message":"API rate limit exceeded"}"#.data(using: .utf8)!
    XCTAssertEqual(
      ParetlyReleaseCatalog.interpret(statusCode: 403, data: limited, transportError: nil),
      .failed(.http(status: 403, message: "API rate limit exceeded"))
    )
    XCTAssertEqual(
      ParetlyReleaseCatalog.interpret(statusCode: 500, data: Data(), transportError: nil),
      .failed(.http(status: 500, message: ""))
    )
    XCTAssertEqual(
      ParetlyReleaseCatalog.interpret(statusCode: 200, data: #"{"message":"nope"}"#.data(using: .utf8), transportError: nil),
      .failed(.unreadable)
    )
    let offline = "The Internet connection appears to be offline."
    XCTAssertEqual(
      ParetlyReleaseCatalog.interpret(statusCode: nil, data: nil, transportError: offline),
      .failed(.transport(offline))
    )
  }

  func testManualCheckStillOffersASkippedVersion() {
    let current = ParetlyVersion.parse("0.1.0")!
    let release = sampleRelease("1.2.0")
    let skipped = ParetlyVersion.parse("1.2.0")!
    XCTAssertEqual(
      ParetlyReleaseCatalog.decide(current: current, newest: release, skipped: skipped, manual: false),
      .upToDate
    )
    XCTAssertEqual(
      ParetlyReleaseCatalog.decide(current: current, newest: release, skipped: skipped, manual: true),
      .available(release)
    )
    let later = sampleRelease("1.3.0")
    XCTAssertEqual(
      ParetlyReleaseCatalog.decide(current: current, newest: later, skipped: skipped, manual: false),
      .available(later)
    )
  }

  func testAutomaticCheckWaitsADay() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    XCTAssertTrue(ParetlyReleaseCatalog.automaticCheckIsDue(automatic: true, lastCheck: nil, now: now))
    XCTAssertFalse(ParetlyReleaseCatalog.automaticCheckIsDue(automatic: false, lastCheck: nil, now: now))
    XCTAssertFalse(ParetlyReleaseCatalog.automaticCheckIsDue(automatic: true, lastCheck: now.addingTimeInterval(-3600), now: now))
    XCTAssertTrue(ParetlyReleaseCatalog.automaticCheckIsDue(automatic: true, lastCheck: now.addingTimeInterval(-24 * 60 * 60), now: now))
  }

  func testChecksumFileAndDigest() {
    XCTAssertEqual(
      ParetlyChecksum.parsePublishedDigest("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad  Paretly-unsigned.pkg\n"),
      "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    )
    XCTAssertNil(ParetlyChecksum.parsePublishedDigest("too short"))
    let data = Data("abc".utf8)
    XCTAssertEqual(ParetlyChecksum.sha256Hex(of: data), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    XCTAssertTrue(ParetlyChecksum.matches(data: data, publishedDigest: ParetlyChecksum.sha256Hex(of: data).uppercased()))
    XCTAssertFalse(ParetlyChecksum.matches(data: data, publishedDigest: String(repeating: "ab", count: 32)))
  }

  private func sampleRelease(_ version: String) -> ParetlyRelease {
    ParetlyRelease(
      tag: "v" + version,
      version: ParetlyVersion.parse(version)!,
      notes: "",
      installer: ParetlyReleaseAsset(name: ParetlyRelease.packageName, byteCount: 1, downloadURL: URL(string: "https://example.com/p.pkg")!),
      checksum: nil
    )
  }
}
