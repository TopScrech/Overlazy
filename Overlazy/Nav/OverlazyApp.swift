import ScrechKit

@main
struct OverlazyApp: App {
    @NSApplicationDelegateAdaptor(OverlazyAppDelegate.self) private var appDelegate
    @State private var inputSwitcherStore = InputSwitcherStore()

    var body: some Scene {
        MenuBarExtra("Overlazy", systemImage: "keyboard") {
            MenuBarContentView(inputSwitcherStore: inputSwitcherStore)
        }
        .menuBarExtraStyle(.menu)
    }
}
