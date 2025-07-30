import Foundation

/// Manages interactions with iOS devices using the libimobiledevice library.
class DeviceManager {

    /// Fetches a list of all currently connected iOS devices.
    ///
    /// - Returns: An array of `Device` objects, each representing a connected device.
    /// - Throws: An error if the device list cannot be retrieved.
    func getDevices() throws -> [Device] {
        var devices: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>? = nil
        var count: Int32 = 0

        // Attempt to get the list of device UDIDs
        let result = idevice_get_device_list(&devices, &count)

        // Ensure we handle potential errors from the C-library
        guard result == IDEVICE_E_SUCCESS else {
            throw IdeviceError(source: .idevice, code: result.rawValue)
        }

        // Make sure the devices pointer is not null before proceeding
        guard let devicePointers = devices else {
            // This case should ideally not happen if count > 0, but it's good practice to check.
            return []
        }

        var deviceList: [Device] = []

        for i in 0..<Int(count) {
            if let udidPointer = devicePointers[i] {
                let udid = String(cString: udidPointer)
                let deviceName = getDeviceName(for: udid) ?? "Unknown Device"
                deviceList.append(Device(udid: udid, name: deviceName))
            }
        }

        // Free the memory allocated by the C library to prevent memory leaks
        idevice_device_list_free(devices)

        return deviceList
    }

    /// Retrieves the name of a device for a given UDID.
    ///
    /// - Parameter udid: The UDID of the device.
    /// - Returns: The name of the device, or `nil` if it cannot be retrieved.
    private func getDeviceName(for udid: String) -> String? {
        var device: idevice_t? = nil
        var lockdownClient: lockdownd_client_t? = nil
        var deviceName: UnsafeMutablePointer<CChar>? = nil

        // Get a handle for the device
        guard idevice_new(&device, udid) == IDEVICE_E_SUCCESS else {
            return nil
        }

        // Connect to the lockdown service on the device
        guard lockdownd_client_new_with_handshake(device, &lockdownClient, "SandboxLoader") == LOCKDOWN_E_SUCCESS else {
            idevice_free(device)
            return nil
        }

        // Try to get the device name
        let result = lockdownd_get_device_name(lockdownClient, &deviceName)

        // Cleanup resources
        lockdownd_client_free(lockdownClient)
        idevice_free(device)

        if result == LOCKDOWN_E_SUCCESS, let namePtr = deviceName {
            let name = String(cString: namePtr)
            // The C library allocates memory for the name, so we must free it
            free(namePtr)
            return name
        }

        return nil
    }

