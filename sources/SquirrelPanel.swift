//
//  SquirrelPanel.swift
//  Squirrel
//
//  Created by Leo Liu on 5/10/24.
//

import AppKit

/// Clicks, scrolling, and caret hits in the candidate panel.
/// The input controller and the settings try-typing field both drive these.
protocol SquirrelPanelInput: AnyObject {
  func selectCandidate(_ index: Int) -> Bool
  func page(up: Bool) -> Bool
  func moveCaret(forward: Bool) -> Bool
}

@objc(ParetlyCandidatePanel)
final class SquirrelPanel: NSPanel {
  private let view: SquirrelView
  private let back: NSVisualEffectView
  var inputController: SquirrelPanelInput?

  var position: NSRect
  private var screenRect: NSRect = .zero
  private var maxHeight: CGFloat = 0

  private var statusMessage: String = ""
  private var statusTimer: Timer?

  private var preedit: String = ""
  private var selRange: NSRange = .empty
  private var caretPos: Int = 0
  private var candidates: [String] = .init()
  private var comments: [String] = .init()
  private var labels: [String] = .init()
  private var index: Int = 0
  private var cursorIndex: Int = 0
  private var scrollDirection: CGVector = .zero
  private var scrollTime: Date = .distantPast
  private var page: Int = 0
  private var lastPage: Bool = true
  private var pagingUp: Bool?
  /// Set while the settings try-field parents this panel so it stays above
  /// that window. Cleared before the panel is used for any other client.
  private var aboveParent = false
  private var savedBehavior: NSWindow.CollectionBehavior?
  /// Settings window the try-field last attached. Ordering the panel front
  /// can drop `parent` while that field is still the client.
  private weak var anchorWindow: NSWindow?

  init(position: NSRect) {
    self.position = position
    self.view = SquirrelView(frame: position)
    self.back = NSVisualEffectView()
    super.init(contentRect: position, styleMask: .nonactivatingPanel, backing: .buffered, defer: true)
    self.becomesKeyOnlyIfNeeded = true
    // The window shadow is a rectangle around the rounded bubble, in other
    // apps as well as over Settings. The bubble is the theme shape only.
    self.hasShadow = false
    self.isOpaque = false
    self.backgroundColor = .clear
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask = [.borderless, .nonactivatingPanel]
    back.blendingMode = .behindWindow
    back.material = .hudWindow
    // Hidden until a theme asks for translucency. A visible HUD plate is a
    // rectangle behind the rounded bubble, and a layer mask does not clip it.
    back.state = .inactive
    back.isHidden = true
    back.alphaValue = 0
    back.wantsLayer = true
    let contentView = NSView()
    contentView.wantsLayer = true
    contentView.layer?.isOpaque = false
    contentView.layer?.backgroundColor = NSColor.clear.cgColor
    contentView.addSubview(back)
    contentView.addSubview(view)
    contentView.addSubview(view.textView)
    self.contentView = contentView
    prepareClearWindow()
    // Nonactivating panels start with hidesOnDeactivate == false. Keep it
    // that way, and join every Space: this panel is shown while another app is key.
    placeForCurrentClient()
  }

  var linear: Bool {
    view.currentTheme.linear
  }
  var vertical: Bool {
    view.currentTheme.vertical
  }
  var inlinePreedit: Bool {
    view.currentTheme.inlinePreedit
  }
  var inlineCandidate: Bool {
    view.currentTheme.inlineCandidate
  }

