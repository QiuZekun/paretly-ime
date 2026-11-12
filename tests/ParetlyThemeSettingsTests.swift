//
//  ParetlyThemeSettingsTests.swift
//  Paretly
//
//  Copyright (C) 2026 Paretly contributors
//
//  This file is part of Paretly, a GPL-3.0 fork of Squirrel (鼠须管).
//  See LICENSE.txt.

import XCTest

final class ParetlyThemeSettingsTests: XCTestCase {
  func testMergeBundledUserAndCustomPatch() {
    let loaded = ParetlyThemeDocument.load(bundledYAML: bundledFixture, userYAML: userFixture, customYAML: customFixture)
    XCTAssertEqual(loaded.schemes.map(\.id), ["native", "clean_white", "extra"])
    XCTAssertEqual(loaded.schemes[0].name, "系統配色")
    XCTAssertTrue(loaded.schemes[0].isNative)
    XCTAssertEqual(loaded.schemes[1].name, "简约白")
    XCTAssertEqual(loaded.schemes[1].fields["back_color"], .string("0xffffff"))
    XCTAssertEqual(loaded.schemes[1].fields["text_color"], .string("0x808080"))
    XCTAssertEqual(loaded.schemes[1].palette.back, .rgb(255, 255, 255))
    XCTAssertEqual(loaded.schemes[1].palette.text, .rgb(128, 128, 128))
    XCTAssertEqual(loaded.schemes[2].name, "Extra")
    XCTAssertEqual(loaded.schemes[2].fields["text_color"], .string("0xabcdef"))
    XCTAssertEqual(loaded.schemes[2].palette.candidateText.red, 239)
    XCTAssertEqual(loaded.schemes[2].palette.candidateText.green, 205)
    XCTAssertEqual(loaded.schemes[2].palette.candidateText.blue, 171)

    XCTAssertEqual(loaded.baseline.colorScheme, "native")
    XCTAssertEqual(loaded.baseline.colorSchemeDark, "clean_black")
    XCTAssertEqual(loaded.baseline.fontPoint, 18)
    XCTAssertEqual(loaded.baseline.cornerRadius, 7)
    XCTAssertEqual(loaded.baseline.labelFontPoint, 13)
    XCTAssertEqual(loaded.effective.colorScheme, "aqua")
    XCTAssertEqual(loaded.effective.colorSchemeDark, "clean_black")
    XCTAssertEqual(loaded.effective.cornerRadius, 12)
    XCTAssertEqual(loaded.effective.fontPoint, 18)
    XCTAssertEqual(loaded.effective.candidateListLayout, "stacked")
  }

  func testWritesOnlyChangedKeysAndKeepsOtherPatches() {
    let loaded = ParetlyThemeDocument.load(bundledYAML: bundledFixture, userYAML: userFixture, customYAML: customFixture)
    var edited = loaded.effective
    edited.fontPoint = 20
    let edits = ParetlyThemeDocument.changedPatchEdits(baseline: loaded.baseline, loaded: loaded.effective, edited: edited)
    XCTAssertEqual(edits, ["style/font_point": .set(.int(20))])
    let rendered = ParetlyThemeDocument.applyEdits(original: customFixture, edits: edits)
    XCTAssertEqual(rendered, """
    # keep me
    patch:
      style/color_scheme: aqua
      app_options/com.apple.Terminal/ascii_mode: false
      preset_color_schemes/extra/text_color: 0xabcdef
      # note
      style:
        corner_radius: 12
        font_point: 20

    keyboard_layout: last

    """)
  }

  func testRevertingToBaselineRemovesThoseKeysOnly() {
    let loaded = ParetlyThemeDocument.load(bundledYAML: bundledFixture, userYAML: userFixture, customYAML: customFixture)
    var edited = loaded.effective
    edited.colorScheme = loaded.baseline.colorScheme
    edited.cornerRadius = loaded.baseline.cornerRadius
    let edits = ParetlyThemeDocument.changedPatchEdits(baseline: loaded.baseline, loaded: loaded.effective, edited: edited)
    XCTAssertEqual(edits["style/color_scheme"], .remove)
    XCTAssertEqual(edits["style/corner_radius"], .remove)
    XCTAssertNil(edits["style/font_point"])
    let rendered = ParetlyThemeDocument.applyEdits(original: customFixture, edits: edits)
    XCTAssertEqual(rendered, """
    # keep me
    patch:
      app_options/com.apple.Terminal/ascii_mode: false
      preset_color_schemes/extra/text_color: 0xabcdef
      # note

    keyboard_layout: last

    """)
  }

  func testUnchangedApplyDoesNotRewriteFile() {
    let loaded = ParetlyThemeDocument.load(bundledYAML: bundledFixture, userYAML: userFixture, customYAML: customFixture)
    let edits = ParetlyThemeDocument.changedPatchEdits(baseline: loaded.baseline, loaded: loaded.effective, edited: loaded.effective)
    XCTAssertTrue(edits.isEmpty)
    XCTAssertNil(ParetlyThemeDocument.applyEdits(original: customFixture, edits: edits))
  }

