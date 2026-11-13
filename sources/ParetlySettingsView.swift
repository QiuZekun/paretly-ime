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
      pane
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      Divider()
      SettingsActionBar(model: model)
    }
    .background(Color(nsColor: .windowBackgroundColor))
    .background(SettingsKeyShortcuts(model: model))
    .onExitCommand {
      NSApp.keyWindow?.performClose(nil)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  @ViewBuilder
  private var pane: some View {
    switch model.selectedTab {
    case .general:
      GeneralSettingsPane(model: model)
    case .appearance:
      AppearanceSettingsPane(model: model)
    case .input:
      InputSettingsPane(model: model)
    case .updates:
      UpdatesSettingsPane(model: model)
    case .about:
      AboutSettingsPane()
    }
  }
}

private struct GeneralSettingsPane: View {
  @ObservedObject var model: ParetlySettingsModel

  var body: some View {
    Form {
      Section {
        LabeledContent(settingsText("Settings File")) {
          Text(settingsPath)
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.trailing)
            .lineLimit(3)
            .textSelection(.enabled)
        }
      } footer: {
        Text(settingsText("Apply writes changed colors, layout, and sizes to ~/Library/Rime/paretly.custom.yaml, keeps other patches, and redeploys Rime."))
      }
      Section {
        LabeledContent(settingsText("Light Scheme")) {
          Text(model.schemeTitle(model.colorScheme))
        }
        LabeledContent(settingsText("Dark Scheme")) {
          Text(model.schemeTitle(model.colorSchemeDark))
        }
      } header: {
        Text(settingsText("Current Appearance"))
      } footer: {
        Text(settingsText("The light scheme is used when the system appearance is light. The dark scheme is used when the system appearance is dark. Dark defaults to 简约黑 (clean_black)."))
      }
    }
    .formStyle(.grouped)
    .controlSize(.regular)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  }

  private var settingsPath: String {
    SquirrelApp.userDir.appendingPathComponent(ParetlyThemeDocument.customFileName).path
  }
}

private struct AppearanceSettingsPane: View {
  @ObservedObject var model: ParetlySettingsModel

