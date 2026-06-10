import Carbon
import Foundation

@MainActor
final class InputSourceService {
    func selectableInputSources() -> [InputSource] {
        copyInputSourceList().compactMap(inputSource(from:))
    }

    func selectedInputSource() -> InputSource? {
        guard let selected = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return nil
        }

        return inputSource(from: selected)
    }

    func select(_ inputSource: InputSource) -> Bool {
        guard let matchingSource = copyInputSourceList().first(where: { source in
            inputSourceID(from: source) == inputSource.id
        }) else {
            return false
        }

        return TISSelectInputSource(matchingSource) == noErr
    }

    private func copyInputSourceList() -> [TISInputSource] {
        guard let unmanagedSources = TISCreateInputSourceList(nil, false) else {
            return []
        }

        let sources = unmanagedSources.takeRetainedValue()
        return (sources as? [TISInputSource] ?? []).filter(isSelectableKeyboardInputSource)
    }

    private func inputSource(from source: TISInputSource) -> InputSource? {
        guard let id = inputSourceID(from: source),
              let name = stringProperty(kTISPropertyLocalizedName, from: source) else {
            return nil
        }

        let languageCode = languages(from: source).first

        return InputSource(
            id: id,
            name: name,
            languageCode: languageCode,
            symbol: symbol(for: name, languageCode: languageCode)
        )
    }

    private func inputSourceID(from source: TISInputSource) -> String? {
        stringProperty(kTISPropertyInputSourceID, from: source)
    }

    private func stringProperty(_ property: CFString, from source: TISInputSource) -> String? {
        guard let pointer = TISGetInputSourceProperty(source, property) else {
            return nil
        }

        return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
    }

    private func languages(from source: TISInputSource) -> [String] {
        guard let pointer = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) else {
            return []
        }

        return Unmanaged<CFArray>.fromOpaque(pointer).takeUnretainedValue() as? [String] ?? []
    }

    private func booleanProperty(_ property: CFString, from source: TISInputSource) -> Bool {
        guard let pointer = TISGetInputSourceProperty(source, property) else {
            return false
        }

        let value = Unmanaged<CFBoolean>.fromOpaque(pointer).takeUnretainedValue()
        return CFBooleanGetValue(value)
    }

    private func isSelectableKeyboardInputSource(_ source: TISInputSource) -> Bool {
        stringProperty(kTISPropertyInputSourceCategory, from: source) == kTISCategoryKeyboardInputSource as String &&
        booleanProperty(kTISPropertyInputSourceIsEnabled, from: source) &&
        booleanProperty(kTISPropertyInputSourceIsSelectCapable, from: source)
    }

    private func symbol(for name: String, languageCode: String?) -> String {
        if let languageCode,
           let primaryCode = languageCode.split(separator: "-").first {
            return String(primaryCode).uppercased()
        }

        let compactName = name.replacing(" ", with: "")
        return String(compactName.prefix(2)).uppercased()
    }
}
