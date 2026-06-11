import LaunchAtLogin
import ScrechKit

struct MenuBarContentView: View {
    let inputSwitcherStore: InputSwitcherStore
    
    var body: some View {
        Button("Switch Language", systemImage: "globe", action: inputSwitcherStore.switchToNextInputSource)
        
        Button("Show Overlay", systemImage: "rectangle.on.rectangle", action: inputSwitcherStore.showSelectedInputSource)
        
        Divider()
        
        Label(inputSwitcherStore.keyboardShortcutStatusTitle, systemImage: shortcutStatusImage)
        
        Label(inputSwitcherStore.systemGlobeActionStatusTitle, systemImage: systemGlobeActionStatusImage)
        
        if inputSwitcherStore.keyboardShortcutStatus != .intercepting {
            Button("Request Permission", systemImage: "hand.raised", action: inputSwitcherStore.requestKeyboardPermission)
        }
        
        if inputSwitcherStore.systemGlobeActionStatus != .disabled {
            Button("Disable System Globe UI", systemImage: "eye.slash", action: inputSwitcherStore.disableSystemGlobeAction)
        }
        
        Button("Restore System Globe Action", systemImage: "arrow.uturn.backward", action: inputSwitcherStore.restoreSystemGlobeAction)
        
        Divider()
        
        ForEach(inputSwitcherStore.inputSources) { inputSource in
            MenuBarInputSourceButtonView(
                inputSource: inputSource,
                isSelected: isSelected(inputSource)
            ) {
                inputSwitcherStore.select(inputSource)
            }
        }
        
        Divider()
        
        LaunchAtLogin.Toggle()
        
        Divider()
        
        Button("Quit", systemImage: "power", action: inputSwitcherStore.quit)
    }
    
    private var shortcutStatusImage: String {
        switch inputSwitcherStore.keyboardShortcutStatus {
        case .inactive:
            "keyboard"
        case .intercepting:
            "keyboard.badge.checkmark"
        case .needsPermission:
            "keyboard.badge.eye"
        case .unavailable:
            "keyboard.badge.exclamationmark"
        }
    }
    
    private var systemGlobeActionStatusImage: String {
        switch inputSwitcherStore.systemGlobeActionStatus {
        case .unknown:
            "globe"
        case .disabled:
            "eye.slash"
        case .restored:
            "globe"
        case .failed:
            "exclamationmark.triangle"
        }
    }
    
    private func isSelected(_ inputSource: InputSource) -> Bool {
        inputSource.id == inputSwitcherStore.selectedInputSource?.id
    }
}