  var body: some View {
    Form {
      Section {
        schemePicker(settingsText("Light Scheme"), selection: lightSelection)
        schemePicker(settingsText("Dark Scheme"), selection: darkSelection)
      } header: {
        Text(settingsText("Color Schemes"))
      } footer: {
        Text(settingsText("The light scheme is used when the system appearance is light. The dark scheme is used when the system appearance is dark. Dark defaults to 简约黑 (clean_black)."))
      }
      Section {
        Picker(settingsText("Assign Cards To"), selection: slotSelection) {
          Text(settingsText("Light")).tag(ThemeSlot.light)
          Text(settingsText("Dark")).tag(ThemeSlot.dark)
        }
        .pickerStyle(.segmented)
        .accessibilityHint(Text(settingsText("Fills the selected appearance.")))
        CandidatePreview(
          palette: model.paletteForPreview(),
          layout: model.candidateListLayout,
          fontSize: CGFloat(model.fontPoint),
          labelSize: CGFloat(model.labelFontPoint),
          cornerRadius: CGFloat(model.cornerRadius)
        )
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(Color(nsColor: .separatorColor))
        )
      } header: {
        Text(settingsText("Preview"))
      } footer: {
        Text(settingsText("Sample candidate window for the selected appearance."))
      }
      Section {
        schemeCards
          .padding(.vertical, 4)
      } header: {
        Text(settingsText("All Schemes"))
      } footer: {
        Text(settingsText("Click a card to fill the selected slot, then Apply to save and redeploy."))
      }
      Section {
        SettingsSlider(title: settingsText("Corner radius"), value: $model.cornerRadius, range: 0...20)
      } footer: {
        Text(settingsText("Corner radius is 0 to 20 points."))
      }
    }
    .formStyle(.grouped)
    .controlSize(.regular)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  }

  private var schemeCards: some View {
    VStack(spacing: 12) {
      ForEach(pairedSchemeIDs, id: \.self) { row in
        HStack(alignment: .top, spacing: 12) {
          ForEach(row, id: \.self) { schemeID in
            if let scheme = model.scheme(id: schemeID) {
              SchemeCard(model: model, scheme: scheme)
                .frame(maxWidth: .infinity, alignment: .top)
            }
          }
          if row.count == 1 {
            Color.clear
              .frame(maxWidth: .infinity)
              .accessibilityHidden(true)
          }
        }
      }
    }
  }

  private var pairedSchemeIDs: [[String]] {
    let identifiers = model.schemes.map(\.id)
    return stride(from: 0, to: identifiers.count, by: 2).map { index in
      Array(identifiers[index..<min(index + 2, identifiers.count)])
    }
  }

  private var lightSelection: Binding<String> {
    Binding(get: { model.colorScheme }, set: { model.chooseLight($0) })
  }

  private var darkSelection: Binding<String> {
    Binding(get: { model.colorSchemeDark }, set: { model.chooseDark($0) })
  }

  private var slotSelection: Binding<ThemeSlot> {
    Binding(get: { model.activeSlot }, set: { model.activate($0) })
  }

  private func schemePicker(_ title: String, selection: Binding<String>) -> some View {
    Picker(title, selection: selection) {
      ForEach(choices(selected: selection.wrappedValue)) { scheme in
        Text(optionTitle(scheme)).tag(scheme.id)
      }
    }
  }

  private func choices(selected schemeID: String) -> [ThemeScheme] {
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

private struct InputSettingsPane: View {
  @ObservedObject var model: ParetlySettingsModel

  var body: some View {
    Form {
      Section {
        Picker(settingsText("Layout"), selection: $model.candidateListLayout) {
          Text(settingsText("Horizontal")).tag("linear")
          Text(settingsText("Vertical")).tag("stacked")
        }
        .pickerStyle(.radioGroup)
        SettingsSlider(title: settingsText("Candidate size"), value: $model.fontPoint, range: 12...28)
        SettingsSlider(title: settingsText("Label size"), value: $model.labelFontPoint, range: 10...24)
      } header: {
        Text(settingsText("Candidate Window"))
      } footer: {
        VStack(alignment: .leading, spacing: 4) {
          Text(settingsText("Horizontal candidates sit on one line. Vertical candidates are stacked."))
          Text(settingsText("Candidate size is 12 to 28 points. Label size is 10 to 24 points."))
        }
      }
    }
    .formStyle(.grouped)
    .controlSize(.regular)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  }
}

private struct UpdatesSettingsPane: View {
  @ObservedObject var model: ParetlySettingsModel

  var body: some View {
    Form {
      Section {
        Toggle(settingsText("Check for updates automatically"), isOn: $model.automaticUpdateChecks)
        Toggle(settingsText("Receive beta updates"), isOn: $model.includeBetaUpdates)
      } header: {
        Text(settingsText("Software Update"))
      } footer: {
        Text(settingsText("Beta releases are offered only when this is on. A beta build turns it on until you change it."))
      }
      Section {
        Button(settingsText("Check for Updates…")) {
          ParetlyUpdatePresenter.shared.checkManually()
        }
      } footer: {
        Text(settingsText("Update Now asks for an administrator password, installs the package in place, and opens Paretly again. If that fails, the package opens in Installer."))
      }
    }
    .formStyle(.grouped)
    .controlSize(.regular)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  }
}

private struct AboutSettingsPane: View {
  var body: some View {
    Form {
      Section {
        ParetlyAboutContent()
      } header: {
        Text(settingsText("About"))
      }
    }
    .formStyle(.grouped)
    .controlSize(.regular)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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

private struct SettingsActionBar: View {
  @ObservedObject var model: ParetlySettingsModel

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      Text(model.statusText)
        .font(.callout)
        .foregroundStyle(statusColor)
        .lineLimit(2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHidden(model.statusText.isEmpty)
      Button(settingsText("Deploy")) {
        model.redeploy()
      }
      .disabled(model.applying)
      .help(settingsText("Redeploy reloads Rime. It does not change the choices in this window."))
      Button(settingsText("Apply")) {
        model.apply()
      }
      .keyboardShortcut(.defaultAction)
      .buttonStyle(.borderedProminent)
      .disabled(model.applying || model.schemes.isEmpty)
    }
    .controlSize(.regular)
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
    .background(Material.bar)
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

private struct SettingsKeyShortcuts: View {
  @ObservedObject var model: ParetlySettingsModel

  var body: some View {
    ZStack {
      WindowCloseShortcuts()
      ForEach(ParetlySettingsTab.allCases, id: \.rawValue) { tab in
        Button(action: { model.selectedTab = tab }) {
          EmptyView()
        }
        .keyboardShortcut(KeyEquivalent(tab.shortcut), modifiers: .command)
        .accessibilityHidden(true)
        .frame(width: 0, height: 0)
      }
    }
    .accessibilityHidden(true)
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
  static func previewModel(tab: ParetlySettingsTab) -> ParetlySettingsModel {
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
    model.selectedTab = tab
    return model
  }
}

struct ParetlySettingsView_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      settingsPreview(.general, "General")
      settingsPreview(.appearance, "Appearance")
      settingsPreview(.input, "Input")
      settingsPreview(.updates, "Updates")
      settingsPreview(.about, "About")
      ParetlyAboutPanelView()
        .previewDisplayName("About Panel")
        .frame(width: 460, height: 540)
    }
  }

  private static func settingsPreview(_ tab: ParetlySettingsTab, _ name: String) -> some View {
    ParetlySettingsView(model: .previewModel(tab: tab))
      .previewDisplayName(name)
      .frame(width: 860, height: 680)
  }
}
#endif
