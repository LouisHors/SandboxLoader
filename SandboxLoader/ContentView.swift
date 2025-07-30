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
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