  // swiftlint:disable:next cyclomatic_complexity
  override func sendEvent(_ event: NSEvent) {
    switch event.type {
    case .leftMouseDown:
      let (index, _, pagingUp) =  view.click(at: mousePosition())
      if let pagingUp {
        self.pagingUp = pagingUp
      } else {
        self.pagingUp = nil
      }
      if let index, index >= 0 && index < candidates.count {
        self.index = index
      }
    case .leftMouseUp:
      let (index, preeditIndex, pagingUp) = view.click(at: mousePosition())

      if let pagingUp, pagingUp == self.pagingUp {
        _ = inputController?.page(up: pagingUp)
      } else {
        self.pagingUp = nil
      }
      if let preeditIndex, preeditIndex >= 0 && preeditIndex < preedit.utf16.count {
        if preeditIndex < caretPos {
          _ = inputController?.moveCaret(forward: true)
        } else if preeditIndex > caretPos {
          _ = inputController?.moveCaret(forward: false)
        }
      }
      if let index, index == self.index && index >= 0 && index < candidates.count {
        _ = inputController?.selectCandidate(index)
      }
    case .mouseEntered:
      acceptsMouseMovedEvents = true
    case .mouseExited:
      acceptsMouseMovedEvents = false
      if cursorIndex != index {
        update(preedit: preedit, selRange: selRange, caretPos: caretPos, candidates: candidates, comments: comments, labels: labels, highlighted: index, page: page, lastPage: lastPage, update: false)
      }
      pagingUp = nil
    case .mouseMoved:
      let (index, _, _) = view.click(at: mousePosition())
      if let index = index, cursorIndex != index && index >= 0 && index < candidates.count {
        update(preedit: preedit, selRange: selRange, caretPos: caretPos, candidates: candidates, comments: comments, labels: labels, highlighted: index, page: page, lastPage: lastPage, update: false)
      }
    case .scrollWheel:
      if event.phase == .began {
        scrollDirection = .zero
        // Scrollboard span
      } else if event.phase == .ended || (event.phase == .init(rawValue: 0) && event.momentumPhase != .init(rawValue: 0)) {
        if abs(scrollDirection.dx) > abs(scrollDirection.dy) && abs(scrollDirection.dx) > 10 {
          _ = inputController?.page(up: (scrollDirection.dx < 0) == vertical)
        } else if abs(scrollDirection.dx) < abs(scrollDirection.dy) && abs(scrollDirection.dy) > 10 {
          _ = inputController?.page(up: scrollDirection.dy > 0)
        }
        scrollDirection = .zero
        // Mouse scroll wheel
      } else if event.phase == .init(rawValue: 0) && event.momentumPhase == .init(rawValue: 0) {
        if scrollTime.timeIntervalSinceNow < -1 {
          scrollDirection = .zero
        }
        scrollTime = .now
        if (scrollDirection.dy >= 0 && event.scrollingDeltaY > 0) || (scrollDirection.dy <= 0 && event.scrollingDeltaY < 0) {
          scrollDirection.dy += event.scrollingDeltaY
        } else {
          scrollDirection = .zero
        }
        if abs(scrollDirection.dy) > 10 {
          _ = inputController?.page(up: scrollDirection.dy > 0)
          scrollDirection = .zero
        }
      } else {
        scrollDirection.dx += event.scrollingDeltaX
        scrollDirection.dy += event.scrollingDeltaY
      }
    default:
      break
    }
    super.sendEvent(event)
  }

  func hide() {
    statusTimer?.invalidate()
    statusTimer = nil
    releaseAnchor()
    orderOut(nil)
    maxHeight = 0
  }

  /// Keep the candidate panel above the settings window.
  ///
  /// The panel is created while this process is an agent, at the shielding
  /// level. After `TransformProcessType` makes Paretly a foreground app,
  /// `orderFront` does not raise that panel over the settings key window
  /// (the shielding level is not honored for this process's own windows).
  /// Parenting it is what keeps it above that window. A child cannot use a
  /// level above its parent, so the anchored panel uses the parent's level.
  /// `hidesOnDeactivate` stays false: an activation flicker while Settings
  /// opens would otherwise hide candidates before they are drawn.
  func anchorAbove(_ window: NSWindow) {
    remainVisibleWhenInactive()
    if savedBehavior == nil {
      savedBehavior = collectionBehavior
    }
    var behavior = collectionBehavior
    behavior.formUnion(Self.externalCollectionBehavior)
    behavior.remove(.moveToActiveSpace)
    collectionBehavior = behavior
    aboveParent = true
    anchorWindow = window
    // Always detach first. Deploy orders this panel out while it is still a
    // child of Settings; addChildWindow ignores a window that is already
    // attached, so the bubble stays behind the key window.
    if parent != nil {
      parent?.removeChildWindow(self)
    }
    prepareClearWindow()
    // A child cannot use a level above its parent.
    hasShadow = false
    level = window.level
    window.addChildWindow(self, ordered: .above)
    level = window.level
    remainVisibleWhenInactive()
    prepareClearWindow()
  }