    /// Fetches a list of installed applications for a given device.
    ///
    /// - Parameter deviceUDID: The UDID of the target device.
    /// - Returns: An array of `InstalledApp` objects.
    /// - Throws: An `IdeviceError` if communication with the device fails.
    func getApps(for deviceUDID: String) throws -> [InstalledApp] {
        var device: idevice_t? = nil
        var lockdownClient: lockdownd_client_t? = nil
        var instproxyClient: instproxy_client_t? = nil
        var appList: plist_t? = nil
        var apps: [InstalledApp] = []

        guard idevice_new(&device, deviceUDID) == IDEVICE_E_SUCCESS else {
            throw IdeviceError(source: .idevice, code: IDEVICE_E_UNKNOWN_ERROR.rawValue)
        }
        defer { idevice_free(device) }

        guard lockdownd_client_new_with_handshake(device, &lockdownClient, "SandboxLoader") == LOCKDOWN_E_SUCCESS else {
            throw IdeviceError(source: .lockdown, code: LOCKDOWN_E_UNKNOWN_ERROR.rawValue)
        }
        defer { lockdownd_client_free(lockdownClient) }

        var service: lockdownd_service_descriptor_t? = nil
        guard lockdownd_start_service(lockdownClient, "com.apple.mobile.installation_proxy", &service) == LOCKDOWN_E_SUCCESS else {
            throw IdeviceError(source: .lockdown, code: LOCKDOWN_E_UNKNOWN_ERROR.rawValue)
        }
        defer { lockdownd_service_descriptor_free(service) }

        guard instproxy_client_new(device, service, &instproxyClient) == INSTPROXY_E_SUCCESS else {
            throw IdeviceError(source: .instproxy, code: INSTPROXY_E_UNKNOWN_ERROR.rawValue)
        }
        defer { instproxy_client_free(instproxyClient) }

        // Create lookup options using the new API
        let lookupOptions = instproxy_client_options_new()
        defer { instproxy_client_options_free(lookupOptions) }

        // We only want to browse user-installed applications
        plist_dict_set_item(lookupOptions, "ApplicationType", plist_new_string("User"))

        // Specify which attributes to return to check the app's signing status
        let returnAttributes = plist_new_array()
        plist_array_append_item(returnAttributes, plist_new_string("CFBundleIdentifier"))
        plist_array_append_item(returnAttributes, plist_new_string("CFBundleDisplayName"))
        plist_array_append_item(returnAttributes, plist_new_string("SignerIdentity"))
        plist_array_append_item(returnAttributes, plist_new_string("Entitlements"))
        plist_dict_set_item(lookupOptions, "ReturnAttributes", returnAttributes)

        guard instproxy_browse(instproxyClient, lookupOptions, &appList) == INSTPROXY_E_SUCCESS else {
            throw IdeviceError(source: .instproxy, code: INSTPROXY_E_UNKNOWN_ERROR.rawValue)
        }

        defer { plist_free(appList) }

        guard let appArray = appList else {
            return []
        }

        let count = plist_array_get_size(appArray)

        for i in 0..<count {
            if let appDict = plist_array_get_item(appArray, i) {
                var shouldAddApp = false

                // 1. Check for "get-task-allow" entitlement, which indicates a debug build.
                if let entitlementsNode = plist_dict_get_item(appDict, "Entitlements"),
                   plist_get_node_type(entitlementsNode) == PLIST_DICT,
                   let getTaskAllowNode = plist_dict_get_item(entitlementsNode, "get-task-allow") {

                    var getTaskAllowValue: UInt8 = 0
                    if plist_get_node_type(getTaskAllowNode) == PLIST_BOOLEAN {
                        plist_get_bool_val(getTaskAllowNode, &getTaskAllowValue)
                        if getTaskAllowValue != 0 {
                            shouldAddApp = true
                        }
                    }
                }

                // 2. If not a debug build, check the signer identity for Ad-Hoc/Enterprise builds.
                if !shouldAddApp {
                    if let signerIdentityNode = plist_dict_get_item(appDict, "SignerIdentity") {
                        var signerIdentityPtr: UnsafeMutablePointer<CChar>? = nil
                        plist_get_string_val(signerIdentityNode, &signerIdentityPtr)

                        if let signerIdentityPtr = signerIdentityPtr {
                            let signerIdentity = String(cString: signerIdentityPtr)
                            // App Store apps have a specific signer. We include anything that is NOT an App Store app.
                            // This covers Ad-Hoc, Enterprise, and TestFlight builds.
                            if !signerIdentity.starts(with: "Apple iPhone OS") {
                                shouldAddApp = true
                            }
                            free(signerIdentityPtr)
                        }
                    }
                }

                // 3. If the app is identified as debug or ad-hoc, add it to the list.
                if shouldAddApp {
                    var bundleIdPtr: UnsafeMutablePointer<CChar>? = nil
                    var appNamePtr: UnsafeMutablePointer<CChar>? = nil

                    defer {
                        free(bundleIdPtr)
                        free(appNamePtr)
                    }

                    if let bundleIdNode = plist_dict_get_item(appDict, "CFBundleIdentifier") {
                        plist_get_string_val(bundleIdNode, &bundleIdPtr)
                    }

                    if let appNameNode = plist_dict_get_item(appDict, "CFBundleDisplayName") {
                        plist_get_string_val(appNameNode, &appNamePtr)
                    }

                    if let bundleIdPtr = bundleIdPtr, let appNamePtr = appNamePtr {
                        let bundleId = String(cString: bundleIdPtr)
                        let appName = String(cString: appNamePtr)
                        apps.append(InstalledApp(bundleIdentifier: bundleId, name: appName))
                    }
                }
            }
        }

        return apps.sorted { $0.name < $1.name }
    }

