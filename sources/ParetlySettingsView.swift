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
      Divider()
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          ForEach(ParetlySettingsSection.allCases, id: \.self) { section in
            sectionBody(section)
          }
        }
        .padding(.bottom, 24)
      }
    }
    .background(Color(nsColor: .windowBackgroundColor))
    .background(WindowCloseShortcuts())
    .onExitCommand {
      NSApp.keyWindow?.performClose(nil)
    }
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
    settingsGroup {
      Section {
        Picker(settingsText("Appearance"), selection: appearanceSelection) {
          Text(settingsText("Light")).tag(false)
          Text(settingsText("Dark")).tag(true)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: 280)
        .accessibilityLabel(Text(settingsText("Appearance")))
        .accessibilityHint(Text(appearanceExplanation))
      } header: {
        sectionHeader(.appearance)
      } footer: {
        Text(appearanceExplanation)
      }
    }
  }

  private var appearanceExplanation: String {
    settingsText("Scheme cards and the candidate preview use this appearance. A card fills this appearance's scheme.")
  }

  private var appearanceSelection: Binding<Bool> {
    Binding(get: { model.previewDark }, set: { model.setPreview(dark: $0) })
  }

  private var schemesSection: some View {
    settingsGroup {
      Section {
        SchemeMenu(model: model, slot: .light)
        SchemeMenu(model: model, slot: .dark)
      } header: {
        sectionHeader(.schemes)
      } footer: {
        Text(settingsText("The light scheme is used when the system appearance is light. The dark scheme is used when the system appearance is dark. Dark defaults to 简约黑 (clean_black)."))
      }
    }
  }

  private var candidateSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      settingsGroup {
        Section {
          Picker(settingsText("Layout"), selection: $model.candidateListLayout) {
            Text(settingsText("Horizontal")).tag("linear")
            Text(settingsText("Vertical")).tag("stacked")
          }
          .pickerStyle(.segmented)
          .accessibilityHint(Text(settingsText("Horizontal candidates sit on one line. Vertical candidates are stacked.")))
          SettingsSlider(title: settingsText("Candidate size"), value: $model.fontPoint, range: 12...28)
          SettingsSlider(title: settingsText("Label size"), value: $model.labelFontPoint, range: 10...24)
          SettingsSlider(title: settingsText("Corner radius"), value: $model.cornerRadius, range: 0...20)
        } header: {
          sectionHeader(.layout)
        } footer: {
          VStack(alignment: .leading, spacing: 4) {
            Text(settingsText("Horizontal candidates sit on one line. Vertical candidates are stacked."))
            Text(settingsText("Candidate size is 12 to 28 points. Label size is 10 to 24 points."))
            Text(settingsText("Corner radius is 0 to 20 points."))
          }
        }
      }
      CandidatePreview(
        palette: model.paletteForPreview(),
        layout: model.candidateListLayout,
        fontSize: CGFloat(model.fontPoint),
        labelSize: CGFloat(model.labelFontPoint),
        cornerRadius: CGFloat(model.cornerRadius)
      )
      .frame(maxWidth: .infinity, minHeight: 120)
      .padding(28)
      .frame(maxWidth: .infinity, minHeight: 168)
      .background(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(Color(nsColor: .underPageBackgroundColor))
      )
      .padding(.horizontal, 20)
      Text(settingsText("Sample candidate window for the selected appearance."))
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 20)
        .accessibilityHidden(true)
    }
    .padding(.top, 4)
  }

  private var updateSection: some View {
    settingsGroup {
      Section {
        Toggle(settingsText("Check for updates automatically"), isOn: $model.automaticUpdateChecks)
          .toggleStyle(.checkbox)
        Toggle(settingsText("Receive beta updates"), isOn: $model.includeBetaUpdates)
          .toggleStyle(.checkbox)
        Button(settingsText("Check for Updates…")) {
          ParetlyUpdatePresenter.shared.checkManually()
        }
      } header: {
        sectionHeader(.update)
      } footer: {
        Text(settingsText("Update Now asks for an administrator password, installs the package in place, and opens Paretly again. If that fails, the package opens in Installer."))
      }
    }
  }

  private func settingsGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    Form {
      content()
    }
    .formStyle(.grouped)
    .controlSize(.regular)
    .fixedSize(horizontal: false, vertical: true)
  }

  private var schemeLibrary: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionHeader(.schemesGrid)
        .padding(.horizontal, 20)
        .padding(.top, 8)
      Text(settingsText("Click a card to fill the selected slot, then Apply to save and redeploy."))
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 20)
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
        ForEach(model.schemes) { scheme in
          SchemeCard(model: model, scheme: scheme)
        }
      }
      .padding(.horizontal, 20)
    }
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
      Text(model.statusText)
        .font(.callout)
        .foregroundStyle(statusColor)
        .lineLimit(2)
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
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
    .background(Material.bar)
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

private struct SchemeMenu: View {
  @ObservedObject var model: ParetlySettingsModel
  var slot: ThemeSlot

  private var schemeID: String { slot == .light ? model.colorScheme : model.colorSchemeDark }

  var body: some View {
    Picker(settingsText(slot == .light ? "Light Scheme" : "Dark Scheme"), selection: selection) {
      ForEach(options) { scheme in
        Text(optionTitle(scheme)).tag(scheme.id)
      }
    }
    .accessibilityHint(Text(settingsText(slot == .light ? "Used when the system appearance is light" : "Used when the system appearance is dark")))
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

  private var isLight: Bool { model.colorScheme == scheme.id }
  private var isDark: Bool { model.colorSchemeDark == scheme.id }

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
          if isLight {
            roleBadge(settingsText("Light"))
          }
          if isDark {
            roleBadge(settingsText("Dark"))
          }
        }
      }
      .padding(10)
      .background(
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(Color(nsColor: .controlBackgroundColor))
      )
      .overlay(cardStroke)
    }
    .buttonStyle(.plain)
    .focused($focused)
    .accessibilityLabel(Text(accessibilityName))
    .accessibilityHint(Text(settingsText("Fills the selected appearance.")))
    .accessibilityAddTraits(isLight || isDark ? .isSelected : [])
  }

  private var accessibilityName: String {
    var parts = [scheme.name, scheme.id]
    if isLight { parts.append(settingsText("Light")) }
    if isDark { parts.append(settingsText("Dark")) }
    return parts.joined(separator: ", ")
  }

  private var cardStroke: some View {
    RoundedRectangle(cornerRadius: 10, style: .continuous)
      .stroke(strokeColor, lineWidth: focused || isLight || isDark ? 2 : 1)
  }

  private var strokeColor: Color {
    if focused || isLight {
      return Color.accentColor
    }
    if isDark {
      return Color.purple
    }
    return Color(nsColor: .separatorColor)
  }

  private func roleBadge(_ title: String) -> some View {
    Text(title)
      .font(.caption2.weight(.semibold))
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(Capsule().fill(Color.accentColor.opacity(0.15)))
  }
}

private struct WindowCloseShortcuts: View {
  var body: some View {
    ZStack {
      Button(action: closeWindow) { EmptyView() }
        .keyboardShortcut("w", modifiers: .command)
      Button(action: closeWindow) { EmptyView() }
        .keyboardShortcut(.cancelAction)
    }
    .accessibilityHidden(true)
    .frame(width: 0, height: 0)
  }

  private func closeWindow() {
    NSApp.keyWindow?.performClose(nil)
  }
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
      .frame(width: 1120, height: 800)
    ParetlyAboutPanelView()
      .previewDisplayName("About Panel")
      .frame(width: 460, height: 540)
  }
}
#endif
