//
//  ParetlyThemeDocument.swift
//  Paretly
//
//  Copyright (C) 2026 Paretly contributors
//
//  This file is part of Paretly, a GPL-3.0 fork of Squirrel (鼠须管).
//  See LICENSE.txt. Upstream copyright notices in this repository stay put.
//
//  Reads the effective frontend theme (bundled paretly.yaml, overlaid by
//  ~/Library/Rime/paretly.yaml and paretly.custom.yaml) and writes only the
//  style keys the user changed back into paretly.custom.yaml. Rime's config
//  id for this app is "paretly", so the patch file is paretly.custom.yaml
//  rather than the upstream squirrel.custom.yaml name.

import Foundation

enum YamlScalar: Equatable {
  case string(String)
  case int(Int)
  case double(Double)
  case bool(Bool)
  case null
}

struct ThemeRGBA: Equatable {
  var red: Int
  var green: Int
  var blue: Int
  var alpha: Double
  var isClear: Bool

  static let clear = ThemeRGBA(red: 0, green: 0, blue: 0, alpha: 0, isClear: true)

  static func rgb(_ red: Int, _ green: Int, _ blue: Int, alpha: Double = 1) -> ThemeRGBA {
    ThemeRGBA(red: red, green: green, blue: blue, alpha: alpha, isClear: alpha <= 0)
  }
}

struct ThemePalette: Equatable {
  var back: ThemeRGBA
  var border: ThemeRGBA
  var text: ThemeRGBA
  var preeditBack: ThemeRGBA
  var candidateBack: ThemeRGBA
  var candidateText: ThemeRGBA
  var label: ThemeRGBA
  var comment: ThemeRGBA
  var hilitedText: ThemeRGBA
  var hilitedBack: ThemeRGBA
  var hilitedCandidateText: ThemeRGBA
  var hilitedCandidateBack: ThemeRGBA
  var hilitedCandidateLabel: ThemeRGBA
  var hilitedComment: ThemeRGBA

  static let nativeLight = ThemePalette(
    back: .rgb(255, 255, 255),
    border: .rgb(200, 200, 205),
    text: .rgb(60, 60, 67),
    preeditBack: .clear,
    candidateBack: .clear,
    candidateText: .rgb(29, 29, 31),
    label: .rgb(142, 142, 147),
    comment: .rgb(142, 142, 147),
    hilitedText: .rgb(29, 29, 31),
    hilitedBack: .clear,
    hilitedCandidateText: .rgb(255, 255, 255),
    hilitedCandidateBack: .rgb(0, 122, 255),
    hilitedCandidateLabel: .rgb(255, 255, 255),
    hilitedComment: .rgb(220, 230, 255)
  )

  static let nativeDark = ThemePalette(
    back: .rgb(44, 44, 46),
    border: .rgb(58, 58, 60),
    text: .rgb(174, 174, 178),
    preeditBack: .clear,
    candidateBack: .clear,
    candidateText: .rgb(245, 245, 247),
    label: .rgb(142, 142, 147),
    comment: .rgb(142, 142, 147),
    hilitedText: .rgb(245, 245, 247),
    hilitedBack: .clear,
    hilitedCandidateText: .rgb(255, 255, 255),
    hilitedCandidateBack: .rgb(10, 132, 255),
    hilitedCandidateLabel: .rgb(255, 255, 255),
    hilitedComment: .rgb(200, 220, 255)
  )
}

struct ThemeScheme: Equatable, Identifiable {
  var id: String
  var name: String
  var author: String
  var isNative: Bool
  var fields: [String: YamlScalar]
  var palette: ThemePalette
  var lightPalette: ThemePalette?
  var darkPalette: ThemePalette?

  func palette(previewDark: Bool) -> ThemePalette {
    if isNative {
      return previewDark ? (darkPalette ?? .nativeDark) : (lightPalette ?? .nativeLight)
    }
    return palette
  }
}

enum ThemeSettingKey: String, CaseIterable, Equatable {
  case colorScheme = "style/color_scheme"
  case colorSchemeDark = "style/color_scheme_dark"
  case candidateListLayout = "style/candidate_list_layout"
  case fontPoint = "style/font_point"
  case labelFontPoint = "style/label_font_point"
  case cornerRadius = "style/corner_radius"
}

struct ThemeSettings: Equatable {
  var colorScheme: String
  var colorSchemeDark: String
  var candidateListLayout: String
  var fontPoint: Int
  var labelFontPoint: Int
  var cornerRadius: Int

  static let fallback = ThemeSettings(
    colorScheme: "native",
    colorSchemeDark: "clean_black",
    candidateListLayout: "stacked",
    fontPoint: 16,
    labelFontPoint: 13,
    cornerRadius: 7
  )

