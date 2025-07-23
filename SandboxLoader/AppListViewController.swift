import AppKit
import Combine

class AppListViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
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

        let appNameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("AppNameColumn"))
        appNameColumn.title = "Application Name"

        let bundleIdColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("BundleIdColumn"))
        bundleIdColumn.title = "Bundle Identifier"

        tableView.addTableColumn(appNameColumn)
        tableView.addTableColumn(bundleIdColumn)
        tableView.headerView = NSTableHeaderView()
        tableView.sizeLastColumnToFit()
        tableView.gridStyleMask = .solidHorizontalGridLineMask

        tableView.dataSource = self
        tableView.delegate = self
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        bindViewModel()
    }

    private func bindViewModel() {
        viewModel.$apps
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)
    }

    // MARK: - NSTableViewDataSource
    func numberOfRows(in tableView: NSTableView) -> Int {
        return viewModel.apps.count
    }

    // MARK: - NSTableViewDelegate
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let column = tableColumn else { return nil }

        let app = viewModel.apps[row]
        let cellIdentifier = NSUserInterfaceItemIdentifier("AppCell")

        var cell = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView

        if cell == nil {
            cell = NSTableCellView()
            // The textField will be created below if it doesn't exist.
        }

        if cell?.textField == nil {
            let textField = NSTextField(string: "")
            textField.isBezeled = false
            textField.drawsBackground = false
            textField.isEditable = false
            textField.translatesAutoresizingMaskIntoConstraints = false

            cell?.addSubview(textField)
            cell?.textField = textField

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cell!.centerYAnchor)
            ])
        }

        if column.identifier == NSUserInterfaceItemIdentifier("AppNameColumn") {
            cell?.textField?.stringValue = app.name
        } else if column.identifier == NSUserInterfaceItemIdentifier("BundleIdColumn") {
            cell?.textField?.stringValue = app.bundleIdentifier
        }

        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < viewModel.apps.count else {
            viewModel.selectedApp = nil
            Task {
                await viewModel.handleAppSelectionChange()
            }
            return
        }
        viewModel.selectedApp = viewModel.apps[selectedRow]
        Task {
            await viewModel.handleAppSelectionChange()
        }
    }
}