  /// Drop the settings-window parent so the next client gets the normal panel.
  ///
  /// Callers include both `hide()` and the external `showPanel` path, so this
  /// must not arm `hidesOnDeactivate`. That flag makes WindowServer omit the
  /// panel from the onscreen list whenever `NSApp` is inactive — which is
  /// the whole time the user is typing in another app. The window keeps a
  /// frame, but `kCGWindowIsOnscreen` is false.
  func releaseAnchor() {
    aboveParent = false
    anchorWindow = nil
    if let savedBehavior {
      collectionBehavior = savedBehavior
      self.savedBehavior = nil
    }
    if let parent {
      parent.removeChildWindow(self)
    }
    clearLayerShadow()
    hasShadow = false
    prepareClearWindow()
    placeForCurrentClient()
  }

  // Main function to add attributes to text output from librime
  // swiftlint:disable:next cyclomatic_complexity function_parameter_count
  func update(preedit: String, selRange: NSRange, caretPos: Int, candidates: [String], comments: [String], labels: [String], highlighted index: Int, page: Int, lastPage: Bool, update: Bool) {
    if update {
      self.preedit = preedit
      self.selRange = selRange
      self.caretPos = caretPos
      self.candidates = candidates
      self.comments = comments
      self.labels = labels
      self.index = index
      self.page = page
      self.lastPage = lastPage
    }
    cursorIndex = index

    if !candidates.isEmpty || !preedit.isEmpty {
      statusMessage = ""
      statusTimer?.invalidate()
      statusTimer = nil
    } else {
      if !statusMessage.isEmpty {
        show(status: statusMessage)
        statusMessage = ""
      } else if statusTimer == nil {
        hide()
      }
      return
    }

    let theme = view.currentTheme
    currentScreen()

    let text = NSMutableAttributedString()
    let preeditRange: NSRange
    let highlightedPreeditRange: NSRange

    // preedit
    if !preedit.isEmpty {
      preeditRange = NSRange(location: 0, length: preedit.utf16.count)
      highlightedPreeditRange = selRange

      let line = NSMutableAttributedString(string: preedit)
      line.addAttributes(theme.preeditAttrs, range: preeditRange)
      line.addAttributes(theme.preeditHighlightedAttrs, range: selRange)
      text.append(line)

      text.addAttribute(.paragraphStyle, value: theme.preeditParagraphStyle, range: NSRange(location: 0, length: text.length))
      if !candidates.isEmpty {
        text.append(NSAttributedString(string: "\n", attributes: theme.preeditAttrs))
      }
    } else {
      preeditRange = .empty
      highlightedPreeditRange = .empty
    }

    // candidates
    var candidateRanges = [NSRange]()
    for i in 0..<candidates.count {
      let attrs = i == index ? theme.highlightedAttrs : theme.attrs
      let labelAttrs = i == index ? theme.labelHighlightedAttrs : theme.labelAttrs
      let commentAttrs = i == index ? theme.commentHighlightedAttrs : theme.commentAttrs

      let label = if theme.candidateFormat.contains(/\[label\]/) {
        if labels.count > 1 && i < labels.count {
          labels[i]
        } else if labels.count == 1 && i < labels.first!.count {
          // custom: A. B. C...
          String(labels.first![labels.first!.index(labels.first!.startIndex, offsetBy: i)])
        } else {
          // default: 1. 2. 3...
          "\(i+1)"
        }
      } else {
        ""
      }

      let candidate = candidates[i].precomposedStringWithCanonicalMapping
      let comment = comments[i].precomposedStringWithCanonicalMapping

      let line = NSMutableAttributedString(string: theme.candidateFormat, attributes: labelAttrs)
      for range in line.string.ranges(of: /\[candidate\]/) {
        let convertedRange = convert(range: range, in: line.string)
        line.addAttributes(attrs, range: convertedRange)
        if candidate.count <= 5 {
          line.addAttribute(.noBreak, value: true, range: NSRange(location: convertedRange.location+1, length: convertedRange.length-1))
        }
      }
      for range in line.string.ranges(of: /\[comment\]/) {
        line.addAttributes(commentAttrs, range: convert(range: range, in: line.string))
      }
      line.mutableString.replaceOccurrences(of: "[label]", with: label, range: NSRange(location: 0, length: line.length))
      let labeledLine = line.copy() as! NSAttributedString
      line.mutableString.replaceOccurrences(of: "[candidate]", with: candidate, range: NSRange(location: 0, length: line.length))
      line.mutableString.replaceOccurrences(of: "[comment]", with: comment, range: NSRange(location: 0, length: line.length))

      if line.length <= 10 {
        line.addAttribute(.noBreak, value: true, range: NSRange(location: 1, length: line.length-1))
      }

      let lineSeparator = NSAttributedString(string: linear ? "  " : "\n", attributes: attrs)
      if i > 0 {
        text.append(lineSeparator)
      }
      let str = lineSeparator.mutableCopy() as! NSMutableAttributedString
      if vertical {
        str.addAttribute(.verticalGlyphForm, value: 1, range: NSRange(location: 0, length: str.length))
      }
      view.separatorWidth = str.boundingRect(with: .zero).width

      let paragraphStyleCandidate = (i == 0 ? theme.firstParagraphStyle : theme.paragraphStyle).mutableCopy() as! NSMutableParagraphStyle
      if linear {
        paragraphStyleCandidate.paragraphSpacingBefore -= theme.linespace
        paragraphStyleCandidate.lineSpacing = theme.linespace
      }
      if !linear, let labelEnd = labeledLine.string.firstMatch(of: /\[(candidate|comment)\]/)?.range.lowerBound {
        let labelString = labeledLine.attributedSubstring(from: NSRange(location: 0, length: labelEnd.utf16Offset(in: labeledLine.string)))
        let labelWidth = labelString.boundingRect(with: .zero, options: [.usesLineFragmentOrigin]).width
        paragraphStyleCandidate.headIndent = labelWidth
      }
      line.addAttribute(.paragraphStyle, value: paragraphStyleCandidate, range: NSRange(location: 0, length: line.length))

      candidateRanges.append(NSRange(location: text.length, length: line.length))
      text.append(line)
    }

    // text done!
    view.textView.textContentStorage?.attributedString = text
    view.textView.setLayoutOrientation(vertical ? .vertical : .horizontal)
    view.drawView(candidateRanges: candidateRanges, hilightedIndex: index, preeditRange: preeditRange, highlightedPreeditRange: highlightedPreeditRange, canPageUp: page > 0, canPageDown: !lastPage)
    show()
  }