  func scalar(for key: ThemeSettingKey) -> YamlScalar {
    switch key {
    case .colorScheme: return .string(colorScheme)
    case .colorSchemeDark: return .string(colorSchemeDark)
    case .candidateListLayout: return .string(candidateListLayout)
    case .fontPoint: return .int(fontPoint)
    case .labelFontPoint: return .int(labelFontPoint)
    case .cornerRadius: return .int(cornerRadius)
    }
  }

  mutating func apply(_ key: ThemeSettingKey, value: YamlScalar) {
    switch key {
    case .colorScheme:
      if let text = Self.string(value), !text.isEmpty { colorScheme = text }
    case .colorSchemeDark:
      if let text = Self.string(value), !text.isEmpty { colorSchemeDark = text }
    case .candidateListLayout:
      if let text = Self.string(value), text == "linear" || text == "stacked" {
        candidateListLayout = text
      }
    case .fontPoint:
      if let number = Self.integer(value) { fontPoint = number }
    case .labelFontPoint:
      if let number = Self.integer(value) { labelFontPoint = number }
    case .cornerRadius:
      if let number = Self.integer(value) { cornerRadius = number }
    }
  }

  private static func string(_ value: YamlScalar) -> String? {
    if case .string(let text) = value { return text }
    return nil
  }

  private static func integer(_ value: YamlScalar) -> Int? {
    switch value {
    case .int(let number):
      return number
    case .double(let number):
      guard number.isFinite else { return nil }
      return Int(number.rounded())
    case .string(let text):
      return Int(text)
    default:
      return nil
    }
  }
}

enum PatchEdit: Equatable {
  case set(YamlScalar)
  case remove
}

struct ThemeLoadResult: Equatable {
  var schemes: [ThemeScheme]
  var baseline: ThemeSettings
  var effective: ThemeSettings
}

struct RawScheme: Equatable {
  var id: String
  var fields: [String: YamlScalar]
}

enum ParetlyThemeDocument {
  static let managedKeys = ThemeSettingKey.allCases.map(\.rawValue)
  static let configFileName = "paretly.yaml"
  static let customFileName = "paretly.custom.yaml"
  static let customBackupFileName = "paretly.custom.yaml.bak"

  static let colorKeys: Set<String> = [
    "back_color",
    "candidate_text_color",
    "hilited_candidate_back_color",
    "hilited_candidate_text_color",
    "text_color",
    "hilited_text_color",
    "hilited_back_color",
    "border_color",
    "label_color",
    "comment_text_color",
    "hilited_candidate_label_color",
    "hilited_comment_text_color",
    "preedit_back_color",
    "candidate_back_color"
  ]

  static func load(bundledYAML: String, userYAML: String? = nil, customYAML: String? = nil) -> ThemeLoadResult {
    var merged = mergeSchemes(base: parseSchemes(bundledYAML), overlay: userYAML.map(parseSchemes) ?? [])
    let patch = indexPatch(customYAML ?? "")
    applySchemePatches(patch.entries, to: &merged)

    var baseline = ThemeSettings.fallback
    applyStyle(parseStyle(bundledYAML), to: &baseline)
    if let userYAML {
      applyStyle(parseStyle(userYAML), to: &baseline)
    }
    var effective = baseline
    for entry in patch.entries {
      guard let key = ThemeSettingKey(rawValue: entry.path) else { continue }
      effective.apply(key, value: entry.value)
    }
    return ThemeLoadResult(schemes: merged.map(makeScheme), baseline: baseline, effective: effective)
  }

  /// Keys whose edited value differs from the value loaded into the window.
  /// A key that returns to the pre-patch baseline is removed; other patches are not listed.
  static func changedPatchEdits(baseline: ThemeSettings, loaded: ThemeSettings, edited: ThemeSettings) -> [String: PatchEdit] {
    var edits: [String: PatchEdit] = [:]
    for key in ThemeSettingKey.allCases {
      let editedValue = edited.scalar(for: key)
      if loaded.scalar(for: key) == editedValue { continue }
      if editedValue == baseline.scalar(for: key) {
        edits[key.rawValue] = .remove
      } else {
        edits[key.rawValue] = .set(editedValue)
      }
    }
    return edits
  }

  static func validate(_ settings: ThemeSettings, knownSchemeIDs: Set<String>) -> String? {
    if !knownSchemeIDs.isEmpty && !knownSchemeIDs.contains(settings.colorScheme) {
      return "Unknown light color scheme."
    }
    if !knownSchemeIDs.isEmpty && !knownSchemeIDs.contains(settings.colorSchemeDark) {
      return "Unknown dark color scheme."
    }
    if settings.candidateListLayout != "linear" && settings.candidateListLayout != "stacked" {
      return "Layout must be horizontal or vertical."
    }
    if !(12...28).contains(settings.fontPoint) {
      return "Candidate size must be between 12 and 28."
    }
    if !(10...24).contains(settings.labelFontPoint) {
      return "Label size must be between 10 and 24."
    }
    if !(0...20).contains(settings.cornerRadius) {
      return "Corner radius must be between 0 and 20."
    }
    return nil
  }

