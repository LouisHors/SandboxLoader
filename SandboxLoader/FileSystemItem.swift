import Foundation

/// Represents an item (file or directory) within an application's sandbox.
struct FileSystemItem: Identifiable, Hashable {
    /// The unique identifier for the item, which is its full path.
    var id: String { path }

    /// The name of the file or directory.
    let name: String

    /// The full path of the item within the sandbox.
    let path: String

    /// The size of the item in bytes. For directories, this may be 0 or a nominal value.
    let size: UInt64

    /// The type of the item.
    let type: ItemType

    enum ItemType {
        case file
        case directory
    }
}
