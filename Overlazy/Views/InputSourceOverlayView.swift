import ScrechKit

struct InputSourceOverlayView: View {
    let inputSource: InputSource
    
    var body: some View {
        if #available(macOS 26, *) {
            Text(inputSource.displayLanguageCode)
                .title(.bold)
                .monospaced()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 60, height: 50)
                .glassEffect(in: .rect(cornerRadius: 8))
        } else {
            Text(inputSource.displayLanguageCode)
                .title(.bold)
                .monospaced()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 60, height: 50)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 8))
        }
    }
}