  /// Rewritten custom-file text, or nil when there is nothing to change.
  static func applyEdits(original: String?, edits: [String: PatchEdit]) -> String? {
    if edits.isEmpty { return nil }
    let hasSet = edits.values.contains { edit in
      if case .set = edit { return true }
      return false
    }
    let index = indexPatch(original ?? "")
    if index.patchHeader == nil {
      return hasSet ? renderNewFile(edits: edits) : nil
    }

    var deleted = Set<Int>()
    var replacements: [Int: String] = [:]
    var insertions: [Int: [String]] = [:]
    for key in orderedEditKeys(edits) {
      guard let edit = edits[key] else { continue }
      let matches = index.entries.filter { $0.path == key }
      switch edit {
      case .remove:
        for match in matches {
          deleted.insert(match.lineIndex)
        }
      case .set(let value):
        if matches.isEmpty {
          let insert = insertionLine(for: key, value: value, index: index)
          insertions[insert.anchor, default: []].append(insert.text)
        } else {
          for match in matches {
            replacements[match.lineIndex] = replacingValue(index.lines[match.lineIndex], with: value)
          }
        }
      }
    }
    deleteEmptyMaps(index, deleted: &deleted, insertions: insertions)
    if deleted.isEmpty && replacements.isEmpty && insertions.isEmpty {
      return nil
    }

    var output: [String] = []
    for lineIndex in index.lines.indices {
      if !deleted.contains(lineIndex) {
        output.append(replacements[lineIndex] ?? index.lines[lineIndex])
      }
      if let extra = insertions[lineIndex] {
        output.append(contentsOf: extra)
      }
    }
    let rendered = YamlText.joined(output)
    if let original, YamlText.normalize(original) == rendered {
      return nil
    }
    return rendered
  }

  /// Writes `paretly.custom.yaml`. Copies the previous file to `.bak` only if that backup does not exist yet.
  static func writeCustomFile(edits: [String: PatchEdit], userDirectory: URL, fileManager: FileManager = .default) throws -> Bool {
    let url = userDirectory.appendingPathComponent(customFileName)
    let original = readOptional(url, fileManager: fileManager)
    guard let rendered = applyEdits(original: original, edits: edits) else { return false }
    try fileManager.createDirectory(at: userDirectory, withIntermediateDirectories: true)
    if fileManager.fileExists(atPath: url.path) {
      let backup = userDirectory.appendingPathComponent(customBackupFileName)
      if !fileManager.fileExists(atPath: backup.path) {
        try fileManager.copyItem(at: url, to: backup)
      }
    }
    try rendered.write(to: url, atomically: true, encoding: .utf8)
    return true
  }
}

extension ParetlyThemeDocument {
  static func parseSchemes(_ text: String) -> [RawScheme] {
    let body = YamlText.contentLines(afterHeader: "preset_color_schemes", in: YamlText.normalizedLines(text))
    var schemes: [RawScheme] = []
    var current: Int?
    for line in body {
      if line.indent <= 2 {
        if let split = YamlText.splitKeyValue(line.content), opensMap(split.rest) {
          schemes.append(RawScheme(id: split.key, fields: [:]))
          current = schemes.count - 1
        } else {
          current = nil
        }
        continue
      }
      guard let current, let split = YamlText.splitKeyValue(line.content), let value = parseScalar(split.rest) else { continue }
      schemes[current].fields[split.key] = value
    }
    return schemes
  }

  static func parseStyle(_ text: String) -> [String: YamlScalar] {
    var fields: [String: YamlScalar] = [:]
    let body = YamlText.contentLines(afterHeader: "style", in: YamlText.normalizedLines(text))
    for line in body {
      guard let split = YamlText.splitKeyValue(line.content), let value = parseScalar(split.rest) else { continue }
      fields[split.key] = value
    }
    return fields
  }

