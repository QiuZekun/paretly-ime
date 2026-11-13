//
//  ParetlySettingsView.swift
//  Paretly
//
//  Copyright (C) 2026 Paretly contributors
//
//  This file is part of Paretly, a GPL-3.0 fork of Squirrel (鼠须管).
//  See LICENSE.txt.

import AppKit
import SwiftUI

struct ParetlySettingsView: View {
  @ObservedObject var model: ParetlySettingsModel

  var body: some View {
    VStack(spacing: 0) {
      if let banner = model.banner {
        SettingsBanner(text: banner)
      }
      SettingsHeader(model: model)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
      Divider()
      ScrollView {
        Form {
          ForEach(ParetlySettingsSection.allCases, id: \.self) { section in
            sectionBody(section)
          }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)
      }
    }
    .background(Color(nsColor: .windowBackgroundColor))
    .background(WindowCloseShortcuts())
    .onExitCommand(perform: closeKeyWindow)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  @ViewBuilder
  private func sectionBody(_ section: ParetlySettingsSection) -> some View {
    switch section {
    case .appearance:
      appearanceSection
    case .schemes:
      schemesSection
    case .schemesGrid:
      schemeLibrary
    case .layout:
      candidateSection
    case .update:
      updateSection
    }
  }

  private var appearanceSection: some View {
    Section {
      Picker(settingsText("Appearance"), selection: appearanceSelection) {
        Text(settingsText("Light")).tag(false)
        Text(settingsText("Dark")).tag(true)
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .frame(maxWidth: 280)
      .accessibilityLabel(Text(settingsText("Appearance")))
      .help(appearanceExplanation)
    } header: {
      sectionHeader(.appearance)
    }
  }

  private var appearanceExplanation: String {
    settingsText("Scheme cards and the candidate preview use this appearance. A card fills this appearance's scheme.")
  }

  private var appearanceSelection: Binding<Bool> {
    Binding(get: { model.previewDark }, set: { model.setPreview(dark: $0) })
  }

  private var schemesSection: some View {
    Section {
      HStack(spacing: 20) {
        SchemeSelection(model: model, slot: .light)
        SchemeSelection(model: model, slot: .dark)
      }
    } header: {
      sectionHeader(.schemes)
    }
  }

  private var candidateSection: some View {
    Section {
      Picker(settingsText("Layout"), selection: $model.candidateListLayout) {
        Text(settingsText("Horizontal")).tag("linear")
        Text(settingsText("Vertical")).tag("stacked")
      }
      .pickerStyle(.segmented)
      SettingsSlider(title: settingsText("Candidate size"), value: $model.fontPoint, range: 12...28)
      SettingsSlider(title: settingsText("Label size"), value: $model.labelFontPoint, range: 10...24)
      SettingsSlider(title: settingsText("Corner radius"), value: $model.cornerRadius, range: 0...20)
    } header: {
      sectionHeader(.layout)
    }
  }

  private var updateSection: some View {
    Section {
      Toggle(settingsText("Check for updates automatically"), isOn: $model.automaticUpdateChecks)
        .toggleStyle(.checkbox)
      Toggle(settingsText("Receive beta updates"), isOn: $model.includeBetaUpdates)
        .toggleStyle(.checkbox)
        .help(settingsText("Beta releases are offered only when this is on. A beta build turns it on until you change it."))
      Button(settingsText("Check for Updates…")) {
        ParetlyUpdatePresenter.shared.checkManually()
      }
    } header: {
      sectionHeader(.update)
    }
  }

  private var schemeLibrary: some View {
    Section {
      schemeAndPreview
    } header: {
      sectionHeader(.schemesGrid)
    }
  }

  private var schemeAndPreview: some View {
    HStack(alignment: .top, spacing: 12) {
      ScrollView {
        LazyVStack(spacing: 12) {
          ForEach(model.schemes) { scheme in
            SchemeCard(model: model, scheme: scheme)
          }
        }
        .padding(.vertical, 2)
      }
      .scrollDisabled(false)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

      VStack {
        Spacer(minLength: 0)
        CandidatePreview(
          palette: model.paletteForPreview(),
          layout: model.candidateListLayout,
          fontSize: CGFloat(model.fontPoint),
          labelSize: CGFloat(model.labelFontPoint),
          cornerRadius: CGFloat(model.cornerRadius)
        )
        .padding(16)
        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(Color(nsColor: .textBackgroundColor))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
      )
    }
    .frame(height: 312)
  }

  private func sectionHeader(_ section: ParetlySettingsSection) -> some View {
    Label(settingsText(section.titleKey), systemImage: section.symbolName)
      .accessibilityAddTraits(.isHeader)
  }
}

private struct SettingsHeader: View {
  @ObservedObject var model: ParetlySettingsModel

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      headerIcon
      ParetlyTryField()
        .frame(width: 196)
      Text(model.statusText)
        .font(.callout)
        .foregroundStyle(statusColor)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHidden(model.statusText.isEmpty)
      Button(settingsText("Deploy")) {
        model.redeploy()
      }
      .buttonStyle(.bordered)
      .disabled(model.applying)
      .help(settingsText("Redeploy reloads Rime. It does not change the choices in this window."))
      Button(settingsText("Apply")) {
        model.apply()
      }
      .keyboardShortcut(.defaultAction)
      .buttonStyle(.borderedProminent)
      .disabled(model.applying || model.schemes.isEmpty)
      .help(settingsText("Apply writes changed colors, layout, and sizes to ~/Library/Rime/paretly.custom.yaml, keeps other patches, and redeploys Rime."))
      .accessibilityHint(Text(settingsText("Apply writes changed colors, layout, and sizes to ~/Library/Rime/paretly.custom.yaml, keeps other patches, and redeploys Rime.")))
    }
    .controlSize(.regular)
  }

