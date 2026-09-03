import ApplicationServices
import Carbon
import Foundation

final class KeyboardInterceptor: @unchecked Sendable {
    var onShortcut: (@MainActor () -> Void)?
    
    nonisolated private static let maximumGlobeTapDuration: CGEventTimestamp = 400_000_000
    
    nonisolated(unsafe) private var eventTap: CFMachPort?
    nonisolated(unsafe) private var runLoopSource: CFRunLoopSource?
    nonisolated(unsafe) private var functionKeyPressedAt: CGEventTimestamp?
    nonisolated(unsafe) private var didUseFunctionKeyAsModifier = false
    nonisolated(unsafe) private var shouldSuppressSpaceKeyUp = false
    
    func start() -> KeyboardShortcutStatus {
        stop()
        
        guard installEventTap() else {
            return .needsPermission
        }
        
        return .intercepting
    }
    
    func requestPermissionAndStart() -> KeyboardShortcutStatus {
        _ = CGRequestListenEventAccess()
        
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        
        _ = AXIsProcessTrustedWithOptions(options)
        
        return start()
    }
    
    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        
        eventTap = nil
        runLoopSource = nil
    }
    
    deinit {
        stop()
    }
    
    private func installEventTap() -> Bool {
        let eventMask = CGEventMask(
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)
        )
        
        guard let eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: keyboardEventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }
        
        guard let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0) else {
            return false
        }
        
        self.eventTap = eventTap
        self.runLoopSource = runLoopSource
        
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        return true
    }
    
    fileprivate nonisolated func handleEventTap(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            
            return Unmanaged.passUnretained(event)
        }
        
        if type == .flagsChanged, isFunctionKey(event) {
            return handleFunctionKeyFlagsChanged(event)
        }
        
        if type == .keyDown, isFunctionKey(event) {
            if !isRepeat(event) {
                beginFunctionKeyPress(at: event.timestamp)
            }
            
            return nil
        }
        
        if type == .keyUp, isFunctionKey(event) {
            endFunctionKeyPress(at: event.timestamp)
            return nil
        }
        
        if type == .keyDown, functionKeyPressedAt != nil {
            didUseFunctionKeyAsModifier = true
        }
        
        if type == .keyDown, isControlSpace(event), !isRepeat(event) {
            shouldSuppressSpaceKeyUp = true
            triggerShortcut()
            return nil
        }
        
        if type == .keyUp, shouldSuppressSpaceKeyUp, isSpace(event) {
            shouldSuppressSpaceKeyUp = false
            return nil
        }
        
        return Unmanaged.passUnretained(event)
    }
    
    private nonisolated func handleFunctionKeyFlagsChanged(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let isPressed = event.flags.contains(.maskSecondaryFn)
        
        if isPressed {
            beginFunctionKeyPress(at: event.timestamp)
        } else {
            endFunctionKeyPress(at: event.timestamp)
        }
        
        return nil
    }
    
    private nonisolated func beginFunctionKeyPress(at timestamp: CGEventTimestamp) {
        guard functionKeyPressedAt == nil else {
            return
        }
        
        functionKeyPressedAt = timestamp
        didUseFunctionKeyAsModifier = false
    }
    
    private nonisolated func endFunctionKeyPress(at timestamp: CGEventTimestamp) {
        guard let functionKeyPressedAt else {
            return
        }
        
        defer {
            self.functionKeyPressedAt = nil
            didUseFunctionKeyAsModifier = false
        }
        
        guard !didUseFunctionKeyAsModifier,
              timestamp >= functionKeyPressedAt,
              timestamp - functionKeyPressedAt <= Self.maximumGlobeTapDuration else {
            return
        }
        
        triggerShortcut()
    }
    
    private nonisolated func triggerShortcut() {
        Task { @MainActor [weak self] in
            self?.onShortcut?()
        }
    }
    
    private nonisolated func isControlSpace(_ event: CGEvent) -> Bool {
        guard isSpace(event) else {
            return false
        }
        
        let flags = event.flags
        let disallowedModifiers: CGEventFlags = [.maskCommand, .maskAlternate, .maskShift]
        
        return flags.contains(.maskControl) && flags.intersection(disallowedModifiers).isEmpty
    }
    
    private nonisolated func isSpace(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.keyboardEventKeycode) == Int64(kVK_Space)
    }
    
    private nonisolated func isFunctionKey(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.keyboardEventKeycode) == Int64(kVK_Function)
    }
    
    private nonisolated func isRepeat(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.keyboardEventAutorepeat) != 0
    }
}

private let keyboardEventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }
    
    let keyboardInterceptor = Unmanaged<KeyboardInterceptor>
        .fromOpaque(userInfo)
        .takeUnretainedValue()
    
    return keyboardInterceptor.handleEventTap(type: type, event: event)
}
