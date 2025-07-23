import Foundation

/// Represents an application installed on an iOS device.
struct InstalledApp: Identifiable, Hashable {
    /// The bundle identifier of the application (e.g., "com.apple.mobilesafari").
    let bundleIdentifier: String

    /// The display name of the application (e.g., "Safari").
    let name: String

    /// The unique identifier for the app, which is its bundle identifier.
    /// Conforms to the `Identifiable` protocol for use in SwiftUI lists.
    var id: String { bundleIdentifier }
}