  static func parseColor(_ value: YamlScalar, format: String?) -> ThemeRGBA? {
    guard case .string(let raw) = value else { return nil }
    var hex = raw.trimmingCharacters(in: .whitespaces).lowercased()
    if hex.hasPrefix("0x") { hex.removeFirst(2) }
    hex.removeAll { $0 == "_" }
    guard hex.count == 6 || hex.count == 8, hex.allSatisfy(\.isHexDigit), let number = Int(hex, radix: 16) else {
      return nil
    }
    var formatName = (format ?? "abgr").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if formatName == "default" || formatName == "bgr" || formatName.isEmpty {
      formatName = "abgr"
    }
    if hex.count == 6 {
      let first = (number >> 16) & 0xFF
      let second = (number >> 8) & 0xFF
      let third = number & 0xFF
      if formatName == "rgba" || formatName == "argb" {
        return .rgb(first, second, third)
      }
      return .rgb(third, second, first)
    }
    let first = (number >> 24) & 0xFF
    let second = (number >> 16) & 0xFF
    let third = (number >> 8) & 0xFF
    let fourth = number & 0xFF
    let alpha: Int
    let red: Int
    let green: Int
    let blue: Int
    switch formatName {
    case "rgba":
      red = first
      green = second
      blue = third
      alpha = fourth
    case "argb":
      alpha = first
      red = second
      green = third
      blue = fourth
    case "bgra":
      blue = first
      green = second
      red = third
      alpha = fourth
    default:
      alpha = first
      blue = second
      green = third
      red = fourth
    }
    return ThemeRGBA(red: red, green: green, blue: blue, alpha: Double(alpha) / 255, isClear: false)
  }

  static func displayName(_ name: String?, schemeID: String) -> String {
    guard let name else { return schemeID }
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return schemeID }
    for separator in ["／", "/"] {
      if let range = trimmed.range(of: separator) {
        let left = trimmed[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
        if !left.isEmpty { return String(left) }
      }
    }
    return trimmed
  }
}

private extension ParetlyThemeDocument {
  struct PatchEntry {
    var path: String
    var lineIndex: Int
    var value: YamlScalar
  }

  struct PatchMap {
    var path: String
    var lineIndex: Int
    var leading: String
  }

  struct PatchIndex {
    var lines: [String]
    var patchHeader: Int?
    var entries: [PatchEntry]
    var maps: [PatchMap]
  }

  static func mergeSchemes(base: [RawScheme], overlay: [RawScheme]) -> [RawScheme] {
    var order: [String] = []
    var fieldsByID: [String: [String: YamlScalar]] = [:]
    for scheme in base {
      if fieldsByID[scheme.id] == nil { order.append(scheme.id) }
      fieldsByID[scheme.id] = scheme.fields
    }
    for scheme in overlay {
      if var existing = fieldsByID[scheme.id] {
        for (key, value) in scheme.fields {
          existing[key] = value
        }
        fieldsByID[scheme.id] = existing
      } else {
        fieldsByID[scheme.id] = scheme.fields
        order.append(scheme.id)
      }
    }
    return order.compactMap { schemeID in
      fieldsByID[schemeID].map { RawScheme(id: schemeID, fields: $0) }
    }
  }

  static func applySchemePatches(_ entries: [PatchEntry], to schemes: inout [RawScheme]) {
    for entry in entries {
      let parts = entry.path.split(separator: "/").map(String.init)
      guard parts.count >= 3, parts[0] == "preset_color_schemes" else { continue }
      let schemeID = parts[1]
      guard !schemeID.isEmpty, schemeID != "+" else { continue }
      let field = parts.dropFirst(2).joined(separator: "/")
      if let schemeIndex = schemes.firstIndex(where: { $0.id == schemeID }) {
        schemes[schemeIndex].fields[field] = entry.value
      } else {
        schemes.append(RawScheme(id: schemeID, fields: [field: entry.value]))
      }
    }
  }

  static func applyStyle(_ fields: [String: YamlScalar], to settings: inout ThemeSettings) {
    let pairs: [(String, ThemeSettingKey)] = [
      ("color_scheme", .colorScheme),
      ("color_scheme_dark", .colorSchemeDark),
      ("candidate_list_layout", .candidateListLayout),
      ("font_point", .fontPoint),
      ("label_font_point", .labelFontPoint),
      ("corner_radius", .cornerRadius)
    ]
    for (name, key) in pairs {
      if let value = fields[name] {
        settings.apply(key, value: value)
      }
    }
  }

  static func makeScheme(_ raw: RawScheme) -> ThemeScheme {
    let name = stringField(raw.fields["name"])
    let author = stringField(raw.fields["author"]) ?? ""
    let native = raw.id == "native" && colorKeys.allSatisfy { raw.fields[$0] == nil }
    return ThemeScheme(
      id: raw.id,
      name: displayName(name, schemeID: raw.id),
      author: author,
      isNative: native,
      fields: raw.fields,
      palette: resolvePalette(raw.fields),
      lightPalette: native ? .nativeLight : nil,
      darkPalette: native ? .nativeDark : nil
    )
  }

