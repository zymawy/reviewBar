import AppKit
import SwiftUI
import Combine
import ReviewBarCore

/// Controls the menu bar status item with custom icon rendering and badge support
@MainActor
final class StatusItemController: NSObject {
    
    // MARK: - Properties
    
    private let settingsStore: SettingsStore
    private let reviewStore: ReviewStore
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Icon State
    
    private var isAnimating = false
    private var animationTask: Task<Void, Never>?
    private var animationFrame = 0
    
    // MARK: - Init
    
    init(settingsStore: SettingsStore, reviewStore: ReviewStore) {
        self.settingsStore = settingsStore
        self.reviewStore = reviewStore
        super.init()
        
        setupStatusItem()
        observeChanges()
    }
    
    deinit {
        animationTask?.cancel()
    }
    
    // MARK: - Setup
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let button = statusItem?.button else { return }
        
        // Initial icon
        updateIcon()
        
        // Click action
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }
    
    // MARK: - Observation
    
    private func observeChanges() {
        // Observe review store changes using Combine
        reviewStore.$pendingReviews
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateIcon()
            }
            .store(in: &cancellables)
        
        reviewStore.$isReviewing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateIcon()
                self?.updateAnimation()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Icon Rendering
    
    private func updateIcon() {
        guard let button = statusItem?.button else { return }
        
        let pendingCount = reviewStore.pendingReviews.count
        let isReviewing = reviewStore.isReviewing
        
        // Create icon image
        let icon = renderIcon(
            pendingCount: pendingCount,
            isReviewing: isReviewing,
            animationFrame: animationFrame
        )
        
        button.image = icon
        button.image?.isTemplate = !isReviewing // Template for dark/light mode when not animating
        
        // Accessibility
        button.setAccessibilityLabel(getAccessibilityLabel(pendingCount: pendingCount, isReviewing: isReviewing))
    }
    
    private func renderIcon(pendingCount: Int, isReviewing: Bool, animationFrame: Int) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        
        let image = NSImage(size: size, flipped: false) { rect in
            let iconSize: CGFloat = 16
            let iconRect = NSRect(
                x: (rect.width - iconSize) / 2,
                y: (rect.height - iconSize) / 2,
                width: iconSize,
                height: iconSize
            )
            
            // Use shield symbol to match our branding (shield + code)
            let symbolName = isReviewing ? "shield.lefthalf.filled.badge.checkmark" : "shield.lefthalf.filled"
            
            if let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: "ReviewBar") {
                let config = NSImage.SymbolConfiguration(pointSize: iconSize, weight: .regular)
                let configured = symbol.withSymbolConfiguration(config)
                
                if isReviewing {
                    // Pulse opacity for loading effect
                    let opacity = 0.5 + 0.5 * sin(Double(animationFrame) * 0.5)
                    configured?.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: opacity)
                } else {
                    configured?.draw(in: iconRect)
                }
            }
            
            // Badge for pending count
            if pendingCount > 0 && !isReviewing {
                self.drawBadge(count: pendingCount, in: rect)
            }
            
            return true
        }
        
        image.isTemplate = true
        return image
    }
    
    // Removed old manual drawing methods drawStaticIcon and drawLoadingIcon
    
    private func drawBadge(count: Int, in rect: NSRect) {
        let badgeSize: CGFloat = 10
        let badgeRect = NSRect(
            x: rect.maxX - badgeSize + 2,
            y: rect.maxY - badgeSize + 2,
            width: badgeSize,
            height: badgeSize
        )
        
        // Red circle
        let badgePath = NSBezierPath(ovalIn: badgeRect)
        NSColor.systemRed.setFill()
        badgePath.fill()
        
        // Count text
        let text = count > 9 ? "9+" : "\(count)"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 7, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        
        let textSize = text.size(withAttributes: attributes)
        let textPoint = NSPoint(
            x: badgeRect.midX - textSize.width / 2,
            y: badgeRect.midY - textSize.height / 2
        )
        
        text.draw(at: textPoint, withAttributes: attributes)
    }
    
    private func getAccessibilityLabel(pendingCount: Int, isReviewing: Bool) -> String {
        if isReviewing {
            return "ReviewBar: Reviewing..."
        } else if pendingCount == 0 {
            return "ReviewBar: No pending reviews"
        } else {
            return "ReviewBar: \(pendingCount) pending review\(pendingCount == 1 ? "" : "s")"
        }
    }
    
    // MARK: - Animation
    
    private func updateAnimation() {
        let shouldAnimate = reviewStore.isReviewing
        
        if shouldAnimate && !isAnimating {
            startAnimation()
        } else if !shouldAnimate && isAnimating {
            stopAnimation()
        }
    }
    
    private func startAnimation() {
        isAnimating = true
        animationFrame = 0
        
        animationTask?.cancel()
        animationTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                guard !Task.isCancelled else { return }
                
                self.animationFrame = (self.animationFrame + 1) % 12
                self.updateIcon()
            }
        }
    }
    
    private func stopAnimation() {
        isAnimating = false
        animationTask?.cancel()
        animationTask = nil
        animationFrame = 0
        updateIcon()
    }
    
    // MARK: - Actions
    
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            // Right click - show context menu
            showContextMenu()
        } else {
            // Left click - handled by MenuBarExtra in SwiftUI
        }
    }
    
    private func showContextMenu() {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit ReviewBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        for item in menu.items {
            item.target = self
        }
        
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }
    
    @objc private func refreshNow() {
        Task {
            await reviewStore.refresh()
        }
    }
    
    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
