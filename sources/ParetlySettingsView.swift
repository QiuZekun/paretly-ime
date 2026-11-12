//
//  ParetlySettingsView.swift
//  Paretly
//
//  Copyright (C) 2026 Paretly contributors
//
//  This file is part of Paretly, a GPL-3.0 fork of Squirrel (鼠须管).
//  See LICENSE.txt.

import SwiftUI

struct SettingsChrome {
  var dark: Bool

  var background: Color { dark ? rgb(29, 29, 31) : rgb(232, 232, 237) }
  var panel: Color { dark ? rgb(44, 44, 46) : .white }
  var text: Color { dark ? rgb(245, 245, 247) : rgb(29, 29, 31) }
  var muted: Color { dark ? rgb(161, 161, 166) : rgb(110, 110, 115) }
  var line: Color { dark ? rgb(58, 58, 60) : rgb(210, 210, 215) }
  var accent: Color { dark ? rgb(10, 132, 255) : rgb(0, 113, 227) }
  var accentDark: Color { dark ? rgb(218, 143, 255) : rgb(175, 82, 222) }
  var desk: Color { dark ? rgb(20, 20, 22) : rgb(201, 205, 212) }
  var ok: Color { dark ? rgb(50, 215, 75) : rgb(36, 138, 61) }
  var warn: Color { dark ? rgb(255, 214, 10) : rgb(154, 103, 0) }
  var err: Color { dark ? rgb(255, 69, 58) : rgb(215, 0, 21) }

  func status(_ kind: ThemeStatusKind) -> Color {
    switch kind {
    case .neutral: return muted
    case .ok: return ok
    case .warn: return warn
    case .err: return err
    }
  }

  private func rgb(_ red: Double, _ green: Double, _ blue: Double) -> Color {
    Color(red: red / 255, green: green / 255, blue: blue / 255)
  }
}

struct ParetlySettingsView: View {
  @ObservedObject var model: ParetlySettingsModel

  private var chrome: SettingsChrome { SettingsChrome(dark: model.previewDark) }