  static func resolvePalette(_ fields: [String: YamlScalar]) -> ThemePalette {
    let format = stringField(fields["color_format"])
    var converted: [String: ThemeRGBA] = [:]
    for key in colorKeys {
      if let value = fields[key], let color = parseColor(value, format: format) {
        converted[key] = color
      }
    }
    let back = firstColor(converted, ["back_color"]) ?? .rgb(255, 255, 255)
    let text = firstColor(converted, ["text_color", "candidate_text_color"]) ?? .rgb(0, 0, 0)
    let candidate = firstColor(converted, ["candidate_text_color", "text_color"]) ?? .rgb(0, 0, 0)
    let label = firstColor(converted, ["label_color", "comment_text_color"]) ?? .rgb(128, 128, 128)
    let comment = firstColor(converted, ["comment_text_color", "label_color"]) ?? .rgb(128, 128, 128)
    let hilitedText = firstColor(converted, ["hilited_text_color", "text_color"]) ?? text
    let hilitedBack = firstColor(converted, ["hilited_back_color", "preedit_back_color"]) ?? .clear
    let hilitedCandidateText = firstColor(converted, ["hilited_candidate_text_color", "hilited_text_color"]) ?? .rgb(255, 255, 255)
    let hilitedCandidateBack = firstColor(converted, ["hilited_candidate_back_color", "hilited_back_color"]) ?? .rgb(0, 122, 255)
    let hilitedCandidateLabel = firstColor(converted, ["hilited_candidate_label_color", "hilited_candidate_text_color"]) ?? hilitedCandidateText
    let hilitedComment = firstColor(converted, ["hilited_comment_text_color", "comment_text_color"]) ?? comment
    let border = firstColor(converted, ["border_color"]) ?? back
    let preeditBack = firstColor(converted, ["preedit_back_color", "hilited_back_color"]) ?? .clear
    let candidateBack = firstColor(converted, ["candidate_back_color"]) ?? .clear
    return ThemePalette(
      back: back,
      border: border,
      text: text,
      preeditBack: preeditBack,
      candidateBack: candidateBack,
      candidateText: candidate,
      label: label,
      comment: comment,
      hilitedText: hilitedText,
      hilitedBack: hilitedBack,
      hilitedCandidateText: hilitedCandidateText,
      hilitedCandidateBack: hilitedCandidateBack,
      hilitedCandidateLabel: hilitedCandidateLabel,
      hilitedComment: hilitedComment
    )
  }

  static func firstColor(_ colors: [String: ThemeRGBA], _ keys: [String]) -> ThemeRGBA? {
    for key in keys {
      if let color = colors[key] { return color }
    }
    return nil
  }

  static func stringField(_ value: YamlScalar?) -> String? {
    if case .string(let text) = value { return text }
    return nil
  }

  static func indexPatch(_ text: String) -> PatchIndex {
    let lines = YamlText.normalizedLines(text)
    guard let header = lines.firstIndex(where: { YamlText.isSectionHeader($0, name: "patch") }) else {
      return PatchIndex(lines: lines, patchHeader: nil, entries: [], maps: [])
    }
    var entries: [PatchEntry] = []
    var maps: [PatchMap] = []
    var stack: [(indent: Int, path: String)] = []
    var index = header + 1
    while index < lines.count {
      let line = lines[index]
      if YamlText.isBlank(line) || YamlText.isCommentLine(line) {
        index += 1
        continue
      }
      let indent = YamlText.indentWidth(line)
      if indent == 0 { break }
      let leading = YamlText.leadingWhitespace(line)
      let content = String(line.dropFirst(leading.count))
      while let top = stack.last, top.indent >= indent {
        stack.removeLast()
      }
      guard let split = YamlText.splitKeyValue(content) else {
        index += 1
        continue
      }
      let parent = stack.last?.path ?? ""
      let path = parent.isEmpty ? split.key : parent + "/" + split.key
      if opensMap(split.rest) {
        maps.append(PatchMap(path: path, lineIndex: index, leading: leading))
        stack.append((indent, path))
      } else if let value = parseScalar(split.rest) {
        entries.append(PatchEntry(path: path, lineIndex: index, value: value))
      }
      index += 1
    }
    return PatchIndex(lines: lines, patchHeader: header, entries: entries, maps: maps)
  }

  static func opensMap(_ rest: String) -> Bool {
    let trimmed = rest.trimmingCharacters(in: .whitespaces)
    return trimmed.isEmpty || trimmed.hasPrefix("#")
  }

  static func orderedEditKeys(_ edits: [String: PatchEdit]) -> [String] {
    edits.keys.sorted { lhs, rhs in
      let left = managedKeys.firstIndex(of: lhs) ?? Int.max
      let right = managedKeys.firstIndex(of: rhs) ?? Int.max
      if left != right { return left < right }
      return lhs < rhs
    }
  }
}