    /// Browses the contents of a specific directory within an application's sandbox.
    ///
    /// - Parameters:
    ///   - deviceUDID: The UDID of the target device.
    ///   - bundleIdentifier: The bundle identifier of the target application.
    ///   - path: The path within the sandbox to browse. Defaults to the root directory "/".
    /// - Returns: An array of `FileSystemItem` objects found at the given path.
    /// - Throws: An `IdeviceError` if any step of the communication fails.
    func browse(for deviceUDID: String, bundleIdentifier: String, at path: String = "/") throws -> [FileSystemItem] {
        var device: idevice_t? = nil
        var houseArrestClient: house_arrest_client_t? = nil
        var afcClient: afc_client_t? = nil
        var directoryInfo: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>? = nil
        var items: [FileSystemItem] = []

        guard idevice_new(&device, deviceUDID) == IDEVICE_E_SUCCESS else {
            throw IdeviceError(source: .idevice, code: IDEVICE_E_UNKNOWN_ERROR.rawValue)
        }
        defer { idevice_free(device) }

        guard house_arrest_client_start_service(device, &houseArrestClient, "SandboxLoader") == HOUSE_ARREST_E_SUCCESS else {
            throw IdeviceError(source: .housearrest, code: HOUSE_ARREST_E_UNKNOWN_ERROR.rawValue)
        }
        defer { house_arrest_client_free(houseArrestClient) }

        guard house_arrest_send_command(houseArrestClient, "VendContainer", bundleIdentifier) == HOUSE_ARREST_E_SUCCESS else {
            throw IdeviceError(source: .housearrest, code: HOUSE_ARREST_E_CONN_FAILED.rawValue)
        }

        var response: plist_t? = nil
        guard house_arrest_get_result(houseArrestClient, &response) == HOUSE_ARREST_E_SUCCESS else {
            throw IdeviceError(source: .housearrest, code: HOUSE_ARREST_E_UNKNOWN_ERROR.rawValue)
        }
        defer { plist_free(response) }

        // After getting the result, we MUST check the status of the command itself.
        guard let responseDict = response else {
            // This should not happen if the previous call was successful, but as a safeguard:
            throw IdeviceError(source: .housearrest, code: HOUSE_ARREST_E_PLIST_ERROR.rawValue)
        }

        var statusValue: UnsafeMutablePointer<CChar>? = nil
        let statusNode = plist_dict_get_item(responseDict, "Status")
        if statusNode != nil {
            plist_get_string_val(statusNode, &statusValue)
        }
        defer { free(statusValue) }

        // Only if the status is "Complete" can we proceed to create an AFC client.
        guard let status = statusValue, String(cString: status) == "Complete" else {
            var errorValue: UnsafeMutablePointer<CChar>? = nil
            let errorNode = plist_dict_get_item(responseDict, "Error")
            if errorNode != nil {
                plist_get_string_val(errorNode, &errorValue)
            }
            defer { free(errorValue) }

            let errorMessage = (errorValue != nil) ? String(cString: errorValue!) : "Unknown operation error"
            // We throw a specific error that can be caught by the UI.
            // Using HOUSE_ARREST_E_OP_FAILED which, although not in the enum, semantically represents this failure.
            throw IdeviceError(source: .housearrest, code: -5 /* HOUSE_ARREST_E_OP_FAILED */, message: errorMessage)
        }

        let afc_new_result = afc_client_new_from_house_arrest_client(houseArrestClient, &afcClient)
        guard afc_new_result == AFC_E_SUCCESS else {
            throw IdeviceError(source: .afc, code: afc_new_result.rawValue)
        }
        defer { afc_client_free(afcClient) }

        let afc_read_result = afc_read_directory(afcClient, path, &directoryInfo)
        guard afc_read_result == AFC_E_SUCCESS else {
            throw IdeviceError(source: .afc, code: afc_read_result.rawValue)
        }
        defer { afc_dictionary_free(directoryInfo) }

        var currentEntry = directoryInfo
        while let entryNamePtr = currentEntry?.pointee {
            let entryName = String(cString: entryNamePtr)
            // Add a filter to exclude the "SystemData" directory, in addition to "." and "..".
            if entryName != "." && entryName != ".." && entryName != "SystemData" {
                var fileInfo: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>? = nil
                let fullPath = (path == "/") ? "/\(entryName)" : "\(path)/\(entryName)"

                if afc_get_file_info(afcClient, fullPath, &fileInfo) == AFC_E_SUCCESS {
                    var itemSize: UInt64 = 0
                    var itemType: FileSystemItem.ItemType = .file

                    var currentInfo = fileInfo
                    while let keyPtr = currentInfo?.pointee, let valPtr = currentInfo?.advanced(by: 1).pointee {
                        let key = String(cString: keyPtr)
                        let value = String(cString: valPtr)

                        if key == "st_size" {
                            itemSize = UInt64(value) ?? 0
                        } else if key == "st_ifmt", value == "S_IFDIR" {
                            itemType = .directory
                        }

                        currentInfo = currentInfo?.advanced(by: 2)
                    }

                    items.append(FileSystemItem(name: entryName, path: fullPath, size: itemSize, type: itemType))
                    afc_dictionary_free(fileInfo)
                }
            }
            currentEntry = currentEntry?.advanced(by: 1)
        }

        return items.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    /// Downloads a file from an application's sandbox to a local file URL.
    ///
    /// - Parameters:
    ///   - deviceUDID: The UDID of the target device.
    ///   - bundleIdentifier: The bundle identifier of the target application.
    ///   - sourcePath: The full path of the file to download from the sandbox.
    ///   - localUrl: The local file `URL` where the downloaded file will be saved.
    /// - Throws: An `IdeviceError` if any step of the communication or file transfer fails.
    func downloadFile(for deviceUDID: String, bundleIdentifier: String, from sourcePath: String, to localUrl: URL) throws {
        var device: idevice_t? = nil
        var houseArrestClient: house_arrest_client_t? = nil
        var afcClient: afc_client_t? = nil

        // Standard device connection and service startup
        guard idevice_new(&device, deviceUDID) == IDEVICE_E_SUCCESS else {
            throw IdeviceError(source: .idevice, code: IDEVICE_E_UNKNOWN_ERROR.rawValue)
        }
        defer { idevice_free(device) }

        guard house_arrest_client_start_service(device, &houseArrestClient, "SandboxLoader") == HOUSE_ARREST_E_SUCCESS else {
            throw IdeviceError(source: .housearrest, code: HOUSE_ARREST_E_UNKNOWN_ERROR.rawValue)
        }
        defer { house_arrest_client_free(houseArrestClient) }

        // Request access to the app's container
        guard house_arrest_send_command(houseArrestClient, "VendContainer", bundleIdentifier) == HOUSE_ARREST_E_SUCCESS else {
            throw IdeviceError(source: .housearrest, code: HOUSE_ARREST_E_CONN_FAILED.rawValue)
        }

        // Check the result of the command
        var response: plist_t? = nil
        guard house_arrest_get_result(houseArrestClient, &response) == HOUSE_ARREST_E_SUCCESS else {
            throw IdeviceError(source: .housearrest, code: HOUSE_ARREST_E_UNKNOWN_ERROR.rawValue)
        }
        defer { plist_free(response) }

        // Create an AFC client from the house_arrest client
        guard afc_client_new_from_house_arrest_client(houseArrestClient, &afcClient) == AFC_E_SUCCESS else {
            throw IdeviceError(source: .afc, code: AFC_E_UNKNOWN_ERROR.rawValue)
        }
        defer { afc_client_free(afcClient) }

        // Open the remote file for reading
        var remoteFileHandle: UInt64 = 0
        let openResult = afc_file_open(afcClient, sourcePath, AFC_FOPEN_RDONLY, &remoteFileHandle)
        guard openResult == AFC_E_SUCCESS else {
            throw IdeviceError(source: .afc, code: openResult.rawValue, message: "Failed to open remote file.")
        }
        defer { afc_file_close(afcClient, remoteFileHandle) }

        // Create a local file handle for writing
        guard let localFileHandle = FileHandle(forWritingAtPath: localUrl.path) ??
              (FileManager.default.createFile(atPath: localUrl.path, contents: nil, attributes: nil) ? FileHandle(forWritingAtPath: localUrl.path) : nil) else {
            throw IdeviceError(source: .afc, code: -1, message: "Failed to create local file at \(localUrl.path)")
        }
        defer { try? localFileHandle.close() }


        // Read from remote and write to local in chunks
        let bufferSize = 65536 // 64KB chunk size
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while true {
            var bytesRead: UInt32 = 0
            let readResult = afc_file_read(afcClient, remoteFileHandle, buffer, UInt32(bufferSize), &bytesRead)

            if readResult == AFC_E_SUCCESS {
                if bytesRead > 0 {
                    let data = Data(bytes: buffer, count: Int(bytesRead))
                    try localFileHandle.write(contentsOf: data)
                } else {
                    // End of file
                    break
                }
            } else {
                throw IdeviceError(source: .afc, code: readResult.rawValue, message: "Failed during file read.")
            }
        }
    }
}

/// A custom error type to represent errors from the libimobiledevice library.
struct IdeviceError: Error {
    enum Source: String {
        case idevice
        case lockdown
        case instproxy
        case housearrest
        case afc
    }

    let source: Source
    let code: Int32
    var message: String? = nil

    var localizedDescription: String {
        if let message = message {
            return "libimobiledevice error (\(source.rawValue)): \(message) (code: \(code))"
        }
        return "libimobiledevice error (\(source.rawValue)): \(code)"
    }
}
