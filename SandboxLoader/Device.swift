import Foundation

/// Represents a connected iOS device.
struct Device: Identifiable, Hashable {
    let udid: String
    let name: String

    /// The unique identifier for the device, which is its UDID.
    /// Conforms to the `Identifiable` protocol for use in SwiftUI lists.
    var id: String { udid }
}