  @ViewBuilder
  private var headerIcon: some View {
    if let image = ParetlyAppIcon.image {
      Image(nsImage: image)
        .resizable()
        .frame(width: 32, height: 32)
        .accessibilityLabel(Text("Paretly"))
    } else {
      Image(systemName: "keyboard")
        .font(.title2)
        .frame(width: 32, height: 32)
        .accessibilityLabel(Text("Paretly"))
    }
  }

  private var statusColor: Color {
    switch model.statusKind {
    case .neutral:
      return Color(nsColor: .secondaryLabelColor)
    case .ok:
      return Color(nsColor: .systemGreen)
    case .warn:
      return Color(nsColor: .systemOrange)
    case .err:
      return Color(nsColor: .systemRed)
    }
  }
}

private struct SchemeSelection: View {
  @ObservedObject var model: ParetlySettingsModel
  var slot: ThemeSlot

  private var schemeID: String { slot == .light ? model.colorScheme : model.colorSchemeDark }

  var body: some View {
    HStack(spacing: 6) {
      SchemeSwatch(palette: model.palette(for: slot))
      Text(String(format: settingsText(slot == .light ? "Light: %@" : "Dark: %@"), model.schemeTitle(schemeID)))
        .lineLimit(1)
        .truncationMode(.tail)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}

private struct SchemeSwatch: View {
  var palette: ThemePalette

  var body: some View {
    RoundedRectangle(cornerRadius: 3, style: .continuous)
      .fill(palette.back.isClear ? Color(palette.candidateText) : Color(palette.back))
      .overlay(alignment: .bottomTrailing) {
        Circle()
          .fill(Color(palette.hilitedCandidateBack))
          .frame(width: 6, height: 6)
          .padding(1)
      }
      .overlay(
        RoundedRectangle(cornerRadius: 3, style: .continuous)
          .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
      )
      .frame(width: 14, height: 14)
      .accessibilityHidden(true)
  }
}

struct ParetlyAboutPanelView: View {
  var body: some View {
    ScrollView {
      ParetlyAboutContent()
        .padding(24)
    }
    .background(Color(nsColor: .windowBackgroundColor))
    .background(WindowCloseShortcuts())
    .onExitCommand {
      NSApp.keyWindow?.performClose(nil)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

struct ParetlyAboutContent: View {
  var body: some View {
    VStack(spacing: 14) {
      icon
      Text("Paretly")
        .font(.title2.weight(.semibold))
        .accessibilityAddTraits(.isHeader)
      Text(ParetlyAbout.versionLabel(marketingVersion: ParetlyAbout.marketingVersion()))
        .font(.body)
        .foregroundStyle(.secondary)
      Text(settingsText("Licensed under GPL-3.0."))
        .font(.body)
      Text(settingsText("Paretly is a GPL-3.0 fork of Squirrel. It uses librime and ships Rime ICE."))
        .font(.callout)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 380)
      VStack(alignment: .leading, spacing: 8) {
        Text(settingsText("Credits"))
          .font(.headline)
          .frame(maxWidth: .infinity, alignment: .leading)
        ForEach(ParetlyAbout.credits, id: \.name) { credit in
          HStack(alignment: .firstTextBaseline) {
            Link(credit.name, destination: credit.url)
              .accessibilityHint(Text(credit.url.absoluteString))
            Spacer(minLength: 12)
            Text(credit.url.host ?? "")
              .font(.caption)
              .foregroundStyle(.secondary)
              .accessibilityHidden(true)
          }
        }
      }
      .frame(maxWidth: 380)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 8)
  }

  @ViewBuilder
  private var icon: some View {
    if let image = ParetlyAppIcon.image {
      Image(nsImage: image)
        .resizable()
        .frame(width: 96, height: 96)
        .accessibilityLabel(Text("Paretly"))
    } else {
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .fill(Color(nsColor: .controlBackgroundColor))
        .frame(width: 96, height: 96)
        .overlay(Text("中").font(.largeTitle))
        .accessibilityLabel(Text("Paretly"))
    }
  }
}

private struct SettingsBanner: View {
  var text: String

  var body: some View {
    Label(text, systemImage: "exclamationmark.triangle.fill")
      .font(.callout)
      .foregroundStyle(Color(nsColor: .systemRed))
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 20)
      .padding(.vertical, 10)
      .background(Color(nsColor: .systemRed).opacity(0.12))
      .accessibilityElement(children: .combine)
  }
}

private struct SettingsSlider: View {
  var title: String
  @Binding var value: Int
  var range: ClosedRange<Int>

  var body: some View {
    LabeledContent(title) {
      HStack(spacing: 8) {
        Slider(
          value: Binding(
            get: { Double(value) },
            set: { value = Int($0.rounded()) }
          ),
          in: Double(range.lowerBound)...Double(range.upperBound),
          step: 1
        )
        .accessibilityValue(Text("\(value)"))
        Text("\(value)")
          .font(.body.monospacedDigit())
          .frame(width: 36, alignment: .trailing)
          .accessibilityHidden(true)
      }
    }
  }
}

private struct SchemeCard: View {
  @ObservedObject var model: ParetlySettingsModel
  var scheme: ThemeScheme
  @FocusState private var focused: Bool

  private var isSelected: Bool {
    let activeID = model.previewDark ? model.colorSchemeDark : model.colorScheme
    return scheme.id == activeID
  }

  var body: some View {
    Button(action: { model.assign(scheme.id) }) {
      VStack(alignment: .leading, spacing: 8) {
        CandidatePreview(
          palette: scheme.palette(previewDark: model.previewDark),
          layout: "linear",
          fontSize: 13,
          labelSize: 11,
          cornerRadius: 7,
          compact: true
        )
        .frame(maxWidth: .infinity, minHeight: 72)
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text(scheme.name)
            .font(.callout.weight(.semibold))
            .lineLimit(1)
          Text(scheme.id)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
          Spacer(minLength: 4)
          if isSelected {
            Image(systemName: "checkmark")
              .font(.body.weight(.semibold))
              .foregroundStyle(Color.accentColor)
              .accessibilityHidden(true)
          }
        }
      }
      .padding(10)
      .background(
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor))
      )
      .overlay(cardStroke)
    }
    .buttonStyle(.plain)
    .focused($focused)
    .help(settingsText("Fills the selected appearance."))
    .accessibilityLabel(Text("\(scheme.name), \(scheme.id)"))
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  private var cardStroke: some View {
    RoundedRectangle(cornerRadius: 10, style: .continuous)
      .strokeBorder(isSelected || focused ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: isSelected || focused ? 2 : 1)
  }
}

private struct WindowCloseShortcuts: View {
  var body: some View {
    ZStack {
      Button(action: closeKeyWindow) { EmptyView() }
        .keyboardShortcut("w", modifiers: .command)
      Button(action: closeKeyWindow) { EmptyView() }
        .keyboardShortcut(.cancelAction)
    }
    .accessibilityHidden(true)
    .frame(width: 0, height: 0)
  }
}

private func closeKeyWindow() {
  guard let window = NSApp.keyWindow else { return }
  if let editor = window.fieldEditor(false, for: nil), window.firstResponder === editor {
    return
  }
  window.performClose(nil)
}

private func settingsText(_ key: String) -> String {
  NSLocalizedString(key, comment: "Settings")
}

#if DEBUG
extension ParetlySettingsModel {
  static func previewModel() -> ParetlySettingsModel {
    let model = ParetlySettingsModel()
    model.schemes = [
      ThemeScheme(
        id: "native",
        name: "系统配色",
        author: "",
        isNative: true,
        fields: [:],
        palette: .nativeLight,
        lightPalette: .nativeLight,
        darkPalette: .nativeDark
      ),
      ThemeScheme(
        id: "clean_white",
        name: "简约白",
        author: "",
        isNative: false,
        fields: [:],
        palette: .nativeLight,
        lightPalette: nil,
        darkPalette: nil
      ),
      ThemeScheme(
        id: "clean_black",
        name: "简约黑",
        author: "",
        isNative: false,
        fields: [:],
        palette: .nativeDark,
        lightPalette: nil,
        darkPalette: nil
      )
    ]
    model.colorScheme = "native"
    model.colorSchemeDark = "clean_black"
    return model
  }
}

struct ParetlySettingsView_Previews: PreviewProvider {
  static var previews: some View {
    ParetlySettingsView(model: .previewModel())
      .previewDisplayName("Settings")
      .frame(width: 800, height: 760)
    ParetlyAboutPanelView()
      .previewDisplayName("About Panel")
      .frame(width: 460, height: 540)
  }
}
#endif
