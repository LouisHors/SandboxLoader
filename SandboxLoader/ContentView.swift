//
//  ContentView.swift
//  SandboxLoader
//
//  Created by horsliu on 2025/7/22.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()

    var body: some View {
        NavigationView {
            // Sidebar for devices
            DeviceSidebar(viewModel: viewModel)

            // Detail view is now a separate computed property
            detailView
        }
        .onAppear {
            viewModel.refreshDevices()
        }
    }

    /// A computed property that builds the detail view based on the current state.
    /// Using @ViewBuilder helps the compiler by breaking up a complex expression.
    @ViewBuilder
    private var detailView: some View {
        if let device = viewModel.selectedDevice {
            if viewModel.selectedApp == nil {
                // App List View
                AppListView(viewModel: viewModel)
                    .navigationTitle("Apps on \(device.name)")
            } else {
                // File Browser View
                FileBrowserView(viewModel: viewModel)
            }
        } else {
            // Placeholder view when no device is selected
            Text("Select a device from the sidebar.")
                .font(.title)
        }
    }
}

// MARK: - Subviews

private struct DeviceSidebar: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        VStack {
            if viewModel.isLoadingDevices {
                ProgressView().padding()
            }
            List(selection: $viewModel.selectedDevice) {
                ForEach(viewModel.devices) { device in
                    Label(device.name, systemImage: "iphone").tag(device)
                }
            }
            .listStyle(SidebarListStyle())
        }
        .navigationTitle("Devices")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: viewModel.refreshDevices, label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                })
            }
        }
        .onChange(of: viewModel.selectedDevice) { _ in
            Task {
                await Task.yield()
                await viewModel.handleDeviceSelectionChange()
            }
        }
    }
}

private struct AppListView: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        VStack {
            if viewModel.isLoadingApps {
                ProgressView("Loading apps...")
            } else if !viewModel.apps.isEmpty {
                List(selection: $viewModel.selectedApp) {
                    ForEach(viewModel.apps) { app in
                        VStack(alignment: .leading) {
                            Text(app.name).font(.headline)
                            Text(app.bundleIdentifier).font(.caption).foregroundColor(.secondary)
                        }.tag(app)
                    }
                }
            } else {
                Text("No user applications found.")
            }

            if let error = viewModel.errorMessage {
                Text(error).foregroundColor(.red).padding()
            }
        }
        .onChange(of: viewModel.selectedApp) { _ in
            Task {
                await Task.yield()
                await viewModel.handleAppSelectionChange()
            }
        }
    }
}

private struct FileBrowserView: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            breadcrumbView
            Divider()

            if viewModel.isLoadingItems {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // The complex table logic is now fully encapsulated in its own View struct.
                FileTableView(items: $viewModel.items, selection: $viewModel.selectedItems, onDoubleClick: viewModel.navigateTo)
            }

            if let error = viewModel.errorMessage {
                Text(error).foregroundColor(.red).padding()
            }
        }
        .navigationTitle("Files in \(viewModel.selectedApp?.name ?? "")")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: viewModel.downloadSelectedFile) {
                    Label("Download", systemImage: "square.and.arrow.down")
                }
                .disabled(viewModel.isDownloadButtonDisabled)
            }
        }
    }

    /// A view builder for the breadcrumb navigation bar.
    @ViewBuilder
    private var breadcrumbView: some View {
        HStack {
            if viewModel.pathStack.count > 1 {
                Button(action: viewModel.navigateBack) {
                    Image(systemName: "chevron.left")
                }
            }
            Text(viewModel.currentPath)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
}

/// A new, self-contained View for displaying the file table.
/// This encapsulation is the most robust way to solve complex compiler issues.
private struct FileTableView: View {
    @Binding var items: [FileSystemItem]
    @Binding var selection: Set<FileSystemItem.ID>
    let onDoubleClick: (FileSystemItem) -> Void

    @State private var sortOrder: [KeyPathComparator<FileSystemItem>] = [.init(\.name)]

    var body: some View {
        Table(items, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name) { item in
                HStack {
                    Image(systemName: item.type == .directory ? "folder.fill" : "doc")
                        .foregroundColor(item.type == .directory ? .accentColor : .secondary)
                    Text(item.name)
                }
                .onTapGesture(count: 2) {
                    onDoubleClick(item)
                }
            }
            .width(min: 200, ideal: 300)

            TableColumn("Size", value: \.size) { item in
                Text(item.type == .file ? formatBytes(item.size) : "--")
            }
            .width(100)
        }
        .onChange(of: sortOrder) { newOrder in
            items.sort(using: newOrder)
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