  func testCommentOnUpdatedLineIsKept() {
    let original = "patch:\n  style/font_point: 16 # keep\n"
    let rendered = ParetlyThemeDocument.applyEdits(original: original, edits: ["style/font_point": .set(.int(18))])
    XCTAssertEqual(rendered, "patch:\n  style/font_point: 18 # keep\n")
  }

  func testNewFileContainsOnlySetKeys() {
    let rendered = ParetlyThemeDocument.applyEdits(original: nil, edits: [
      "style/color_scheme": .set(.string("clean_white")),
      "style/font_point": .set(.int(18))
    ])
    XCTAssertEqual(rendered, """
    # Paretly settings
    # encoding: utf-8

    patch:
      style/color_scheme: clean_white
      style/font_point: 18

    """)
  }

  func testBackupIsCreatedOnce() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("paretly-theme-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let custom = directory.appendingPathComponent(ParetlyThemeDocument.customFileName)
    let original = "patch:\n  style/font_point: 18\n  app_options/keep: true\n"
    try original.write(to: custom, atomically: true, encoding: .utf8)

    XCTAssertTrue(try ParetlyThemeDocument.writeCustomFile(edits: ["style/corner_radius": .set(.int(9))], userDirectory: directory))
    let backup = directory.appendingPathComponent(ParetlyThemeDocument.customBackupFileName)
    XCTAssertEqual(try String(contentsOf: backup, encoding: .utf8), original)

    XCTAssertTrue(try ParetlyThemeDocument.writeCustomFile(edits: ["style/corner_radius": .set(.int(11))], userDirectory: directory))
    XCTAssertEqual(try String(contentsOf: backup, encoding: .utf8), original)
    let body = try String(contentsOf: custom, encoding: .utf8)
    XCTAssertTrue(body.contains("style/corner_radius: 11"))
    XCTAssertFalse(body.contains("style/corner_radius: 9"))
    XCTAssertTrue(body.contains("style/font_point: 18"))
    XCTAssertTrue(body.contains("app_options/keep: true"))
    XCTAssertFalse(try ParetlyThemeDocument.writeCustomFile(edits: [:], userDirectory: directory))
  }

  func testCreatesCustomFileWithoutBackupWhenNoneExists() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("paretly-theme-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let edits: [String: PatchEdit] = ["style/color_scheme_dark": .set(.string("clean_black"))]
    XCTAssertTrue(try ParetlyThemeDocument.writeCustomFile(edits: edits, userDirectory: directory))
    let backup = directory.appendingPathComponent(ParetlyThemeDocument.customBackupFileName)
    XCTAssertFalse(FileManager.default.fileExists(atPath: backup.path))
    let body = try String(contentsOf: directory.appendingPathComponent(ParetlyThemeDocument.customFileName), encoding: .utf8)
    XCTAssertTrue(body.contains("style/color_scheme_dark: clean_black"))
    XCTAssertFalse(body.contains("style/color_scheme:"))
  }

  func testColorChannelsAndQuotedScalars() {
    let bgr = ParetlyThemeDocument.parseColor(.string("0x112233"), format: nil)
    XCTAssertEqual(bgr, .rgb(0x33, 0x22, 0x11))
    let abgr = ParetlyThemeDocument.parseColor(.string("0x80112233"), format: nil)
    XCTAssertEqual(abgr?.red, 0x33)
    XCTAssertEqual(abgr?.green, 0x22)
    XCTAssertEqual(abgr?.blue, 0x11)
    XCTAssertEqual(abgr?.alpha ?? -1, 128.0 / 255.0, accuracy: 0.0001)
    let rgba = ParetlyThemeDocument.parseColor(.string("0x010203"), format: "rgba")
    XCTAssertEqual(rgba, .rgb(1, 2, 3))
    XCTAssertNil(ParetlyThemeDocument.parseColor(.string("blue"), format: nil))

    let parsed = ParetlyThemeDocument.load(bundledYAML: """
    preset_color_schemes:
      dust:
        name: 浮尘／Dust
        candidate_format: \"%c\\u2005%@\"
    style:
      font_point: 18.0
      corner_radius: 7  # window
    """)
    XCTAssertEqual(parsed.schemes.first?.name, "浮尘")
    XCTAssertEqual(parsed.schemes.first?.fields["candidate_format"], .string("%c\u{2005}%@"))
    XCTAssertEqual(parsed.effective.fontPoint, 18)
    XCTAssertEqual(parsed.effective.cornerRadius, 7)
  }

