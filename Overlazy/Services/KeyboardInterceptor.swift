import ApplicationServices
import Carbon
import Foundation

final class KeyboardInterceptor: @unchecked Sendable {
    var onShortcut: (@MainActor () -> Void)?

    nonisolated(unsafe) private var eventTap: CFMachPort?
    nonisolated(unsafe) private var runLoopSource: CFRunLoopSource?
    nonisolated(unsafe) private var isFunctionKeyPressed = false
    nonisolated(unsafe) private var shouldSuppressFunctionKeyUp = false
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

        if type == .keyDown, isFunctionKey(event), !isRepeat(event) {
            shouldSuppressFunctionKeyUp = true
            triggerShortcut()
            return nil
        }

        if type == .keyUp, shouldSuppressFunctionKeyUp, isFunctionKey(event) {
            shouldSuppressFunctionKeyUp = false
            return nil
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

        if isPressed, !isFunctionKeyPressed {
            isFunctionKeyPressed = true
            triggerShortcut()
            return nil
        }

        if !isPressed, isFunctionKeyPressed {
            isFunctionKeyPressed = false
            return nil
        }

        return nil
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
