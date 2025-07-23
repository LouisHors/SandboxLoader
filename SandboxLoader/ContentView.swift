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
        MainAppKitView(viewModel: viewModel)
            .onAppear {
                viewModel.refreshDevices()
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: viewModel.refreshDevices) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
