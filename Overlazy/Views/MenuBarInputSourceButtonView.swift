import ScrechKit

struct MenuBarInputSourceButtonView: View {
    let inputSource: InputSource
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        if isSelected {
            Button(inputSource.name, action: action)
                .keyboardShortcut("✓", modifiers: [])
        } else {
            Button(inputSource.name, action: action)
        }
    }
}
