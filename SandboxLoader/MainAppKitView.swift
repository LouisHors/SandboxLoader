import SwiftUI
import AppKit

struct MainAppKitView: NSViewControllerRepresentable {
    @ObservedObject var viewModel: ContentViewModel

    func makeNSViewController(context: Context) -> MainSplitViewController {
        let splitViewController = MainSplitViewController()
        splitViewController.viewModel = viewModel
        return splitViewController
    }

    func updateNSViewController(_ nsViewController: MainSplitViewController, context: Context) {
        // We will handle updates via Combine subscriptions within the view controllers
    }
}
