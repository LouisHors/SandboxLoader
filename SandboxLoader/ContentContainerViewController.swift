import AppKit
import Combine

class ContentContainerViewController: NSViewController {
    var viewModel: ContentViewModel!
    private var cancellables = Set<AnyCancellable>()

    private var currentViewController: NSViewController?

    // Placeholders for the actual view controllers
    private lazy var appListViewController: AppListViewController = {
        let vc = AppListViewController()
        vc.viewModel = viewModel
        return vc
    }()

    private lazy var fileBrowserViewController: FileBrowserViewController = {
        let vc = FileBrowserViewController()
        vc.viewModel = viewModel
        return vc
    }()

    private lazy var noDeviceSelectedViewController: NSViewController = {
        let vc = NSViewController()
        let label = NSTextField(labelWithString: "Select a device from the sidebar.")
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        vc.view = NSView()
        vc.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: vc.view.centerYAnchor)
        ])
        return vc
    }()

    override func loadView() {
        self.view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        bindViewModel()
    }

    private func bindViewModel() {
        viewModel.$selectedDevice
            .combineLatest(viewModel.$selectedApp)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (device, app) in
                self?.updateChildViewController(device: device, app: app)
            }
            .store(in: &cancellables)
    }

    private func updateChildViewController(device: Device?, app: InstalledApp?) {
        let newViewController: NSViewController

        if device == nil {
            newViewController = noDeviceSelectedViewController
        } else if app == nil {
            newViewController = appListViewController
        } else {
            newViewController = fileBrowserViewController
        }

        if newViewController == currentViewController {
            return
        }

        // Remove the old view controller
        if let oldViewController = currentViewController {
            oldViewController.view.removeFromSuperview()
            oldViewController.removeFromParent()
        }

        // Add the new view controller
        addChild(newViewController)
        newViewController.view.frame = self.view.bounds
        newViewController.view.autoresizingMask = [.width, .height]
        self.view.addSubview(newViewController.view)

        currentViewController = newViewController
    }
}