private extension ParetlyThemeDocument {
  static func insertionLine(for key: String, value: YamlScalar, index: PatchIndex) -> (anchor: Int, text: String) {
    let parts = key.split(separator: "/").map(String.init)
    if parts.count >= 2 {
      let parent = parts.dropLast().joined(separator: "/")
      let child = parts[parts.count - 1]
      if let map = index.maps.last(where: { $0.path == parent }) {
        let anchor = lastDescendantLine(mapLine: map.lineIndex, index: index)
        return (anchor, map.leading + "  " + child + ": " + dump(value))
      }
    }
    return (lastPatchContentLine(index), topLevelPatchIndent(index) + key + ": " + dump(value))
  }

  static func lastDescendantLine(mapLine: Int, index: PatchIndex) -> Int {
    let mapIndent = YamlText.indentWidth(index.lines[mapLine])
    var last = mapLine
    var cursor = mapLine + 1
    while cursor < index.lines.count {
      let line = index.lines[cursor]
      if YamlText.isBlank(line) || YamlText.isCommentLine(line) {
        cursor += 1
        continue
      }
      if YamlText.indentWidth(line) <= mapIndent { break }
      last = cursor
      cursor += 1
    }
    return last
  }

  static func lastPatchContentLine(_ index: PatchIndex) -> Int {
    guard let header = index.patchHeader else { return max(index.lines.count - 1, 0) }
    var last = header
    var cursor = header + 1
    while cursor < index.lines.count {
      let line = index.lines[cursor]
      if YamlText.isBlank(line) || YamlText.isCommentLine(line) {
        cursor += 1
        continue
      }
      if YamlText.indentWidth(line) == 0 { break }
      last = cursor
      cursor += 1
    }
    return last
  }

  static func topLevelPatchIndent(_ index: PatchIndex) -> String {
    guard let header = index.patchHeader else { return "  " }
    var cursor = header + 1
    while cursor < index.lines.count {
      let line = index.lines[cursor]
      if YamlText.isBlank(line) || YamlText.isCommentLine(line) {
        cursor += 1
        continue
      }
      if YamlText.indentWidth(line) == 0 { break }
      let leading = YamlText.leadingWhitespace(line)
      return leading.isEmpty ? "  " : leading
    }
    return "  "
  }

  static func deleteEmptyMaps(_ index: PatchIndex, deleted: inout Set<Int>, insertions: [Int: [String]]) {
    let maps = index.maps.sorted { $0.path.count > $1.path.count }
    for map in maps {
      if keepsMap(map, index: index, deleted: deleted, insertions: insertions) { continue }
      deleted.insert(map.lineIndex)
    }
  }

  static func keepsMap(_ map: PatchMap, index: PatchIndex, deleted: Set<Int>, insertions: [Int: [String]]) -> Bool {
    if insertions[map.lineIndex] != nil { return true }
    let mapIndent = YamlText.indentWidth(index.lines[map.lineIndex])
    var cursor = map.lineIndex + 1
    while cursor < index.lines.count {
      let line = index.lines[cursor]
      if YamlText.isBlank(line) || YamlText.isCommentLine(line) {
        cursor += 1
        continue
      }
      if YamlText.indentWidth(line) <= mapIndent { break }
      if !deleted.contains(cursor) || insertions[cursor] != nil { return true }
      cursor += 1
    }
    return false
  }

  static func renderNewFile(edits: [String: PatchEdit]) -> String? {
    var lines = ["# Paretly settings", "# encoding: utf-8", "", "patch:"]
    var wrote = false
    for key in orderedEditKeys(edits) {
      guard case .set(let value) = edits[key] else { continue }
      lines.append("  \(key): \(dump(value))")
      wrote = true
    }
    if !wrote { return nil }
    return YamlText.joined(lines)
  }

  static func replacingValue(_ line: String, with value: YamlScalar) -> String {
    let leading = YamlText.leadingWhitespace(line)
    let content = String(line.dropFirst(leading.count))
    guard let split = YamlText.splitKeyValue(content) else { return line }
    let dumped = dump(value)
    if let comment = YamlText.trailingComment(in: split.rest) {
      return leading + split.key + ": " + dumped + String(comment)
    }
    return leading + split.key + ": " + dumped
  }

  static func dump(_ value: YamlScalar) -> String {
    switch value {
    case .bool(true):
      return "true"
    case .bool(false):
      return "false"
    case .int(let number):
      return String(number)
    case .double(let number):
      if number.isFinite, number.rounded() == number, number <= Double(Int.max), number >= Double(Int.min) {
        return String(Int(number))
      }
      return String(number)
    case .null:
      return "null"
    case .string(let text):
      return needsQuotes(text) ? quote(text) : text
    }
  }