  func updateStatus(long longMessage: String, short shortMessage: String) {
    let theme = view.currentTheme
    switch theme.statusMessageType {
    case .mix:
      statusMessage = shortMessage.isEmpty ? longMessage : shortMessage
    case .long:
      statusMessage = longMessage
    case .short:
      if !shortMessage.isEmpty {
        statusMessage = shortMessage
      } else if let initial = longMessage.first {
        statusMessage = String(initial)
      } else {
        statusMessage = ""
      }
    }
  }

  func load(config: SquirrelThemeConfig, forDarkMode isDark: Bool) {
    if isDark {
      view.darkTheme = SquirrelTheme()
      view.darkTheme.load(config: config, dark: true)
    } else {
      view.lightTheme = SquirrelTheme()
      view.lightTheme.load(config: config, dark: isDark)
    }
  }

}

extension SquirrelPanel {
  func show(status message: String) {
    let theme = view.currentTheme
    let text = NSMutableAttributedString(string: message, attributes: theme.attrs)
    text.addAttribute(.paragraphStyle, value: theme.paragraphStyle, range: NSRange(location: 0, length: text.length))
    view.textContentStorage.attributedString = text
    view.textView.setLayoutOrientation(vertical ? .vertical : .horizontal)
    view.drawView(candidateRanges: [NSRange(location: 0, length: text.length)], hilightedIndex: -1,
                  preeditRange: .empty, highlightedPreeditRange: .empty, canPageUp: false, canPageDown: false)
    show()

    statusTimer?.invalidate()
    statusTimer = Timer.scheduledTimer(withTimeInterval: SquirrelTheme.showStatusDuration, repeats: false) { _ in
      self.hide()
    }
  }

