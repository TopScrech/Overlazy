import ScrechKit

struct InputSourceOverlayView: View {
    let inputSource: InputSource

    var body: some View {
        Text(inputSource.displayLanguageCode)
            .title(.bold)
            .monospaced()
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: 96, height: 96)
            .background(.regularMaterial, in: .rect(cornerRadius: 8))
    }
}