  static func needsQuotes(_ text: String) -> Bool {
    if text.isEmpty || text != text.trimmingCharacters(in: .whitespaces) { return true }
    if ["true", "false", "null", "yes", "no", "~"].contains(text.lowercased()) { return true }
    let specials = CharacterSet(charactersIn: ":#[]{},&*!|>%@`\"'")
    return text.rangeOfCharacter(from: specials) != nil
  }

  static func quote(_ text: String) -> String {
    var encoded = "\""
    for scalar in text.unicodeScalars {
      switch scalar {
      case "\\":
        encoded += "\\\\"
      case "\"":
        encoded += "\\\""
      case "\n":
        encoded += "\\n"
      case "\t":
        encoded += "\\t"
      case "\r":
        encoded += "\\r"
      default:
        if scalar.value < 0x20 {
          encoded += String(format: "\\u%04x", scalar.value)
        } else {
          encoded.unicodeScalars.append(scalar)
        }
      }
    }
    encoded += "\""
    return encoded
  }
}

private extension ParetlyThemeDocument {
  static func parseScalar(_ raw: String) -> YamlScalar? {
    let text = raw.trimmingCharacters(in: .whitespaces)
    if text.isEmpty { return nil }
    if text.first == "\"" || text.first == "'" {
      let body: String
      if let comment = YamlText.trailingComment(in: text) {
        body = String(text[..<comment.startIndex]).trimmingCharacters(in: .whitespaces)
      } else {
        body = text
      }
      return interpret(body)
    }
    let plain: String
    if let comment = YamlText.unquotedCommentRange(in: text) {
      plain = String(text[..<comment.lowerBound]).trimmingCharacters(in: .whitespaces)
    } else {
      plain = text
    }
    if plain.isEmpty { return nil }
    return interpret(plain)
  }

  static func interpret(_ text: String) -> YamlScalar? {
    if text.isEmpty { return nil }
    switch text {
    case "true", "True", "yes", "YES":
      return .bool(true)
    case "false", "False", "no", "NO":
      return .bool(false)
    case "null", "Null", "~":
      return .null
    default:
      break
    }
    if text.count >= 2, let first = text.first, first == text.last, first == "'" || first == "\"" {
      return .string(YamlText.unquote(text))
    }
    if text.hasPrefix("0x"), text.dropFirst(2).allSatisfy(\.isHexDigit), text.count > 2 {
      return .string(text)
    }
    if isIntegerToken(text), let number = Int(text) {
      return .int(number)
    }
    if isFloatToken(text), let number = Double(text) {
      return .double(number)
    }
    return .string(text)
  }

  static func isIntegerToken(_ text: String) -> Bool {
    var index = text.startIndex
    if text.first == "-" {
      index = text.index(after: index)
    }
    guard index < text.endIndex else { return false }
    while index < text.endIndex {
      if !text[index].isNumber { return false }
      index = text.index(after: index)
    }
    return true
  }

  static func isFloatToken(_ text: String) -> Bool {
    var index = text.startIndex
    if text.first == "-" {
      index = text.index(after: index)
    }
    var sawDigit = false
    var sawDot = false
    while index < text.endIndex {
      let character = text[index]
      if character.isNumber {
        sawDigit = true
      } else if character == ".", !sawDot, sawDigit {
        sawDot = true
        sawDigit = false
      } else {
        return false
      }
      index = text.index(after: index)
    }
    return sawDot && sawDigit
  }

  static func readOptional(_ url: URL, fileManager: FileManager) -> String? {
    guard fileManager.fileExists(atPath: url.path) else { return nil }
    return try? String(contentsOf: url, encoding: .utf8)
  }
}

private enum YamlText {
  struct IndexedLine {
    var indent: Int
    var content: String
  }

  static func normalizedLines(_ text: String) -> [String] {
    var raw = text
    if raw.hasPrefix("\u{feff}") {
      raw.removeFirst()
    }
    raw = raw.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    return raw.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
  }

  static func normalize(_ text: String) -> String {
    joined(normalizedLines(text))
  }

  static func joined(_ lines: [String]) -> String {
    if lines.isEmpty || lines == [""] { return "" }
    var text = lines.joined(separator: "\n")
    if !text.hasSuffix("\n") {
      text += "\n"
    }
    return text
  }

  static func indentWidth(_ line: String) -> Int {
    var width = 0
    for character in line {
      if character == " " {
        width += 1
      } else if character == "\t" {
        width += 2
      } else {
        break
      }
    }
    return width
  }

  static func leadingWhitespace(_ line: String) -> String {
    var result = ""
    for character in line {
      if character == " " || character == "\t" {
        result.append(character)
      } else {
        break
      }
    }
    return result
  }

  static func isBlank(_ line: String) -> Bool {
    line.trimmingCharacters(in: .whitespaces).isEmpty
  }