  /// Attach this panel above the settings window again after a deploy.
  ///
  /// Redeploy finalizes librime and reloads the theme. Either one can order
  /// the panel out while it is still a child of Settings. External apps call
  /// `releaseAnchor()` first, which is why their candidates keep working.
  /// The try-field must not take that path: a detached panel at the shielding
  /// level stays behind this process's own key window.
  func reclaimForTryField(above window: NSWindow) {
    anchorAbove(window)
  }
}

private extension SquirrelPanel {
  /// Visible on every Space, including beside a fullscreen app.
  /// `moveToActiveSpace` only runs when a window becomes key. This panel is
  /// nonactivating, so that flag would leave it on the Space where Paretly
  /// was last active (often the settings window) instead of the app being typed in.
  static let externalCollectionBehavior: NSWindow.CollectionBehavior = [
    .canJoinAllSpaces, .fullScreenAuxiliary
  ]

  func remainVisibleWhenInactive() {
    // isFloatingPanel == true forces hidesOnDeactivate back on.
    isFloatingPanel = false
    hidesOnDeactivate = false
  }

  func prepareClearWindow() {
    isOpaque = false
    backgroundColor = .clear
    hasShadow = false
    titlebarAppearsTransparent = true
    titleVisibility = .hidden
    if styleMask.contains(.titled) || styleMask.contains(.utilityWindow) || styleMask.contains(.hudWindow) {
      styleMask = [.borderless, .nonactivatingPanel]
    }
    guard let content = contentView else { return }
    content.wantsLayer = true
    content.layer?.isOpaque = false
    content.layer?.backgroundColor = NSColor.clear.cgColor
    content.layer?.masksToBounds = false
    content.layer?.borderWidth = 0
    content.layer?.shadowOpacity = 0
    view.layer?.isOpaque = false
    view.layer?.backgroundColor = NSColor.clear.cgColor
    view.textView.drawsBackground = false
    view.textView.backgroundColor = .clear
    view.textView.wantsLayer = true
    view.textView.layer?.isOpaque = false
    view.textView.layer?.backgroundColor = NSColor.clear.cgColor
    if let frame = content.superview {
      frame.wantsLayer = true
      frame.layer?.isOpaque = false
      frame.layer?.backgroundColor = NSColor.clear.cgColor
      frame.layer?.borderWidth = 0
      frame.layer?.shadowOpacity = 0
    }
  }

  func clearLayerShadow() {
    contentView?.layer?.shadowOpacity = 0
    contentView?.layer?.shadowPath = nil
  }

  /// Clip every subview to the theme's rounded shape and drop the window
  /// shadow. A rectangular shadow, HUD plate, or text-view fill shows up as
  /// a square frame in Settings and in other apps.
  func applyRoundedChrome() {
    prepareClearWindow()
    clearLayerShadow()
    hasShadow = false
    // Changing styleMask can turn hidesOnDeactivate back on.
    remainVisibleWhenInactive()
    let path = view.shape.path
    guard let path, !path.isEmpty, let content = contentView else { return }
    let contentMask = (content.layer?.mask as? CAShapeLayer) ?? CAShapeLayer()
    contentMask.path = path
    contentMask.fillColor = NSColor.black.cgColor
    content.wantsLayer = true
    if content.layer?.mask !== contentMask {
      content.layer?.mask = contentMask
    }
    let plateMask = (back.layer?.mask as? CAShapeLayer) ?? CAShapeLayer()
    plateMask.path = path
    plateMask.fillColor = NSColor.black.cgColor
    back.wantsLayer = true
    if back.layer?.mask !== plateMask {
      back.layer?.mask = plateMask
    }
  }

