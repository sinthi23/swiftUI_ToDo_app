
import SwiftUI
import FirebaseCore

@main
struct assignment_sinthiApp: App {

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
