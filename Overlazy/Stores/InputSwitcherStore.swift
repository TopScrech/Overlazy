import SwiftUI
import Carbon
import OSLog

@MainActor
@Observable
final class InputSwitcherStore {
    var inputSources: [InputSource] = []
    var selectedInputSource: InputSource?
    var keyboardShortcutStatus = KeyboardShortcutStatus.inactive
    var systemGlobeActionStatus = SystemGlobeActionStatus.unknown
    
    @ObservationIgnored private let globeKeySystemActionService = GlobeKeySystemActionService()
    @ObservationIgnored private let inputSourceService = InputSourceService()
    @ObservationIgnored private let keyboardInterceptor = KeyboardInterceptor()
    @ObservationIgnored private let logger = Logger(subsystem: "dev.topscrech.Overlazy", category: "InputSwitcher")
    @ObservationIgnored private let overlayPresenter = InputSourceOverlayPresenter()
    @ObservationIgnored private var inputSourceObserver: NSObjectProtocol?
    
    init() {
        configureSystemGlobeAction()
        refreshInputSources()
        configureKeyboardInterceptor()
        observeSystemInputSourceChanges()
    }
    
    deinit {
        if let inputSourceObserver {
            DistributedNotificationCenter.default().removeObserver(inputSourceObserver)
        }
    }
    
    func switchToNextInputSource() {
        refreshInputSources()
        
        guard let nextInputSource else {
            logger.info("No next input source found")
            return
        }
        
        logger.info("Switching input source to \(nextInputSource.name, privacy: .public)")
        select(nextInputSource)
    }
    
    func select(_ inputSource: InputSource) {
        guard inputSourceService.select(inputSource) else {
            refreshInputSources()
            return
        }
        
        selectedInputSource = inputSource
        overlayPresenter.show(inputSource)
    }
    
    func showSelectedInputSource() {
        refreshInputSources()
        
        guard let selectedInputSource else {
            return
        }
        
        overlayPresenter.show(selectedInputSource)
    }
    
    func requestKeyboardPermission() {
        keyboardShortcutStatus = keyboardInterceptor.requestPermissionAndStart()
    }
    
    func disableSystemGlobeAction() {
        systemGlobeActionStatus = globeKeySystemActionService.disableSystemAction()
        logger.info("System Globe action status \(self.systemGlobeActionStatusTitle, privacy: .public)")
    }
    
    func restoreSystemGlobeAction() {
        systemGlobeActionStatus = globeKeySystemActionService.restoreSystemAction()
        logger.info("System Globe action status \(self.systemGlobeActionStatusTitle, privacy: .public)")
    }
    
    func quit() {
        NSApplication.shared.terminate(nil)
    }
    
    var keyboardShortcutStatusTitle: String {
        switch keyboardShortcutStatus {
        case .inactive:
            "Shortcut inactive"
        case .intercepting:
            "Globe key active"
        case .needsPermission:
            "Keyboard permission needed"
        case .unavailable:
            "Shortcut unavailable"
        }
    }
    
    var systemGlobeActionStatusTitle: String {
        switch systemGlobeActionStatus {
        case .unknown:
            "System Globe UI unknown"
        case .disabled:
            "System Globe UI disabled"
        case .restored:
            "System Globe UI restored"
        case .failed:
            "System Globe UI failed"
        }
    }
    
    private var nextInputSource: InputSource? {
        guard !inputSources.isEmpty else {
            return nil
        }
        
        guard let selectedInputSource,
              let selectedIndex = inputSources.firstIndex(of: selectedInputSource) else {
            return inputSources.first
        }
        
        let nextIndex = inputSources.index(after: selectedIndex)
        return nextIndex == inputSources.endIndex ? inputSources.first : inputSources[nextIndex]
    }
    
    private func configureSystemGlobeAction() {
        systemGlobeActionStatus = globeKeySystemActionService.disableSystemAction()
        logger.info("System Globe action status \(self.systemGlobeActionStatusTitle, privacy: .public)")
    }
    
    private func configureKeyboardInterceptor() {
        keyboardInterceptor.onShortcut = { [weak self] in
            self?.switchToNextInputSource()
        }
        
        keyboardShortcutStatus = keyboardInterceptor.start()
        logger.info("Keyboard shortcut status \(self.keyboardShortcutStatusTitle, privacy: .public)")
    }
    
    private func observeSystemInputSourceChanges() {
        let notificationName = Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String)
        
        inputSourceObserver = DistributedNotificationCenter.default().addObserver(
            forName: notificationName,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshInputSources()
            }
        }
    }
    
    private func refreshInputSources() {
        inputSources = inputSourceService.selectableInputSources()
        selectedInputSource = inputSourceService.selectedInputSource()
    }
}