  func testValidationRanges() {
    var settings = ThemeSettings.fallback
    XCTAssertNil(ParetlyThemeDocument.validate(settings, knownSchemeIDs: ["native", "clean_black"]))
    settings.colorScheme = "missing"
    XCTAssertEqual(ParetlyThemeDocument.validate(settings, knownSchemeIDs: ["native"]), "Unknown light color scheme.")
    settings = ThemeSettings.fallback
    settings.candidateListLayout = "horizontal"
    XCTAssertEqual(ParetlyThemeDocument.validate(settings, knownSchemeIDs: []), "Layout must be horizontal or vertical.")
    settings = ThemeSettings.fallback
    settings.fontPoint = 11
    XCTAssertEqual(ParetlyThemeDocument.validate(settings, knownSchemeIDs: []), "Candidate size must be between 12 and 28.")
    settings.fontPoint = 12
    settings.labelFontPoint = 9
    XCTAssertEqual(ParetlyThemeDocument.validate(settings, knownSchemeIDs: []), "Label size must be between 10 and 24.")
    settings.labelFontPoint = 10
    settings.cornerRadius = 21
    XCTAssertEqual(ParetlyThemeDocument.validate(settings, knownSchemeIDs: []), "Corner radius must be between 0 and 20.")
    XCTAssertNil(ParetlyThemeDocument.validate(ThemeSettings.fallback, knownSchemeIDs: []))
  }

  func testShippedCleanBlackIsDarkCounterpart() throws {
    let url = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("data/paretly.yaml")
    let text = try String(contentsOf: url, encoding: .utf8)
    let loaded = ParetlyThemeDocument.load(bundledYAML: text)
    XCTAssertEqual(loaded.effective.colorScheme, "native")
    XCTAssertEqual(loaded.effective.colorSchemeDark, "clean_black")
    let white = try XCTUnwrap(loaded.schemes.first { $0.id == "clean_white" })
    let black = try XCTUnwrap(loaded.schemes.first { $0.id == "clean_black" })
    XCTAssertEqual(black.name, "简约黑")
    XCTAssertEqual(black.fields["name"], .string("简约黑／Clean Black"))
    XCTAssertFalse(black.isNative)
    let shared = [
      "candidate_list_layout",
      "candidate_format",
      "corner_radius",
      "border_height",
      "border_width",
      "font_point",
      "label_font_point"
    ]
    for key in shared {
      XCTAssertEqual(black.fields[key], white.fields[key], key)
    }
    XCTAssertEqual(black.fields["candidate_list_layout"], .string("linear"))
    XCTAssertEqual(black.fields["candidate_format"], .string("%c %@"))
    XCTAssertGreaterThan(black.palette.hilitedCandidateText.blue, black.palette.hilitedCandidateText.red)
    XCTAssertGreaterThanOrEqual(contrast(black.palette.candidateText, on: black.palette.back), 7)
    XCTAssertGreaterThanOrEqual(contrast(black.palette.text, on: black.palette.back), 4.5)
    XCTAssertGreaterThanOrEqual(contrast(black.palette.label, on: black.palette.back), 4.5)
    XCTAssertGreaterThanOrEqual(contrast(black.palette.comment, on: black.palette.back), 4.5)
    XCTAssertGreaterThanOrEqual(contrast(black.palette.hilitedCandidateText, on: black.palette.back), 4.5)
    XCTAssertGreaterThanOrEqual(contrast(black.palette.hilitedCandidateLabel, on: black.palette.back), 4.5)
    XCTAssertGreaterThanOrEqual(contrast(black.palette.hilitedText, on: black.palette.back), 4.5)
  }
}

private let bundledFixture = """
style:
  color_scheme: native
  color_scheme_dark: clean_black
  candidate_list_layout: stacked
  font_point: 16
  corner_radius: 7

preset_color_schemes:
  native:
    name: 系統配色
  clean_white:
    name: 简约白／Clean White
    back_color: 0xeeeeee
    text_color: 0x808080
    candidate_text_color: 0x000000
"""

private let userFixture = """
style:
  font_point: 18

preset_color_schemes:
  clean_white:
    back_color: 0xffffff
  extra:
    name: Extra／Mine
    back_color: 0x112233
"""

private let customFixture = """
# keep me
patch:
  style/color_scheme: aqua
  app_options/com.apple.Terminal/ascii_mode: false
  preset_color_schemes/extra/text_color: 0xabcdef
  # note
  style:
    corner_radius: 12

keyboard_layout: last
"""

private func contrast(_ foreground: ThemeRGBA, on background: ThemeRGBA) -> Double {
  func channel(_ value: Int) -> Double {
    let unit = Double(value) / 255
    if unit <= 0.04045 { return unit / 12.92 }
    return pow((unit + 0.055) / 1.055, 2.4)
  }
  func luminance(_ color: ThemeRGBA) -> Double {
    (0.2126 * channel(color.red)) + (0.7152 * channel(color.green)) + (0.0722 * channel(color.blue))
  }
  let painted: ThemeRGBA
  if foreground.isClear || foreground.alpha <= 0 {
    painted = background
  } else if foreground.alpha >= 0.999 {
    painted = foreground
  } else {
    let alpha = foreground.alpha
    painted = ThemeRGBA(
      red: Int((Double(foreground.red) * alpha + Double(background.red) * (1 - alpha)).rounded()),
      green: Int((Double(foreground.green) * alpha + Double(background.green) * (1 - alpha)).rounded()),
      blue: Int((Double(foreground.blue) * alpha + Double(background.blue) * (1 - alpha)).rounded()),
      alpha: 1,
      isClear: false
    )
  }
  let lighter = max(luminance(painted), luminance(background))
  let darker = min(luminance(painted), luminance(background))
  return (lighter + 0.05) / (darker + 0.05)
}
