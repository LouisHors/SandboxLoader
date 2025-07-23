import AppKit
import Combine

class AppListViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    var viewModel: ContentViewModel!
    private var cancellables = Set<AnyCancellable>()

    // MARK: - UI Components
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let headerView = NSView()
    private let titleLabel = NSTextField(labelWithString: "Applications")
    private let refreshButton = NSButton(image: NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Refresh")!, target: nil, action: nil)


    override func loadView() {
        self.view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()
    }

    private func setupUI() {
        // --- Header ---
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.wantsLayer = true
        headerView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        headerView.layer?.borderWidth = 1.0
        headerView.layer?.borderColor = NSColor.separatorColor.cgColor

        titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = .labelColor

        refreshButton.bezelStyle = .texturedRounded
        refreshButton.target = self
        refreshButton.action = #selector(refreshApps)

        let headerStack = NSStackView(views: [titleLabel, NSView(), refreshButton]) // Use a dummy view for spacing
        headerStack.orientation = .horizontal
        headerStack.distribution = .fill
        headerStack.alignment = .centerY
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(headerStack)

        // --- Table View ---
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let mainStack = NSStackView(views: [headerView, scrollView])
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 0
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainStack)

        NSLayoutConstraint.activate([
            headerStack.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            headerStack.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            headerStack.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 50),

            mainStack.topAnchor.constraint(equalTo: view.topAnchor),
            mainStack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.widthAnchor.constraint(equalTo: mainStack.widthAnchor)
        ])


        let appNameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("AppNameColumn"))
        appNameColumn.title = "Application"

        let bundleIdColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("BundleIdColumn"))
        bundleIdColumn.title = "Bundle Identifier"

        tableView.addTableColumn(appNameColumn)
        tableView.addTableColumn(bundleIdColumn)
        tableView.headerView = NSTableHeaderView()
        tableView.backgroundColor = .white
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.gridStyleMask = [.solidHorizontalGridLineMask, .solidVerticalGridLineMask]
        tableView.style = .inset
        tableView.rowHeight = 44
        tableView.sizeLastColumnToFit()


        tableView.dataSource = self
        tableView.delegate = self
    }


    private func bindViewModel() {
        viewModel.$apps
            .receive(on: DispatchQueue.main)
            .sink { [weak self] apps in
                self?.tableView.reloadData()
                self?.updateAppNameColumnWidth(for: apps)
            }
            .store(in: &cancellables)
    }

    @objc private func refreshApps() {
        viewModel.refreshApps()
    }

    private func updateAppNameColumnWidth(for apps: [InstalledApp]) {
        guard !apps.isEmpty, let column = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier("AppNameColumn")) else {
            return
        }

        let font = NSFont.systemFont(ofSize: 14, weight: .medium)
        let attributes = [NSAttributedString.Key.font: font]

        let maxWidth = apps.reduce(0) { (currentMax, app) -> CGFloat in
            let nameWidth = (app.name as NSString).size(withAttributes: attributes).width
            return max(currentMax, nameWidth)
        }

        // Add padding for the cell's horizontal constraints (8 + 8) and some extra breathing room
        let paddedWidth = maxWidth + 24

        column.width = max(column.minWidth, paddedWidth)
    }


    // MARK: - NSTableViewDataSource
    func numberOfRows(in tableView: NSTableView) -> Int {
        return viewModel.apps.count
    }

    // MARK: - NSTableViewDelegate
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let column = tableColumn else { return nil }

        let app = viewModel.apps[row]
        let cellIdentifier = NSUserInterfaceItemIdentifier("AppCell_\(column.identifier.rawValue)")

        var cell = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView

        if cell == nil {
            cell = NSTableCellView()
            let textField = NSTextField(string: "")
            textField.isBezeled = false
            textField.drawsBackground = false
            textField.isEditable = false
            textField.translatesAutoresizingMaskIntoConstraints = false
            cell?.textField = textField
            cell?.addSubview(textField)

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 8),
                textField.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -8),
                textField.centerYAnchor.constraint(equalTo: cell!.centerYAnchor)
            ])
        }

        if column.identifier.rawValue == "AppNameColumn" {
            cell?.textField?.stringValue = app.name
            cell?.textField?.font = .systemFont(ofSize: 14, weight: .medium)
            cell?.textField?.textColor = .labelColor
        } else if column.identifier.rawValue == "BundleIdColumn" {
            cell?.textField?.stringValue = app.bundleIdentifier
            cell?.textField?.font = .systemFont(ofSize: 12)
            cell?.textField?.textColor = .secondaryLabelColor
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
