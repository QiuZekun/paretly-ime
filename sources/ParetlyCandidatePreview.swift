//
//  ParetlyCandidatePreview.swift
//  Paretly
//
//  Copyright (C) 2026 Paretly contributors
//
//  This file is part of Paretly, a GPL-3.0 fork of Squirrel (鼠须管).
//  See LICENSE.txt.

import SwiftUI

extension Color {
  init(_ rgba: ThemeRGBA) {
    if rgba.isClear || rgba.alpha <= 0 {
      self = .clear
    } else {
      self.init(
        .sRGB,
        red: Double(rgba.red) / 255,
        green: Double(rgba.green) / 255,
        blue: Double(rgba.blue) / 255,
        opacity: rgba.alpha
      )
    }
  }
}

struct FlowLayout: Layout {
  var spacing: CGFloat = 2

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let maxWidth = proposal.width ?? .greatestFiniteMagnitude
    var x: CGFloat = 0
    var y: CGFloat = 0
    var rowHeight: CGFloat = 0
    var usedWidth: CGFloat = 0
    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if x > 0, x + size.width > maxWidth {
        x = 0
        y += rowHeight + spacing
        rowHeight = 0
      }
      rowHeight = max(rowHeight, size.height)
      x += size.width
      if x > 0 { x += spacing }
      usedWidth = max(usedWidth, x - spacing)
    }
    let width = proposal.width ?? usedWidth
    return CGSize(width: width, height: y + rowHeight)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    var x = bounds.minX
    var y = bounds.minY
    var rowHeight: CGFloat = 0
    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if x > bounds.minX, x + size.width > bounds.maxX + 0.5 {
        x = bounds.minX
        y += rowHeight + spacing
        rowHeight = 0
      }
      subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(width: size.width, height: size.height))
      rowHeight = max(rowHeight, size.height)
      x += size.width + spacing
    }
  }
}

struct CandidatePreview: View {
  var palette: ThemePalette
  var layout: String
  var fontSize: CGFloat
  var labelSize: CGFloat
  var cornerRadius: CGFloat
  var compact: Bool = false

  private let rows = [("1", "你好"), ("2", "拟好"), ("3", "你"), ("4", "呢"), ("5", "尼")]

  var body: some View {
    let radius = max(0, cornerRadius)
    VStack(alignment: .leading, spacing: compact ? 2 : 4) {
      Text("ni hao")
        .font(.system(size: max(9, fontSize * (compact ? 0.85 : 0.9)), design: .monospaced))
        .foregroundStyle(Color(palette.text))
        .padding(.horizontal, 6)
        .padding(.vertical, 1)
        .background(Color(palette.preeditBack))
        .clipShape(RoundedRectangle(cornerRadius: radius * 0.4, style: .continuous))
      candidates
    }
    .padding(.horizontal, compact ? 4 : 6)
    .padding(.vertical, compact ? 4 : 5)
    .background(Color(palette.back))
    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: radius, style: .continuous)
        .stroke(Color(palette.border), lineWidth: 1)
    )
    .shadow(color: .black.opacity(compact ? 0.16 : 0.22), radius: compact ? 3 : 12, y: compact ? 1 : 6)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(NSLocalizedString("Candidate preview", comment: "Settings")))
    .accessibilityHint(Text(NSLocalizedString("Sample candidate window for the selected appearance.", comment: "Settings")))
    .accessibilityHidden(compact)
  }

  @ViewBuilder
  private var candidates: some View {
    if layout == "stacked" {
      VStack(alignment: .leading, spacing: 2) {
        ForEach(rows.indices, id: \.self) { index in
          candidate(index)
        }
      }
    } else {
      FlowLayout(spacing: 2) {
        ForEach(rows.indices, id: \.self) { index in
          candidate(index)
        }
      }
    }
  }

  private func candidate(_ index: Int) -> some View {
    let hilited = index == 0
    return HStack(alignment: .firstTextBaseline, spacing: compact ? 3 : 4) {
      Text(rows[index].0)
        .font(.system(size: labelSize))
        .foregroundStyle(Color(hilited ? palette.hilitedCandidateLabel : palette.label))
      Text(rows[index].1)
        .font(.system(size: fontSize, weight: .medium))
        .foregroundStyle(Color(hilited ? palette.hilitedCandidateText : palette.candidateText))
    }
    .padding(.horizontal, compact ? 5 : 6)
    .padding(.vertical, compact ? 1 : 2)
    .background(Color(hilited ? palette.hilitedCandidateBack : palette.candidateBack))
    .clipShape(RoundedRectangle(cornerRadius: max(2, cornerRadius * 0.45), style: .continuous))
  }
}
