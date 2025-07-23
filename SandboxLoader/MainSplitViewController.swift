import AppKit
import Combine

class MainSplitViewController: NSSplitViewController {
    var viewModel: ContentViewModel!
    private var cancellables = Set<AnyCancellable>()

    private let deviceViewController = DeviceViewController()
    private let contentViewController = ContentContainerViewController()

    override func viewDidLoad() {
        super.viewDidLoad()

        deviceViewController.viewModel = viewModel
        contentViewController.viewModel = viewModel

        // Setup left panel (devices)
        let devicesItem = NSSplitViewItem(viewController: deviceViewController)

        // Setup right panel (content)
        let contentItem = NSSplitViewItem(viewController: contentViewController)

        self.splitViewItems = [devicesItem, contentItem]
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        guard splitViewItems.count > 1 else { return }
        splitView.setPosition(250, ofDividerAt: 0)
    }
}