  func presentAbove(_ window: NSWindow) {
    if parent != nil {
      parent?.removeChildWindow(self)
    }
    prepareClearWindow()
    hasShadow = false
    level = window.level
    remainVisibleWhenInactive()
    orderFrontRegardless()
    window.addChildWindow(self, ordered: .above)
    level = window.level
    remainVisibleWhenInactive()
    prepareClearWindow()
    hasShadow = false
  }

  /// Shielding level for other apps. While parented to Settings, the level
  /// matches that window: a child cannot sit above its parent. Either way
  /// the panel joins fullscreen Spaces and does not hide on deactivate.
  func placeForCurrentClient() {
    remainVisibleWhenInactive()
    var behavior = collectionBehavior
    behavior.formUnion(Self.externalCollectionBehavior)
    behavior.remove(.moveToActiveSpace)
    if behavior != collectionBehavior {
      collectionBehavior = behavior
    }
    let shielding = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
    let target = aboveParent ? (parent?.level ?? .normal) : shielding
    if level != target {
      level = target
    }
  }

  func mousePosition() -> NSPoint {
    var point = NSEvent.mouseLocation
    point = self.convertPoint(fromScreen: point)
    return view.convert(point, from: nil)
  }

  func currentScreen() {
    if let screen = NSScreen.main {
      screenRect = screen.frame
    }
    for screen in NSScreen.screens where screen.frame.contains(position.origin) {
      screenRect = screen.frame
      break
    }
  }

  func maxTextWidth() -> CGFloat {
    let theme = view.currentTheme
    let font: NSFont = theme.font
    let fontScale = font.pointSize / 12
    let textWidthRatio = min(1, 1 / (vertical ? 4 : 3) + fontScale / 12)
    let maxWidth = if vertical {
      screenRect.height * textWidthRatio - theme.edgeInset.height * 2
    } else {
      screenRect.width * textWidthRatio - theme.edgeInset.width * 2
    }
    return maxWidth
  }

