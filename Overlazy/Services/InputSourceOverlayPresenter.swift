import AppKit
import ScrechKit

@MainActor
final class InputSourceOverlayPresenter {
    private var panel: NSPanel?
    private var dismissalTask: Task<Void, Never>?
    
    func show(_ inputSource: InputSource) {
        dismissalTask?.cancel()
        
        let overlayView = InputSourceOverlayView(inputSource: inputSource)
        let hostingView = NSHostingView(rootView: overlayView)
        hostingView.frame = NSRect(origin: .zero, size: hostingView.fittingSize)
        
        let panel = panel ?? makePanel()
        panel.contentView = hostingView
        panel.setFrame(frame(for: hostingView.fittingSize), display: true)
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        
        self.panel = panel
        
        dismissalTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            
            guard !Task.isCancelled else {
                return
            }
            
            self?.hide()
        }
    }
    
    private func hide() {
        panel?.orderOut(nil)
    }
    
    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.backgroundColor = .clear
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.isOpaque = false
        panel.level = .statusBar
        
        return panel
    }
    
    private func frame(for size: NSSize) -> NSRect {
        let screenFrame = currentScreen()?.visibleFrame ?? .zero
        let originX = screenFrame.midX - size.width / 2
        let originY = screenFrame.maxY - size.height - 24
        
        return NSRect(origin: NSPoint(x: originX, y: originY), size: size)
    }
    
    private func currentScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        
        return NSScreen.screens.first {
            $0.frame.contains(mouseLocation)
        } ?? NSScreen.main
    }
}