  static func isCommentLine(_ line: String) -> Bool {
    line.trimmingCharacters(in: .whitespaces).hasPrefix("#")
  }

  static func isSectionHeader(_ line: String, name: String) -> Bool {
    guard indentWidth(line) == 0 else { return false }
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix(name + ":") else { return false }
    let after = trimmed.dropFirst(name.count + 1).trimmingCharacters(in: .whitespaces)
    return after.isEmpty || after.hasPrefix("#")
  }

  static func contentLines(afterHeader name: String, in lines: [String]) -> [IndexedLine] {
    guard let start = lines.firstIndex(where: { isSectionHeader($0, name: name) }) else { return [] }
    var result: [IndexedLine] = []
    var index = start + 1
    while index < lines.count {
      let line = lines[index]
      if isBlank(line) || isCommentLine(line) {
        index += 1
        continue
      }
      let indent = indentWidth(line)
      if indent == 0 { break }
      let leading = leadingWhitespace(line)
      result.append(IndexedLine(indent: indent, content: String(line.dropFirst(leading.count))))
      index += 1
    }
    return result
  }

  static func splitKeyValue(_ content: String) -> (key: String, rest: String)? {
    var index = content.startIndex
    guard index < content.endIndex, isKeyCharacter(content[index]) else { return nil }
    while index < content.endIndex, isKeyCharacter(content[index]) {
      index = content.index(after: index)
    }
    let key = String(content[..<index])
    guard index < content.endIndex, content[index] == ":" else { return nil }
    let after = content.index(after: index)
    let rest = content[after...].drop(while: { $0 == " " || $0 == "\t" })
    return (key, String(rest))
  }

  static func isKeyCharacter(_ character: Character) -> Bool {
    guard let scalar = character.unicodeScalars.first, character.unicodeScalars.count == 1, scalar.value < 128 else {
      return false
    }
    let value = scalar.value
    if (value >= 65 && value <= 90) || (value >= 97 && value <= 122) || (value >= 48 && value <= 57) {
      return true
    }
    return character == "_" || character == "." || character == "/" || character == "-"
  }

  static func unquotedCommentRange(in text: String) -> Range<String.Index>? {
    let space = text.range(of: " #")
    let tab = text.range(of: "\t#")
    switch (space, tab) {
    case let (left?, right?):
      return left.lowerBound <= right.lowerBound ? left : right
    case let (left?, nil):
      return left
    case let (nil, right?):
      return right
    default:
      return nil
    }
  }

  static func trailingComment(in rest: String) -> Substring? {
    guard let first = rest.first, first == "\"" || first == "'" else {
      guard let range = unquotedCommentRange(in: rest) else { return nil }
      return rest[range.lowerBound...]
    }
    var index = rest.index(after: rest.startIndex)
    var escaped = false
    while index < rest.endIndex {
      let character = rest[index]
      if escaped {
        escaped = false
      } else if character == "\\", first == "\"" {
        escaped = true
      } else if character == first {
        let after = rest.index(after: index)
        guard after < rest.endIndex else { return nil }
        let tail = rest[after...]
        guard tail.trimmingCharacters(in: .whitespaces).hasPrefix("#") else { return nil }
        if let hash = tail.firstIndex(of: "#") {
          var start = hash
          if hash > tail.startIndex {
            let previous = rest.index(before: hash)
            if rest[previous] == " " || rest[previous] == "\t" {
              start = previous
            }
          }
          return rest[start...]
        }
        return nil
      }
      index = rest.index(after: index)
    }
    return nil
  }

  static func unquote(_ text: String) -> String {
    guard text.count >= 2 else { return text }
    let body = text.dropFirst().dropLast()
    var result = ""
    var index = body.startIndex
    while index < body.endIndex {
      let character = body[index]
      let nextIndex = body.index(after: index)
      if character == "\\", nextIndex < body.endIndex {
        let next = body[nextIndex]
        if next == "u" {
          let hexStart = body.index(index, offsetBy: 2, limitedBy: body.endIndex) ?? body.endIndex
          let hexEnd = body.index(hexStart, offsetBy: 4, limitedBy: body.endIndex) ?? body.endIndex
          let hex = body[hexStart..<hexEnd]
          if hex.count == 4, let value = UInt32(String(hex), radix: 16), let scalar = UnicodeScalar(value) {
            result.append(Character(scalar))
            index = hexEnd
            continue
          }
        }
        switch next {
        case "n":
          result.append("\n")
        case "t":
          result.append("\t")
        case "\"", "'", "\\":
          result.append(next)
        default:
          result.append(next)
        }
        index = body.index(index, offsetBy: 2, limitedBy: body.endIndex) ?? body.endIndex
        continue
      }
      result.append(character)
      index = nextIndex
    }
    return result
  }
}