  var body: some View {
    let palette = chrome
    ZStack {
      palette.background.ignoresSafeArea()
      VStack(spacing: 0) {
        header(palette)
        Divider().overlay(palette.line)
        if let banner = model.banner {
          Text(banner)
            .font(.system(size: 13))
            .foregroundStyle(palette.err)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(palette.err.opacity(0.12))
        }
        controls(palette)
        stage(palette)
        ScrollView {
          schemeGrid(palette)
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 28)
        }
      }
    }
    .foregroundStyle(palette.text)
    .environment(\.colorScheme, model.previewDark ? .dark : .light)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func header(_ palette: SettingsChrome) -> some View {
    HStack(spacing: 12) {
      Text("中")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(palette.dark ? rgbText(29, 29, 31) : .white)
        .frame(width: 28, height: 28)
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(palette.dark ? rgbText(245, 245, 247) : rgbText(29, 29, 31)))
      Text(settingsText("Paretly Colors"))
        .font(.system(size: 16, weight: .semibold))
      previewSwitch(palette)
      Text(model.statusText)
        .font(.system(size: 12))
        .foregroundStyle(palette.status(model.statusKind))
        .lineLimit(1)
      Spacer(minLength: 8)
      Button(action: { model.redeploy() }) {
        Text(settingsText("Deploy"))
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(palette.accent)
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .stroke(palette.accent, lineWidth: 1)
          )
      }
      .buttonStyle(.plain)
      .disabled(model.applying)
      Button(action: { model.apply() }) {
        Text(settingsText("Apply"))
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.white)
          .padding(.horizontal, 16)
          .padding(.vertical, 6)
          .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(palette.accent.opacity(model.applying ? 0.55 : 1)))
      }
      .buttonStyle(.plain)
      .disabled(model.applying || model.schemes.isEmpty)
      .keyboardShortcut(.defaultAction)
    }
    .padding(.horizontal, 20)
    .padding(.top, 16)
    .padding(.bottom, 10)
  }

  private func previewSwitch(_ palette: SettingsChrome) -> some View {
    HStack(spacing: 0) {
      previewButton(settingsText("Light Preview"), dark: false, palette: palette)
      previewButton(settingsText("Dark Preview"), dark: true, palette: palette)
    }
    .padding(2)
    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(palette.dark ? rgbText(35, 35, 38) : rgbText(246, 246, 248)))
    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(palette.line, lineWidth: 1))
  }

  private func previewButton(_ title: String, dark: Bool, palette: SettingsChrome) -> some View {
    let selected = model.previewDark == dark
    return Button(action: { model.setPreview(dark: dark) }) {
      Text(title)
        .font(.system(size: 13, weight: selected ? .semibold : .regular))
        .foregroundStyle(selected ? palette.text : palette.muted)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(
          RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(selected ? palette.panel : .clear)
            .shadow(color: .black.opacity(selected ? 0.08 : 0), radius: 1, y: 1)
        )
    }
    .buttonStyle(.plain)
  }

  private func controls(_ palette: SettingsChrome) -> some View {
    VStack(spacing: 12) {
      HStack(spacing: 12) {
        SchemeSlot(model: model, slot: .light, palette: palette)
        SchemeSlot(model: model, slot: .dark, palette: palette)
      }
      metrics(palette)
    }
    .padding(.horizontal, 20)
    .padding(.top, 14)
  }

  private func metrics(_ palette: SettingsChrome) -> some View {
    HStack(spacing: 16) {
      HStack(spacing: 0) {
        layoutButton(settingsText("Horizontal"), value: "linear", palette: palette)
        layoutButton(settingsText("Vertical"), value: "stacked", palette: palette)
      }
      .padding(2)
      .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(palette.dark ? rgbText(35, 35, 38) : rgbText(246, 246, 248)))
      .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(palette.line, lineWidth: 1))
      metricSlider(settingsText("Candidate size"), value: $model.fontPoint, range: 12...28, palette: palette)
      metricSlider(settingsText("Label size"), value: $model.labelFontPoint, range: 10...24, palette: palette)
      metricSlider(settingsText("Corner radius"), value: $model.cornerRadius, range: 0...20, palette: palette)
      Spacer(minLength: 8)
      Text(settingsText("Click a card to fill the selected slot, then Apply to save and redeploy."))
        .font(.system(size: 12))
        .foregroundStyle(palette.muted)
        .multilineTextAlignment(.trailing)
        .frame(maxWidth: 280, alignment: .trailing)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(palette.panel))
    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(palette.line, lineWidth: 1))
  }

  private func layoutButton(_ title: String, value: String, palette: SettingsChrome) -> some View {
    let selected = model.candidateListLayout == value
    return Button(action: { model.candidateListLayout = value }) {
      Text(title)
        .font(.system(size: 13, weight: selected ? .semibold : .regular))
        .foregroundStyle(selected ? palette.text : palette.muted)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(selected ? palette.panel : .clear))
    }
    .buttonStyle(.plain)
  }

  private func metricSlider(_ title: String, value: Binding<Int>, range: ClosedRange<Int>, palette: SettingsChrome) -> some View {
    HStack(spacing: 8) {
      Text(title)
        .font(.system(size: 13))
        .foregroundStyle(palette.muted)
      Slider(
        value: Binding(get: { Double(value.wrappedValue) }, set: { value.wrappedValue = Int($0.rounded()) }),
        in: Double(range.lowerBound)...Double(range.upperBound),
        step: 1
      )
      .frame(width: 108)
      .tint(palette.accent)
      Text("\(value.wrappedValue)")
        .font(.system(size: 13))
        .monospacedDigit()
        .frame(width: 22, alignment: .trailing)
    }
  }

  private func stage(_ palette: SettingsChrome) -> some View {
    ZStack {
      CandidatePreview(
        palette: model.paletteForPreview(),
        layout: model.candidateListLayout,
        fontSize: CGFloat(model.fontPoint),
        labelSize: CGFloat(model.labelFontPoint),
        cornerRadius: CGFloat(model.cornerRadius)
      )
    }
    .frame(maxWidth: .infinity, minHeight: 168)
    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(palette.desk))
    .padding(.horizontal, 20)
    .padding(.top, 14)
    .padding(.bottom, 16)
  }

  private func schemeGrid(_ palette: SettingsChrome) -> some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 12)], spacing: 12) {
      ForEach(model.schemes) { scheme in
        SchemeCard(model: model, scheme: scheme, palette: palette)
      }
    }
  }

  private func rgbText(_ red: Double, _ green: Double, _ blue: Double) -> Color {
    Color(red: red / 255, green: green / 255, blue: blue / 255)
  }
}

private struct SchemeSlot: View {
  @ObservedObject var model: ParetlySettingsModel
  var slot: ThemeSlot
  var palette: SettingsChrome

  private var schemeID: String { slot == .light ? model.colorScheme : model.colorSchemeDark }
  private var active: Bool { model.activeSlot == slot }