  // Get the window size, the windows will be the dirtyRect in
  // SquirrelView.drawRect
  // swiftlint:disable:next cyclomatic_complexity
  func show() {
    currentScreen()
    let theme = view.currentTheme
    if theme.native || view.darkTheme.available {
      self.appearance = NSApp.effectiveAppearance
    } else {
      // user configured only a light theme, set window appearance to light.
      self.appearance = NSAppearance(named: .aqua)
    }

    // Break line if the text is too long, based on screen size.
    let textWidth = maxTextWidth()
    let maxTextHeight = vertical ? screenRect.width - theme.edgeInset.width * 2 : screenRect.height - theme.edgeInset.height * 2
    view.textContainer.size = NSSize(width: textWidth, height: maxTextHeight)

    var panelRect = NSRect.zero
    // in vertical mode, the width and height are interchanged
    var contentRect = view.contentRect
    if theme.memorizeSize && (vertical && position.midY / screenRect.height < 0.5) ||
        (vertical && position.minX + max(contentRect.width, maxHeight) + theme.edgeInset.width * 2 > screenRect.maxX) {
      if contentRect.width >= maxHeight {
        maxHeight = contentRect.width
      } else {
        contentRect.size.width = maxHeight
        view.textContainer.size = NSSize(width: maxHeight, height: maxTextHeight)
      }
    }

    if vertical {
      panelRect.size = NSSize(width: min(0.95 * screenRect.width, contentRect.height + theme.edgeInset.height * 2),
                              height: min(0.95 * screenRect.height, contentRect.width + theme.edgeInset.width * 2) + theme.pagingOffset)

      // To avoid jumping up and down while typing, use the lower screen when
      // typing on upper, and vice versa
      if position.midY / screenRect.height >= 0.5 {
        panelRect.origin.y = position.minY - SquirrelTheme.offsetHeight - panelRect.height + theme.pagingOffset
      } else {
        panelRect.origin.y = position.maxY + SquirrelTheme.offsetHeight
      }
      // Make the first candidate fixed at the left of cursor
      panelRect.origin.x = position.minX - panelRect.width - SquirrelTheme.offsetHeight
      if view.preeditRange.length > 0, let preeditTextRange = view.convert(range: view.preeditRange) {
        let preeditRect = view.contentRect(range: preeditTextRange)
        panelRect.origin.x += preeditRect.height + theme.edgeInset.width
      }
    } else {
      panelRect.size = NSSize(width: min(0.95 * screenRect.width, contentRect.width + theme.edgeInset.width * 2),
                              height: min(0.95 * screenRect.height, contentRect.height + theme.edgeInset.height * 2))
      panelRect.size.width += theme.pagingOffset
      panelRect.origin = NSPoint(x: position.minX - theme.pagingOffset, y: position.minY - SquirrelTheme.offsetHeight - panelRect.height)
    }
    if panelRect.maxX > screenRect.maxX {
      panelRect.origin.x = screenRect.maxX - panelRect.width
    }
    if panelRect.minX < screenRect.minX {
      panelRect.origin.x = screenRect.minX
    }
    if panelRect.minY < screenRect.minY {
      if vertical {
        panelRect.origin.y = screenRect.minY
      } else {
        panelRect.origin.y = position.maxY + SquirrelTheme.offsetHeight
      }
    }
    if panelRect.maxY > screenRect.maxY {
      panelRect.origin.y = screenRect.maxY - panelRect.height
    }
    if panelRect.minY < screenRect.minY {
      panelRect.origin.y = screenRect.minY
    }
    self.setFrame(panelRect, display: true)

    // rotate the view, the core in vertical mode!
    if vertical {
      contentView!.boundsRotation = -90
      contentView!.setBoundsOrigin(NSPoint(x: 0, y: panelRect.width))
    } else {
      contentView!.boundsRotation = 0
      contentView!.setBoundsOrigin(.zero)
    }
    view.textView.boundsRotation = 0
    view.textView.setBoundsOrigin(.zero)

    view.frame = contentView!.bounds
    view.textView.frame = contentView!.bounds
    view.textView.frame.size.width -= theme.pagingOffset
    view.textView.frame.origin.x += theme.pagingOffset
    view.textView.textContainerInset = theme.edgeInset

    if theme.translucency {
      if back.superview == nil {
        contentView!.addSubview(back, positioned: .below, relativeTo: view)
      }
      back.frame = contentView!.bounds
      back.frame.size.width += theme.pagingOffset
      back.appearance = NSApp.effectiveAppearance
      back.alphaValue = 1
      back.state = .active
      back.isHidden = false
    } else {
      // Hiding the HUD view still leaves its rectangular plate in the
      // window. Take it out of the hierarchy unless the theme asked for it.
      back.isHidden = true
      back.alphaValue = 0
      back.state = .inactive
      back.removeFromSuperview()
    }
    alphaValue = theme.alpha
    // orderFront is a no-op for this panel once the process is foreground:
    // the key window stays above it. orderFrontRegardless shows it whether
    // or not the input method itself is the active app. hidesOnDeactivate
    // has to be false first, or WindowServer still leaves the panel offscreen
    // while another app is key — including after Settings demotes this
    // process back to a UI element.
    if aboveParent, let window = anchorWindow ?? parent {
      // Order while detached, then parent. orderFrontRegardless on a child
      // that deploy ordered out does not raise it over the key window, and
      // it can also clear the child link.
      presentAbove(window)
    } else {
      placeForCurrentClient()
      orderFrontRegardless()
      // Ordering front can clear the level. Put the shielding level back,
      // and keep hidesOnDeactivate off after the order.
      placeForCurrentClient()
    }
    // The shape path clips the vibrancy plate and, while parented to
    // Settings, is the shadow. Draw after the frames and the order are final.
    contentView?.layoutSubtreeIfNeeded()
    view.needsDisplay = true
    view.displayIfNeeded()
    if view.shape.path?.isEmpty != false, view.bounds.width > 1, view.bounds.height > 1 {
      view.draw(view.bounds)
    }
    applyRoundedChrome()
  }

  func convert(range: Range<String.Index>, in string: String) -> NSRange {
    let startPos = range.lowerBound.utf16Offset(in: string)
    let endPos = range.upperBound.utf16Offset(in: string)
    return NSRange(location: startPos, length: endPos - startPos)
  }
}
