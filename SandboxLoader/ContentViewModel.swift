import Foundation
import AppKit

@MainActor
class ContentViewModel: ObservableObject {
    @Published var devices: [Device] = []
    @Published var selectedDevice: Device?

    @Published var apps: [InstalledApp] = []
    @Published var selectedApp: InstalledApp?

    @Published var items: [FileSystemItem] = []
    @Published var selectedItems = Set<FileSystemItem.ID>()
    @Published var currentPath: String = "/"
    @Published var pathStack: [String] = []

    @Published var isLoadingDevices = false
    @Published var isLoadingApps = false
    @Published var isLoadingItems = false

    @Published var errorMessage: String?

    private let deviceManager = DeviceManager()

    var isDownloadButtonDisabled: Bool {
        guard let selectedItemId = selectedItems.first,
              let selectedItem = items.first(where: { $0.id == selectedItemId }) else {
            return true
        }
        return selectedItem.type != .file
    }

    func handleDeviceSelectionChange() async {
        guard let device = selectedDevice else {
            // Handle deselection: selectedDevice is already nil, so we just clear dependent state.
            apps = []
            selectedApp = nil
            items = []
            return
        }

        // Handle new selection
        apps = []
        selectedApp = nil
        items = []
        isLoadingApps = true
        errorMessage = nil

        do {
            self.apps = try await Task { try deviceManager.getApps(for: device.udid) }.value
        } catch {
            self.errorMessage = "Failed to fetch apps for \(device.name): \(error.localizedDescription)"
        }
        isLoadingApps = false
    }

    func handleAppSelectionChange() async {
        guard let _ = selectedApp, let _ = selectedDevice else {
            // app is already deselected by the view binding. just clear items
            items = []
            return
        }

        // app is already selected by the view binding, just load contents
        pathStack = ["/"]
        currentPath = "/"
        await browseCurrentPath()
    }

    func navigateTo(item: FileSystemItem) {
        guard item.type == .directory else { return }
        pathStack.append(item.path)
        currentPath = item.path
        Task {
            await browseCurrentPath()
        }
    }

    func navigateBack() {
        guard pathStack.count > 1 else { return }
        pathStack.removeLast()
        currentPath = pathStack.last ?? "/"
        Task {
            await browseCurrentPath()
        }
    }

    private func browseCurrentPath() async {
        guard let device = selectedDevice, let app = selectedApp else { return }

        isLoadingItems = true
        errorMessage = nil
        items = []

        do {
            self.items = try await Task { try deviceManager.browse(for: device.udid, bundleIdentifier: app.bundleIdentifier, at: currentPath) }.value
        } catch {
            self.errorMessage = "Failed to browse \(app.name) at \(currentPath): \(error.localizedDescription)"
        }
        isLoadingItems = false
    }

    func downloadSelectedFile() {
        guard let device = selectedDevice,
              let app = selectedApp,
              let selectedItemId = selectedItems.first,
              let selectedItem = items.first(where: { $0.id == selectedItemId }),
              selectedItem.type == .file else {
            errorMessage = "No file selected for download."
            return
        }

        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = selectedItem.name

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                Task {
                    await self.performDownload(deviceUdid: device.udid,
                                               bundleId: app.bundleIdentifier,
                                               sourcePath: selectedItem.path,
                                               to: url)
                }
            }
        }
    }

    private func performDownload(deviceUdid: String, bundleId: String, sourcePath: String, to localUrl: URL) async {
        isLoadingItems = true
        errorMessage = nil
        do {
            // Run the blocking file download on a background thread.
            try await Task {
                try deviceManager.downloadFile(for: deviceUdid,
                                               bundleIdentifier: bundleId,
                                               from: sourcePath,
                                               to: localUrl)
            }.value
        } catch {
            errorMessage = "Download failed: \(error.localizedDescription)"
        }
        isLoadingItems = false
    }

    func refreshDevices() {
        isLoadingDevices = true
        errorMessage = nil
        devices = []
        // Directly set the selected device to nil. The view's `onChange` will handle the consequences.
        selectedDevice = nil

        Task {
            do {
                self.devices = try await Task { try deviceManager.getDevices() }.value
            } catch {
                self.errorMessage = "Failed to fetch devices: \(error.localizedDescription)"
            }
            isLoadingDevices = false
        }
    }
}
