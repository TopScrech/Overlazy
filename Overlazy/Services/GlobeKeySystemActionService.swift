import CoreFoundation
import Foundation

@MainActor
final class GlobeKeySystemActionService {
    private let domain = "com.apple.HIToolbox" as CFString
    private let key = "AppleFnUsageType" as CFString
    private let savedValueKey = "savedAppleFnUsageType"
    private let savedValueWasPresentKey = "savedAppleFnUsageTypeWasPresent"
    private let savedOriginalKey = "savedOriginalAppleFnUsageType"
    private let savedSymbolicHotKeysKey = "savedInputSourceSymbolicHotKeys"
    private let savedSymbolicHotKeysOriginalKey = "savedOriginalInputSourceSymbolicHotKeys"
    private let symbolicHotKeysDomain = "com.apple.symbolichotkeys" as CFString
    private let symbolicHotKeysKey = "AppleSymbolicHotKeys" as CFString
    private let inputSourceHotKeyIDs = ["60", "61", "64", "65"]
    private let userDefaults = UserDefaults.standard
    
    func disableSystemAction() -> SystemGlobeActionStatus {
        saveOriginalValueIfNeeded()
        let didDisableGlobeAction = setValue(0)
        let didDisableHotKeys = disableInputSourceHotKeys()
        applyKeyboardSettings()
        
        return didDisableGlobeAction && didDisableHotKeys ? .disabled : .failed
    }
    
    func restoreSystemAction() -> SystemGlobeActionStatus {
        let didRestoreGlobeAction: Bool
        
        guard userDefaults.bool(forKey: savedOriginalKey) else {
            didRestoreGlobeAction = deleteValue()
            let didRestoreHotKeys = restoreInputSourceHotKeys()
            applyKeyboardSettings()
            return didRestoreGlobeAction && didRestoreHotKeys ? .restored : .failed
        }
        
        if userDefaults.bool(forKey: savedValueWasPresentKey) {
            let savedValue = userDefaults.integer(forKey: savedValueKey)
            didRestoreGlobeAction = setValue(savedValue)
        } else {
            didRestoreGlobeAction = deleteValue()
        }
        
        let didRestoreHotKeys = restoreInputSourceHotKeys()
        applyKeyboardSettings()
        
        return didRestoreGlobeAction && didRestoreHotKeys ? .restored : .failed
    }
    
    func currentValue() -> Int? {
        guard let value = CFPreferencesCopyValue(
            key,
            domain,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        ) else {
            return nil
        }
        
        if let number = value as? NSNumber {
            return number.intValue
        }
        
        if let string = value as? String {
            return Int(string)
        }
        
        return nil
    }
    
    private func setValue(_ value: Int) -> Bool {
        CFPreferencesSetValue(
            key,
            NSNumber(value: value),
            domain,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        
        return CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }
    
    private func deleteValue() -> Bool {
        CFPreferencesSetValue(
            key,
            nil,
            domain,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        
        return CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }
    
    private func saveOriginalValueIfNeeded() {
        guard !userDefaults.bool(forKey: savedOriginalKey) else {
            return
        }
        
        if let currentValue = currentValue() {
            userDefaults.set(currentValue, forKey: savedValueKey)
            userDefaults.set(true, forKey: savedValueWasPresentKey)
        } else {
            userDefaults.set(false, forKey: savedValueWasPresentKey)
        }
        
        userDefaults.set(true, forKey: savedOriginalKey)
    }
    
    private func disableInputSourceHotKeys() -> Bool {
        guard var hotKeys = currentSymbolicHotKeys() else {
            return false
        }
        
        saveOriginalSymbolicHotKeysIfNeeded(from: hotKeys)
        
        for id in inputSourceHotKeyIDs {
            guard var hotKey = hotKeys[id] as? [String: Any] else {
                continue
            }
            
            hotKey["enabled"] = false
            hotKeys[id] = hotKey
        }
        
        return setSymbolicHotKeys(hotKeys)
    }
    
    private func restoreInputSourceHotKeys() -> Bool {
        guard userDefaults.bool(forKey: savedSymbolicHotKeysOriginalKey) else {
            return true
        }
        
        guard var hotKeys = currentSymbolicHotKeys(),
              let savedHotKeys = savedSymbolicHotKeys() else {
            return false
        }
        
        for (id, hotKey) in savedHotKeys {
            hotKeys[id] = hotKey
        }
        
        return setSymbolicHotKeys(hotKeys)
    }
    
    private func currentSymbolicHotKeys() -> [String: Any]? {
        guard let value = CFPreferencesCopyValue(
            symbolicHotKeysKey,
            symbolicHotKeysDomain,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        ) else {
            return nil
        }
        
        return value as? [String: Any]
    }
    
    private func setSymbolicHotKeys(_ hotKeys: [String: Any]) -> Bool {
        CFPreferencesSetValue(
            symbolicHotKeysKey,
            hotKeys as CFDictionary,
            symbolicHotKeysDomain,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        
        return CFPreferencesSynchronize(symbolicHotKeysDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }
    
    private func saveOriginalSymbolicHotKeysIfNeeded(from hotKeys: [String: Any]) {
        guard !userDefaults.bool(forKey: savedSymbolicHotKeysOriginalKey) else {
            return
        }
        
        let originals = inputSourceHotKeyIDs.reduce(into: [String: Any]()) {
            guard let hotKey = hotKeys[$1] else {
                return
            }
            
            $0[$1] = hotKey
        }
        
        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: originals,
            format: .binary,
            options: 0
        ) else {
            return
        }
        
        userDefaults.set(data, forKey: savedSymbolicHotKeysKey)
        userDefaults.set(true, forKey: savedSymbolicHotKeysOriginalKey)
    }
    
    private func savedSymbolicHotKeys() -> [String: Any]? {
        guard
            let data = userDefaults.data(forKey: savedSymbolicHotKeysKey),
            let hotKeys = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            ) as? [String: Any]
        else {
            return nil
        }
        
        return hotKeys
    }
    
    private func applyKeyboardSettings() {
        run("/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings", arguments: ["-u"])
        run("/usr/bin/killall", arguments: ["-9", "TextInputSwitcher"])
    }
    
    private func run(_ executablePath: String, arguments: [String]) {
        let process = Process()
        process.executableURL = URL(filePath: executablePath)
        process.arguments = arguments
        
        try? process.run()
        process.waitUntilExit()
    }
}
