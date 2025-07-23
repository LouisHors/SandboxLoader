import AppKit
import Combine

class DeviceViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    var viewModel: ContentViewModel!
    private var cancellables = Set<AnyCancellable>()

    private let tableView = NSTableView()
    private let scrollView = NSScrollView()

    override func loadView() {
        self.view = NSView()

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        view.addSubview(scrollView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("DeviceNameColumn"))
        column.title = "Devices"
        column.resizingMask = []
        tableView.addTableColumn(column)
        tableView.headerView = NSTableHeaderView()
        tableView.intercellSpacing = .zero

        tableView.dataSource = self
        tableView.delegate = self
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        guard let column = tableView.tableColumns.first else { return }
        column.width = tableView.bounds.width
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        bindViewModel()
    }

    private func bindViewModel() {
        viewModel.$devices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        return viewModel.devices.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let device = viewModel.devices[row]
        let cellIdentifier = NSUserInterfaceItemIdentifier("DeviceCell")

        var cell = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView
        if cell == nil {
            let textField = NSTextField()
            textField.isBezeled = false
            textField.drawsBackground = false
            textField.isEditable = false

            cell = NSTableCellView()
            cell!.textField = textField
            cell!.addSubview(textField)

            textField.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: 0),
                textField.centerYAnchor.constraint(equalTo: cell!.centerYAnchor)
            ])
        }

        cell?.textField?.stringValue = device.name
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 else {
            viewModel.selectedDevice = nil
            Task {
                await viewModel.handleDeviceSelectionChange()
            }
            return
        }
        viewModel.selectedDevice = viewModel.devices[selectedRow]
        Task {
            await viewModel.handleDeviceSelectionChange()
        }
    }
}
