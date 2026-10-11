import SwiftUI

@main
struct SoundRemoteApp: App {
    @StateObject private var client = RemoteClient()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(client)
        }
    }
}