  var body: some View {
    let border = active ? (slot == .light ? palette.accent : palette.accentDark) : palette.line
    let tint = slot == .light ? palette.accent : palette.accentDark
    HStack(spacing: 10) {
      Text(settingsText(slot == .light ? "Light" : "Dark"))
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(Capsule().fill(tint.opacity(0.18)))
      VStack(alignment: .leading, spacing: 1) {
        Text(model.scheme(id: schemeID)?.name ?? (schemeID.isEmpty ? "—" : schemeID))
          .font(.system(size: 13, weight: .semibold))
          .lineLimit(1)
        Text(settingsText(slot == .light ? "Used when the system appearance is light" : "Used when the system appearance is dark"))
          .font(.system(size: 12))
          .foregroundStyle(palette.muted)
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
      .onTapGesture { model.activate(slot) }
      Picker(slot == .light ? settingsText("Light") : settingsText("Dark"), selection: selection) {
        ForEach(options, id: \.id) { scheme in
          Text(optionTitle(scheme)).tag(scheme.id)
        }
      }
      .labelsHidden()
      .frame(maxWidth: 210)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(palette.panel))
    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(border, lineWidth: 2))
  }

  private var selection: Binding<String> {
    Binding(get: { schemeID }, set: { schemeID in
      if slot == .light {
        model.chooseLight(schemeID)
      } else {
        model.chooseDark(schemeID)
      }
    })
  }

  private var options: [ThemeScheme] {
    var list = model.schemes
    if !schemeID.isEmpty, !list.contains(where: { $0.id == schemeID }) {
      list.append(ThemeScheme(
        id: schemeID,
        name: schemeID,
        author: "",
        isNative: false,
        fields: [:],
        palette: model.previewDark ? .nativeDark : .nativeLight,
        lightPalette: nil,
        darkPalette: nil
      ))
    }
    return list
  }

  private func optionTitle(_ scheme: ThemeScheme) -> String {
    if model.schemes.contains(where: { $0.id == scheme.id }) {
      return "\(scheme.name) (\(scheme.id))"
    }
    return "\(scheme.id) \(settingsText("Not in the theme file"))"
  }
}

private struct SchemeCard: View {
  @ObservedObject var model: ParetlySettingsModel
  var scheme: ThemeScheme
  var palette: SettingsChrome
  @State private var hovered = false

  private var isLight: Bool { model.colorScheme == scheme.id }
  private var isDark: Bool { model.colorSchemeDark == scheme.id }

  var body: some View {
    Button(action: { model.assign(scheme.id) }) {
      VStack(alignment: .leading, spacing: 7) {
        ZStack {
          CandidatePreview(
            palette: scheme.palette(previewDark: model.previewDark),
            layout: "linear",
            fontSize: 13,
            labelSize: 11,
            cornerRadius: 7,
            compact: true
          )
        }
        .frame(maxWidth: .infinity, minHeight: 78)
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(
          LinearGradient(
            colors: [Color.black.opacity(palette.dark ? 0.03 : 0.04), Color.black.opacity(palette.dark ? 0.25 : 0.08)],
            startPoint: .top,
            endPoint: .bottom
          )
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text(scheme.name)
            .font(.system(size: 12, weight: .semibold))
            .lineLimit(1)
          Text(scheme.id)
            .font(.system(size: 11))
            .foregroundStyle(palette.muted)
            .lineLimit(1)
          Spacer(minLength: 4)
          if isLight {
            badge(settingsText("Light"), tint: palette.accent)
          }
          if isDark {
            badge(settingsText("Dark"), tint: palette.accentDark)
          }
        }
      }
      .padding(10)
      .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(palette.panel))
      .overlay(cardStroke)
    }
    .buttonStyle(.plain)
    .offset(y: hovered ? -1 : 0)
    .onHover { hovered = $0 }
    .accessibilityLabel(Text("\(scheme.name) \(scheme.id)"))
  }

  private var cardStroke: some View {
    RoundedRectangle(cornerRadius: 14, style: .continuous)
      .stroke(isLight ? palette.accent : (isDark ? palette.accentDark : palette.line), lineWidth: 2)
      .overlay {
        if isLight && isDark {
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(palette.accentDark, lineWidth: 2)
            .padding(3)
        }
      }
  }

  private func badge(_ title: String, tint: Color) -> some View {
    Text(title)
      .font(.system(size: 10, weight: .semibold))
      .foregroundStyle(tint)
      .padding(.horizontal, 5)
      .padding(.vertical, 1)
      .background(Capsule().fill(tint.opacity(0.18)))
  }
}

private func settingsText(_ key: String) -> String {
  NSLocalizedString(key, comment: "Settings")
}
